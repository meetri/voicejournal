//
//  SpectrumAnalyzerService.swift
//  voicejournal
//
//  Created on 5/4/2025.
//

import Foundation
import AVFoundation
import Combine

/// Protocol for receiving spectrum analyzer updates
protocol SpectrumAnalyzerDelegate: AnyObject {
    /// Called when new frequency data is available
    /// - Parameter frequencyData: The frequency data in decibels
    func didUpdateFrequencyData(_ frequencyData: [Float])
}

/// A service that analyzes audio frequency spectrum using GPU-accelerated FFT
class SpectrumAnalyzerService {
    // MARK: - Properties
    
    /// The audio engine
    private var audioEngine: AVAudioEngine
    
    /// The Metal FFT service
    private var fftService: MetalFFTService?
    
    /// The audio buffer size for FFT
    private let bufferSize: UInt32
    
    /// The sample rate of the audio
    private var sampleRate: Double = 44100
    
    /// The frequency bins for visualization
    private let frequencyBinCount: Int
    
    /// The delegate to receive frequency updates
    weak var delegate: SpectrumAnalyzerDelegate?
    
    /// Whether the analyzer is active
    private var isActive = false
    
    /// A buffer for audio samples
    private var audioSampleBuffer: [Float]
    
    /// The background queue for processing
    private let processingQueue = DispatchQueue(label: "com.voicejournal.spectrumanalyzer.processing", qos: .userInteractive)
    
    /// A publisher for frequency data
    private let frequencyDataSubject = PassthroughSubject<[Float], Never>()
    
    /// Frequency data publisher for Combine subscribers
    var frequencyDataPublisher: AnyPublisher<[Float], Never> {
        return frequencyDataSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    /// Initializes the spectrum analyzer service
    /// - Parameters:
    ///   - bufferSize: The buffer size for FFT processing (must be a power of 2)
    ///   - frequencyBinCount: The number of frequency bins for visualization
    init(bufferSize: UInt32 = 2048, frequencyBinCount: Int = 64) {
        self.bufferSize = bufferSize
        self.frequencyBinCount = frequencyBinCount
        self.audioEngine = AVAudioEngine()
        self.audioSampleBuffer = [Float](repeating: 0, count: Int(bufferSize))
        
        setupFFTService()
        // Don't automatically set up audio engine - we'll do this only when needed
    }
    
    // MARK: - Public Methods
    
    /// Starts the spectrum analyzer
    /// - Throws: An error if the audio engine fails to start
    func start() throws {
        if !isActive {
            // Set up the audio engine before starting it
            try setupAudioEngine()
            
            // Start the audio engine
            try audioEngine.start()
            isActive = true
        }
    }
    
    /// Stops the spectrum analyzer
    func stop() {
        if isActive {
            // Stop the audio engine
            audioEngine.stop()
            
            // Remove the tap to release resources
            if audioEngine.inputNode.numberOfInputs > 0 {
                audioEngine.inputNode.removeTap(onBus: 0)
            }
            
            isActive = false
        }
    }
    
    // MARK: - Private Methods
    
    /// Sets up the Metal FFT service
    private func setupFFTService() {
        fftService = MetalFFTService(fftSize: bufferSize)
        if fftService == nil {
            print("Warning: Failed to initialize Metal FFT service. Frequency analysis will not be available.")
        }
    }
    
    /// Sets up the audio engine for capturing audio
    /// - Throws: An error if the audio engine setup fails
    private func setupAudioEngine() throws {
        // Check if the audio session is active and configured properly
        let audioSession = AVAudioSession.sharedInstance()
        if audioSession.category != .playAndRecord {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
        }
        
        // Get the sample rate from the audio format
        let format = audioEngine.inputNode.outputFormat(forBus: 0)
        
        // Validate the format to avoid Core Audio crashes
        guard format.sampleRate > 0 && format.channelCount > 0 else {
            throw NSError(domain: "com.voicejournal.spectrum", 
                          code: 1, 
                          userInfo: [NSLocalizedDescriptionKey: "Invalid audio format"])
        }
        
        sampleRate = format.sampleRate
        
        // Clean up any previous tap that might exist
        audioEngine.inputNode.removeTap(onBus: 0)
        
        // Install a new tap on the input node to get audio samples
        audioEngine.inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, time in
            self?.processSamples(buffer: buffer)
        }
        
        // Prepare the engine
        audioEngine.prepare()
    }
    
