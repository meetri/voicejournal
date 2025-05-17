//
//  AudioSpectrumManager.swift
//  voicejournal
//
//  Created on 5/16/2025.
//

import AVFoundation
import Accelerate

protocol AudioSpectrumDelegate: AnyObject {
    func didUpdateSpectrum(_ bars: [Float])
}

class AudioSpectrumManager {
    // MARK: - Properties
    
    private let engine = AVAudioEngine()
    private var fftSetup: FFTSetup?
    private let fftSize: Int
    private let barCount: Int
    private var log2n: vDSP_Length
    weak var delegate: AudioSpectrumDelegate?
    private var playerNode: AVAudioPlayerNode?
    
    // MARK: - Initialization
    
    init(fftSize: Int = 1024, barCount: Int = 30) {
        self.fftSize = fftSize
        self.barCount = barCount
        self.log2n = vDSP_Length(log2(Float(fftSize)))
        self.fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
    }
    
    // MARK: - Public Methods
    
    func startMicrophoneAnalysis() {
        // For microphone analysis during recording, we'll use external buffer processing
        // since the AudioRecordingService already has a tap on the input
        print("Microphone analysis ready - using external buffer processing")
        
        // We don't need to stop or start our own engine for microphone analysis
        // The recording service will provide us with audio buffers
    }
    
