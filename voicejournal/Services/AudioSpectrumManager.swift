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
        stopAnalysis()
        
        // Configure audio session for recording
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
            try session.setPreferredIOBufferDuration(0.005)
            try session.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
            return
        }
        
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        guard format.sampleRate > 0 && format.channelCount > 0 else {
            print("Invalid audio format from input node")
            return
        }
        
        inputNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(fftSize), format: format) { [weak self] buffer, _ in
            self?.process(buffer: buffer)
        }
        
        do {
            try engine.start()
            print("Audio engine started for microphone.")
        } catch {
            print("Failed to start audio engine: \(error)")
        }
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
    
    // MARK: - Private Methods
    
    private func process(buffer: AVAudioPCMBuffer) {
        guard let fftSetup = fftSetup,
              let channelData = buffer.floatChannelData?[0],
              buffer.frameLength > 0 else { return }
        
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
                
                // Apply logarithmic scaling for more natural visualization
                var scaledMagnitudes = [Float](repeating: 0.0, count: magnitudes.count)
                var one: Float = 1.0
                vDSP_vsadd(magnitudes, 1, &one, &scaledMagnitudes, 1, vDSP_Length(magnitudes.count))
                var logMagnitudes = [Float](repeating: 0.0, count: scaledMagnitudes.count)
                vvlog10f(&logMagnitudes, &scaledMagnitudes, [Int32(scaledMagnitudes.count)])
                scaledMagnitudes = logMagnitudes
                
                // Normalize to 0-1 range with a more realistic scale
                var minValue: Float = 0
                var maxValue: Float = 0
                vDSP_minv(scaledMagnitudes, 1, &minValue, vDSP_Length(scaledMagnitudes.count))
                vDSP_maxv(scaledMagnitudes, 1, &maxValue, vDSP_Length(scaledMagnitudes.count))
                
                let range = maxValue - minValue
                if range > 0 {
                    var negMinValue = -minValue
                    vDSP_vsadd(scaledMagnitudes, 1, &negMinValue, &scaledMagnitudes, 1, vDSP_Length(scaledMagnitudes.count))
                    vDSP_vsdiv(scaledMagnitudes, 1, [range], &scaledMagnitudes, 1, vDSP_Length(scaledMagnitudes.count))
                }
                
                // Apply a power curve for better visual response
                var poweredMagnitudes = [Float](repeating: 0.0, count: scaledMagnitudes.count)
                vDSP_vsq(scaledMagnitudes, 1, &poweredMagnitudes, 1, vDSP_Length(scaledMagnitudes.count))
                
                let bars = self.reduceToBars(magnitudes: poweredMagnitudes)
                
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