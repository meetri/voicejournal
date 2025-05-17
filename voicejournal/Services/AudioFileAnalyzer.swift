//
//  AudioFileAnalyzer.swift
//  voicejournal
//
//  Created on 5/16/2025.
//

import AVFoundation
import Accelerate

/// A service that analyzes audio file data synchronized with playback
class AudioFileAnalyzer {
    private var audioFile: AVAudioFile?
    private var fftSetup: FFTSetup?
    private let fftSize: Int = 1024
    private let barCount: Int = 30
    private var log2n: vDSP_Length
    private var timer: Timer?
    
    weak var delegate: AudioSpectrumDelegate?
    
    // Smoothing for visualization
    private var previousBars: [Float] = []
    private let smoothingFactor: Float = 0.5 // Higher = more smoothing
    
    init() {
        self.log2n = vDSP_Length(log2(Float(fftSize)))
        self.fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
        
        // Initialize smoothing array
        self.previousBars = [Float](repeating: 0, count: barCount)
    }
    
    /// Load an audio file for analysis
    func loadFile(url: URL) throws {
        audioFile = try AVAudioFile(forReading: url)
    }
    
    /// Start analyzing the file synchronized with playback time
    func startAnalysis(playbackTimeProvider: @escaping () -> TimeInterval) {
        guard let file = audioFile else { return }
        
        // Start a timer to analyze audio in sync with playback
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            let currentTime = playbackTimeProvider()
            let sampleRate = file.processingFormat.sampleRate
            let framePosition = AVAudioFramePosition(currentTime * sampleRate)
            
            // Read audio data at current playback position
            if framePosition < file.length {
                let frameCount = min(AVAudioFrameCount(self.fftSize), AVAudioFrameCount(file.length - framePosition))
                
                guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frameCount) else { return }
                
                do {
                    file.framePosition = framePosition
                    try file.read(into: buffer, frameCount: frameCount)
                    self.processBuffer(buffer)
                } catch {
                    // // Error occurred
                }
            }
        }
    }
    
    /// Stop analysis
    func stopAnalysis() {
        timer?.invalidate()
        timer = nil
    }
    
    private func processBuffer(_ buffer: AVAudioPCMBuffer) {
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
                let dynamicRange: Float = 50.0 // dB dynamic range (reduced for better scaling)
                let minDB: Float = -dynamicRange
                let maxDB: Float = -5.0 // Adjusted to boost overall levels
                
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
                
                DispatchQueue.main.async {
                    self.delegate?.didUpdateSpectrum(bars)
                }
            }
        }
    }
    
    private func reduceToBars(magnitudes: [Float]) -> [Float] {
        let binCount = magnitudes.count
        var bars = [Float](repeating: 0, count: barCount)
        
        for i in 0..<barCount {
            let minFreq = Float(20) * pow(Float(22050/20), Float(i) / Float(barCount))
            let maxFreq = Float(20) * pow(Float(22050/20), Float(i + 1) / Float(barCount))
            
            let minBin = Int(minFreq * Float(binCount) / 22050)
            let maxBin = min(binCount - 1, Int(maxFreq * Float(binCount) / 22050))
            
            var sum: Float = 0
            var count = 0
            
            for bin in minBin...maxBin where bin < binCount {
                sum += magnitudes[bin]
                count += 1
            }
            
            if count > 0 {
                bars[i] = sum / Float(count)
            }
        }
        
        // Apply smoothing using exponential moving average
        for i in 0..<barCount {
            let currentValue = bars[i]
            let previousValue = previousBars[i]
            
            // Smooth the values, but allow quick rises and slow falls
            if currentValue > previousValue {
                // Allow quick rises
                bars[i] = currentValue * 0.9 + previousValue * 0.1
            } else {
                // Slow falls
                bars[i] = currentValue * 0.3 + previousValue * 0.7
            }
            
            previousBars[i] = bars[i]
        }
        
        return bars
    }
    
    deinit {
        if let fftSetup = fftSetup {
            vDSP_destroy_fftsetup(fftSetup)
        }
    }
}
