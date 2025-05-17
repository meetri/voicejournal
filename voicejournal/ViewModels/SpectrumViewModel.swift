//
//  SpectrumViewModel.swift
//  voicejournal
//
//  Created on 5/4/2025.
//

import Foundation
import SwiftUI
import Combine

/// ViewModel for the spectrum analyzer
class SpectrumViewModel: ObservableObject, SpectrumAnalyzerDelegate {
    // MARK: - Published Properties
    
    /// The frequency data for visualization
    @Published var frequencyData: [Float] = []
    
    /// The peak frequency data (for peak hold visualization)
    @Published var peakFrequencyData: [Float] = []
    
    /// Whether the spectrum analyzer is active
    @Published var isActive: Bool = false
    
    /// The primary color for the spectrum visualization
    @Published var primaryColor: Color = .blue
    
    /// The secondary color for the spectrum visualization
    @Published var secondaryColor: Color = .purple
    
    /// The color mode for the spectrum visualization
    @Published var colorMode: SpectrumColorMode = .gradient
    
    /// The decay speed for the peaks (0.0-1.0)
    @Published var peakDecay: Float = 0.05
    
    /// Whether to show peak hold indicators
    @Published var showPeakHold: Bool = true
    
    // MARK: - Private Properties
    
    /// The spectrum analyzer service
    private let spectrumAnalyzerService: SpectrumAnalyzerService
    
    /// Cancellable for the subscription to frequency data
    private var frequencyDataCancellable: AnyCancellable?
    
    /// Timer for updating the peaks
    private var peakDecayTimer: Timer?
    
    // MARK: - Initialization
    
    /// Initializes the spectrum view model
    /// - Parameter service: The spectrum analyzer service (creates a new one if nil)
    init(service: SpectrumAnalyzerService? = nil) {
        // Use the provided service or create a new one
        self.spectrumAnalyzerService = service ?? SpectrumAnalyzerService(frequencyBinCount: 64)
        
        // Set up the delegate
        self.spectrumAnalyzerService.delegate = self
        
        // Subscribe to frequency data updates
        setupSubscriptions()
        
        // Set up peak decay timer
        setupPeakDecayTimer()
    }
    
    // MARK: - Public Methods
    
    /// Starts the spectrum analyzer
    func start() {
        if isActive {
            return // Already active
        }
        
        // Try to start the service, but don't crash if it fails
        do {
            try spectrumAnalyzerService.start()
            isActive = true
        } catch {
            // Failed to start spectrum analyzer
            // If we can't start the spectrum analyzer, we'll just not show any data
            // but we won't crash the app
        }
    }
    
    /// Stops the spectrum analyzer
    func stop() {
        spectrumAnalyzerService.stop()
        isActive = false
    }
    
    /// Sets the color mode for the spectrum visualization
    /// - Parameter mode: The color mode
    func setColorMode(_ mode: SpectrumColorMode) {
        colorMode = mode
    }
    
    /// Sets the peak decay speed
    /// - Parameter decay: The decay speed (0.0-1.0)
    func setPeakDecay(_ decay: Float) {
        peakDecay = max(0.001, min(0.2, decay))
    }
    
    /// Toggles peak hold indicators
    func togglePeakHold() {
        showPeakHold.toggle()
    }
    
    // MARK: - SpectrumAnalyzerDelegate
    
    func didUpdateFrequencyData(_ frequencyData: [Float]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Update frequency data
            self.frequencyData = frequencyData
            
            // Update peak data
            self.updatePeakData(newData: frequencyData)
        }
    }
    
    // MARK: - Private Methods
    
    /// Sets up subscriptions to frequency data updates
    private func setupSubscriptions() {
        frequencyDataCancellable = spectrumAnalyzerService.frequencyDataPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] data in
                guard let self = self else { return }
                
                self.frequencyData = data
                self.updatePeakData(newData: data)
            }
    }
    
    /// Sets up the timer for peak decay
    private func setupPeakDecayTimer() {
        peakDecayTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self, self.showPeakHold else { return }
            
            DispatchQueue.main.async {
                self.decayPeaks()
            }
        }
    }
    
    /// Updates the peak data based on new frequency data
    /// - Parameter newData: The new frequency data
    private func updatePeakData(newData: [Float]) {
        // Initialize peak data if needed
        if peakFrequencyData.isEmpty {
            peakFrequencyData = Array(repeating: 0, count: newData.count)
        }
        
        // Update peak values
        for i in 0..<min(newData.count, peakFrequencyData.count) {
            if newData[i] > peakFrequencyData[i] {
                peakFrequencyData[i] = newData[i]
            }
        }
    }
    
    /// Decays the peak values over time
    private func decayPeaks() {
        for i in 0..<peakFrequencyData.count {
            peakFrequencyData[i] = max(0, peakFrequencyData[i] - peakDecay)
        }
    }
    
    /// Gets a color for a frequency bin based on the current color mode
    /// - Parameters:
    ///   - index: The bin index
    ///   - count: The total number of bins
    ///   - value: The normalized value (0.0-1.0)
    /// - Returns: The color for the bin
    func colorForBin(index: Int, count: Int, value: Float) -> Color {
        switch colorMode {
        case .gradient:
            return primaryColor.opacity(Double(value))
            
        case .spectrum:
            // Color spectrum (blue to purple to red)
            let hue = 0.7 - (0.7 * Double(index) / Double(count))
            return Color(hue: hue, saturation: 1.0, brightness: Double(value) * 0.8 + 0.2)
            
        case .heatmap:
            // Heatmap (blue, green, yellow, red)
            let stops: [(color: Color, position: CGFloat)] = [
                (.blue, 0.0),
                (.green, 0.4),
                (.yellow, 0.7),
                (.red, 1.0)
            ]
            
            let position = CGFloat(index) / CGFloat(count)
            var resultColor = stops.last!.color
            
            for i in 0..<stops.count-1 {
                let current = stops[i]
                let next = stops[i+1]
                
                if position >= current.position && position <= next.position {
                    let t = (position - current.position) / (next.position - current.position)
                    resultColor = blend(color1: current.color, color2: next.color, factor: t)
                    break
                }
            }
            
            return resultColor.opacity(Double(value) * 0.8 + 0.2)
        }
    }
    
    /// Blends two colors
    /// - Parameters:
    ///   - color1: The first color
    ///   - color2: The second color
    ///   - factor: The blend factor (0.0-1.0)
    /// - Returns: The blended color
    private func blend(color1: Color, color2: Color, factor: CGFloat) -> Color {
        // For simple blending, just return the color based on the factor
        // A more sophisticated approach would blend in RGB space
        return factor < 0.5 ? color1 : color2
    }
}

/// The color mode for the spectrum visualization
enum SpectrumColorMode: String, CaseIterable, Identifiable {
    /// Single color gradient
    case gradient = "Gradient"
    
    /// Full color spectrum
    case spectrum = "Spectrum"
    
    /// Heatmap (blue to red)
    case heatmap = "Heatmap"
    
    var id: String { rawValue }
}