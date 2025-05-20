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

/// A service that analyzes audio frequency spectrum using AVFoundation and Accelerate
class SpectrumAnalyzerService: AudioSpectrumDelegate {
    // MARK: - Properties
    
    /// The audio spectrum manager
    private var audioSpectrumManager: AudioSpectrumManager
    
    /// The frequency bins for visualization
    private let frequencyBinCount: Int
    
    /// The delegate to receive frequency updates
    weak var delegate: SpectrumAnalyzerDelegate?
    
    /// Whether the analyzer is active
    private var isActive = false
    
    /// A publisher for frequency data
    private let frequencyDataSubject = PassthroughSubject<[Float], Never>()
    
    /// Frequency data publisher for Combine subscribers
    var frequencyDataPublisher: AnyPublisher<[Float], Never> {
        return frequencyDataSubject.eraseToAnyPublisher()
    }
    
    /// The type of analysis (microphone or playback)
    private var analysisType: AnalysisType = .microphone
    
    // MARK: - Initialization
    
    /// Initializes the spectrum analyzer service
    /// - Parameters:
    ///   - bufferSize: The buffer size for FFT processing (must be a power of 2)
    ///   - frequencyBinCount: The number of frequency bins for visualization
    init(bufferSize: UInt32 = 2048, frequencyBinCount: Int = 64) {
        self.frequencyBinCount = frequencyBinCount
        self.audioSpectrumManager = AudioSpectrumManager(fftSize: Int(bufferSize), barCount: frequencyBinCount)
        
        // Set up delegate
        self.audioSpectrumManager.delegate = self
    }
    
    // MARK: - Public Methods
    
    /// Starts the spectrum analyzer
    /// - Throws: An error if the audio engine fails to start
    func start() throws {
        if !isActive {
            // Start the appropriate analysis based on the current type
            switch analysisType {
            case .microphone:
                audioSpectrumManager.startMicrophoneAnalysis()
            case .playback(let url):
                audioSpectrumManager.startPlaybackAnalysis(fileURL: url)
            }
            
            isActive = true
        }
    }
    
    /// Process audio buffer directly (for use with shared audio engine)
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isActive else { return }
        audioSpectrumManager.processExternalBuffer(buffer)
    }
    
    /// Starts microphone analysis
    func startMicrophoneAnalysis() {
        // Stop any existing analysis first
        audioSpectrumManager.stopAnalysis()
        
        analysisType = .microphone
        if isActive {
            audioSpectrumManager.startMicrophoneAnalysis()
        }
    }
    
    /// Starts playback analysis
    /// - Parameter fileURL: The URL of the audio file to analyze
    func startPlaybackAnalysis(fileURL: URL) {
        // Stop any existing analysis first
        audioSpectrumManager.stopAnalysis()
        
        analysisType = .playback(fileURL)
        if isActive {
            print("🔈 [SpectrumAnalyzerService] Starting playback analysis for: \(fileURL.lastPathComponent)")
            audioSpectrumManager.startPlaybackAnalysis(fileURL: fileURL)
        } else {
            print("🔇 [SpectrumAnalyzerService] Not active, deferring playback analysis")
        }
    }
    
    /// Stops the spectrum analyzer
    func stop() {
        if isActive {
            audioSpectrumManager.stopAnalysis()
            isActive = false
        }
    }
    
    // MARK: - AudioSpectrumDelegate
    
    func didUpdateSpectrum(_ bars: [Float]) {
        // Process the spectrum data and convert to decibels if needed
        let processedData = processSpectrumData(bars)
        
        // Debug log to check if we're getting data
        if processedData.contains(where: { $0 > 0 }) {
            // Only occasionally log to avoid spam
            if Int.random(in: 0...100) < 1 {  // ~1% chance to log
                print("📈 [SpectrumAnalyzerService] Got non-zero frequency data: \(processedData.prefix(5))...")
            }
        } else {
            // Log more frequently when there's no data, as this is an error condition
            if Int.random(in: 0...100) < 10 {  // ~10% chance to log
                print("⚠️ [SpectrumAnalyzerService] Received all-zero frequency data from AudioSpectrumManager")
            }
        }
        
        // Notify delegate and publisher
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.didUpdateFrequencyData(processedData)
            self?.frequencyDataSubject.send(processedData)
        }
    }
    
    // MARK: - Private Methods
    
    /// Processes spectrum data for visualization
    /// - Parameter bars: The raw spectrum data
    /// - Returns: The processed spectrum data
    private func processSpectrumData(_ bars: [Float]) -> [Float] {
        // Apply visual amplification to make the visualization more responsive
        let visualAmplification: Float = 1.8
        return bars.map { min(1.0, $0 * visualAmplification) }
    }
    
    // MARK: - Types
    
    /// The type of analysis being performed
    private enum AnalysisType {
        case microphone
        case playback(URL)
    }
}