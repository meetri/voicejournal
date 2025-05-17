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
    
    init() {
        self.log2n = vDSP_Length(log2(Float(fftSize)))
        self.fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
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
                    print("Error reading audio file: \(error)")
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
        
        return bars
    }
    
    deinit {
        if let fftSetup = fftSetup {
            vDSP_destroy_fftsetup(fftSetup)
        }
    }
}