    /// Processes audio samples from the buffer
    /// - Parameter buffer: The audio buffer
    private func processSamples(buffer: AVAudioPCMBuffer) {
        guard let fftService = fftService,
              let channelData = buffer.floatChannelData?[0],
              buffer.frameLength > 0 else {
            return
        }
        
        // Copy samples to our buffer
        for i in 0..<min(Int(bufferSize), Int(buffer.frameLength)) {
            audioSampleBuffer[i] = channelData[i]
        }
        
        // Process on a background queue
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Apply window function (Hann window) to reduce spectral leakage
            var windowedSamples = [Float](repeating: 0, count: Int(self.bufferSize))
            for i in 0..<Int(self.bufferSize) {
                let windowValue = 0.5 * (1 - cos(2 * Float.pi * Float(i) / Float(self.bufferSize - 1)))
                windowedSamples[i] = self.audioSampleBuffer[i] * windowValue
            }
            
            // Perform FFT
            if let magnitudes = fftService.performFFT(samples: windowedSamples) {
                // Convert to decibels and normalize
                let decibelMagnitudes = self.processFFTMagnitudesToDecibels(magnitudes: magnitudes)
                
                // Bin the frequencies
                let binnedFrequencies = self.binFrequencies(decibelMagnitudes)
                
                // Notify delegate on main thread
                DispatchQueue.main.async {
                    self.delegate?.didUpdateFrequencyData(binnedFrequencies)
                    self.frequencyDataSubject.send(binnedFrequencies)
                }
            }
        }
    }
    
    /// Converts FFT magnitudes to decibels and normalizes them
    /// - Parameter magnitudes: The raw FFT magnitudes
    /// - Returns: The processed magnitudes in decibels
    private func processFFTMagnitudesToDecibels(magnitudes: [Float]) -> [Float] {
        let minDB: Float = -100  // Minimum decibel value
        let maxDB: Float = 0     // Maximum decibel value
        
        var decibelMagnitudes = [Float](repeating: 0, count: magnitudes.count)
        
        for i in 0..<magnitudes.count {
            // Convert to decibels (log scale)
            let magnitude = magnitudes[i]
            var decibels = 20 * log10(magnitude + 1e-9)  // Add small value to avoid log(0)
            
            // Clamp to range
            decibels = max(minDB, min(maxDB, decibels))
            
            // Normalize to 0.0-1.0 range
            decibelMagnitudes[i] = (decibels - minDB) / (maxDB - minDB)
        }
        
        return decibelMagnitudes
    }
    
    /// Bins frequencies for visualization
    /// - Parameter magnitudes: The processed FFT magnitudes
    /// - Returns: The binned frequencies for visualization
    private func binFrequencies(_ magnitudes: [Float]) -> [Float] {
        let fftSize = magnitudes.count
        var binned = [Float](repeating: 0, count: frequencyBinCount)
        
        // Use a logarithmic scale for frequency bins to better match human hearing
        for binIndex in 0..<frequencyBinCount {
            let startFreqNormalized = pow(10, log10(1 + 19) * Float(binIndex) / Float(frequencyBinCount)) / 20
            let endFreqNormalized = pow(10, log10(1 + 19) * Float(binIndex + 1) / Float(frequencyBinCount)) / 20
            
            let startIndex = Int(startFreqNormalized * Float(fftSize))
            let endIndex = min(fftSize, Int(endFreqNormalized * Float(fftSize)))
            
            if endIndex > startIndex {
                var sum: Float = 0
                for i in startIndex..<endIndex {
                    sum += magnitudes[i]
                }
                
                binned[binIndex] = sum / Float(endIndex - startIndex)
            }
        }
        
        return binned
    }
    
    /// Computes the frequency for a given FFT bin index
    /// - Parameter binIndex: The bin index
    /// - Returns: The frequency in Hz
    private func frequencyForBin(binIndex: Int) -> Float {
        return Float(binIndex) * Float(sampleRate) / Float(bufferSize)
    }
}