    func startPlaybackAnalysis(fileURL: URL) {
        stopAnalysis()
        
        // Use a player node in our engine to get the audio data
        let player = AVAudioPlayerNode()
        engine.attach(player)
        self.playerNode = player
        
        guard let file = try? AVAudioFile(forReading: fileURL) else {
            print("Failed to open audio file")
            return
        }
        
        let format = file.processingFormat
        
        // Connect player to main mixer
        engine.connect(player, to: engine.mainMixerNode, format: format)
        
        // Install tap on the player node to capture audio data
        player.installTap(onBus: 0, bufferSize: AVAudioFrameCount(fftSize), format: format) { [weak self] buffer, _ in
            self?.process(buffer: buffer)
        }
        
        do {
            try engine.start()
            
            // Schedule the file but set volume to 0 to avoid echo
            player.scheduleFile(file, at: nil, completionHandler: nil)
            player.volume = 0.0  // Mute this player to avoid echo
            player.play()
            
            print("Audio engine started for playback analysis.")
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    func stopAnalysis() {
        // Remove any installed taps
        if engine.inputNode.numberOfInputs > 0 {
            engine.inputNode.removeTap(onBus: 0)
        }
        
        if let player = playerNode {
            player.removeTap(onBus: 0)
            player.stop()
            engine.detach(player)
            playerNode = nil
        }
        
        engine.mainMixerNode.removeTap(onBus: 0)
        engine.stop()
        print("Audio engine stopped.")
    }
    
    // MARK: - Public Methods
    
    /// Process external buffer (for use with shared audio tap)
    func processExternalBuffer(_ buffer: AVAudioPCMBuffer) {
        process(buffer: buffer)
    }
    
    // MARK: - Private Methods
    
    private func process(buffer: AVAudioPCMBuffer) {
        guard let fftSetup = fftSetup,
              let channelData = buffer.floatChannelData?[0],
              buffer.frameLength > 0 else { 
            print("DEBUG: Process failed - fftSetup: \(fftSetup != nil), channelData: \(buffer.floatChannelData != nil), frameLength: \(buffer.frameLength)")
            return 
        }
        
        let frameCount = Int(buffer.frameLength)
        
        // Apply Hann window
        let window = vDSP.window(ofType: Float.self,
                                usingSequence: .hanningDenormalized,
                                count: frameCount,
                                isHalfWindow: false)
        
        var windowed = [Float](repeating: 0, count: frameCount)
        let channelDataArray = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
        vDSP.multiply(channelDataArray, window, result: &windowed)
        
        // Pad with zeros if needed
        if frameCount < fftSize {
            windowed.append(contentsOf: [Float](repeating: 0, count: fftSize - frameCount))
        }
        
        // Perform FFT
        var real = [Float](repeating: 0, count: fftSize/2)
        var imag = [Float](repeating: 0, count: fftSize/2)
        
        real.withUnsafeMutableBufferPointer { realPtr in
            imag.withUnsafeMutableBufferPointer { imagPtr in
                var split = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                
                windowed.withUnsafeBufferPointer {
                    $0.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftSize/2) {
                        vDSP_ctoz($0, 2, &split, 1, vDSP_Length(fftSize / 2))
                    }
                }
                
                vDSP_fft_zrip(fftSetup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                
                var magnitudes = [Float](repeating: 0.0, count: fftSize/2)
                vDSP_zvabs(&split, 1, &magnitudes, 1, vDSP_Length(fftSize/2))
                
                // Scale magnitudes to compensate for FFT size
                var scaleFactor: Float = 2.0 / Float(fftSize)
                vDSP_vsmul(magnitudes, 1, &scaleFactor, &magnitudes, 1, vDSP_Length(magnitudes.count))
                
                // Apply logarithmic scaling for better perception
                // log10(x + 1) to avoid log(0) and maintain dynamic range
                var logMagnitudes = [Float](repeating: 0.0, count: magnitudes.count)
                for i in 0..<magnitudes.count {
                    // Add a small epsilon to avoid log(0), but keep it small to preserve silence
                    let epsilon: Float = 1e-10
                    logMagnitudes[i] = log10(magnitudes[i] + epsilon)
                }
                
                // Apply a noise floor threshold to eliminate background noise
                let noiseFloor: Float = -60.0 // dB threshold
                let minMagnitude: Float = pow(10, noiseFloor / 20.0)
                
                // Convert to linear scale (0-1 range) with proper silence detection
                var scaledMagnitudes = [Float](repeating: 0.0, count: logMagnitudes.count)
                let dynamicRange: Float = 60.0 // dB dynamic range
                let minDB: Float = -dynamicRange
                let maxDB: Float = 0.0
                
                for i in 0..<logMagnitudes.count {
                    // Convert log magnitude to dB (20 * log10(magnitude))
                    let db = 20.0 * logMagnitudes[i]
                    
                    // Apply noise floor
                    if magnitudes[i] < minMagnitude {
                        scaledMagnitudes[i] = 0.0
                    } else {
                        // Map dB to 0-1 range with clamping
                        let normalized = (db - minDB) / (maxDB - minDB)
                        scaledMagnitudes[i] = max(0.0, min(1.0, normalized))
                    }
                }
                
                let bars = self.reduceToBars(magnitudes: scaledMagnitudes)
                
                if bars.contains(where: { $0 > 0 }) {
                    print("DEBUG: Spectrum bars generated with max: \(bars.max() ?? 0)")
                }
                
                DispatchQueue.main.async {
                    self.delegate?.didUpdateSpectrum(bars)
                }
            }
        }
    }
    
    private func reduceToBars(magnitudes: [Float]) -> [Float] {
        let binCount = magnitudes.count
        var bars = [Float](repeating: 0, count: barCount)
        
        // Use logarithmic scaling for better frequency representation
        for i in 0..<barCount {
            let minFreq = Float(20) * pow(Float(22050/20), Float(i) / Float(barCount))
            let maxFreq = Float(20) * pow(Float(22050/20), Float(i + 1) / Float(barCount))
            
            let minBin = Int(minFreq * Float(binCount) / 22050)
            let maxBin = min(binCount - 1, Int(maxFreq * Float(binCount) / 22050))
            
            var sum: Float = 0
            var count = 0
            
            for bin in minBin...maxBin {
                sum += magnitudes[bin]
                count += 1
            }
            
            if count > 0 {
                bars[i] = sum / Float(count)
            }
        }
        
        return bars
    }
    
    deinit {
        if let fftSetup = fftSetup {
            vDSP_destroy_fftsetup(fftSetup)
        }
    }
}