//
//  EnhancedWaveformView.swift
//  voicejournal
//
//  Created on 4/28/25.
//

import SwiftUI
import AVFoundation

/// An enhanced view that displays an audio waveform visualization with animations and effects
struct EnhancedWaveformView: View {
    // MARK: - Properties
    
    /// The audio level to visualize (0.0 to 1.0)
    var audioLevel: CGFloat
    
    /// The primary color of the waveform
    var primaryColor: Color = .blue
    
    /// The secondary color for gradient effects
    var secondaryColor: Color = .purple
    
    /// The number of bars to display in the waveform
    var barCount: Int = 30
    
    /// The spacing between bars
    var spacing: CGFloat = 3
    
    /// Whether the waveform is active (recording/playing)
    var isActive: Bool = true
    
    /// The style of the waveform
    var style: WaveformStyle = .bars
    
    // MARK: - View Model
    
    /// The view model for managing waveform state
    @StateObject private var viewModel: WaveformViewModel
    
    /// The view model for spectrum analysis
    @StateObject private var spectrumViewModel = SpectrumViewModel()
    
    // MARK: - State
    
    // State variable to trigger view refreshes
    @State private var refreshTrigger = false
    
    // MARK: - Initialization
    
    init(
        audioLevel: CGFloat,
        primaryColor: Color = .blue,
        secondaryColor: Color? = nil,
        barCount: Int = 30,
        spacing: CGFloat = 3,
        isActive: Bool = true,
        style: WaveformStyle = .bars
    ) {
        self.audioLevel = audioLevel
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor ?? primaryColor.opacity(0.6)
        self.barCount = barCount
        self.spacing = spacing
        self.isActive = isActive
        self.style = style
        
        // Initialize the view model
        _viewModel = StateObject(wrappedValue: WaveformViewModel(barCount: barCount))
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Simplified background without gradient
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            primaryColor.opacity(0.2),
                            lineWidth: 1
                        )
                )
            
            // Waveform visualization based on selected style
            Group {
                switch style {
                case .bars:
                    barsWaveform
                case .curve:
                    curveWaveform
                case .circles:
                    circlesWaveform
                case .spectrum:
                    // Use the new SpectrumAnalyzerView for spectrum visualization
                    GeometryReader { geometry in
                        SpectrumAnalyzerView(
                            viewModel: spectrumViewModel,
                            height: geometry.size.height,
                            style: .bars,
                            useHardwareAcceleration: true
                        )
                    }
                }
            }
            .padding(8)
            
            // Simplified indicator when active (no animation)
            if isActive && audioLevel > 0.1 {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        primaryColor.opacity(0.3),
                        lineWidth: 1
                    )
            }
        }
        .onAppear {
            // Update the view model with the current audio level and active state
            viewModel.update(audioLevel: audioLevel, isActive: isActive)
        }
        .onChange(of: audioLevel) { oldValue, newValue in
            // Update the view model with the new audio level
            viewModel.update(audioLevel: newValue, isActive: isActive)
            
            // Handle spectrum analyzer updates
            if style == .spectrum {
                // Only attempt to start the spectrum analyzer when needed
                if isActive && audioLevel > 0.01 {
                    // Start the analyzer if it's not already active
                    if !spectrumViewModel.isActive {
                        spectrumViewModel.start()
                    }
                    
                    // Provide minimal visual feedback in case audio engine fails
                    // This uses the audio level but doesn't try to simulate spectral data
                    spectrumViewModel.updateWithMinimalVisualization(level: Float(audioLevel))
                } else {
                    // If we're not active, stop the analyzer to save resources
                    spectrumViewModel.stop()
                }
            } else {
                // If we're not in spectrum mode, ensure the analyzer is stopped
                spectrumViewModel.stop()
            }
        }
        .onChange(of: isActive) { oldValue, newValue in
            // Update the view model with the new active state
            viewModel.update(audioLevel: audioLevel, isActive: newValue)
            
            // Handle spectrum analyzer when activity state changes
            if style == .spectrum {
                if newValue && audioLevel > 0.01 {
                    spectrumViewModel.start()
                } else {
                    spectrumViewModel.stop()
                }
            }
        }
        .onChange(of: style) { oldValue, newValue in
            // When changing to spectrum style, start the analyzer if active
            if newValue == .spectrum && isActive && audioLevel > 0.01 {
                spectrumViewModel.start()
            } 
            // When changing away from spectrum style, stop the analyzer
            else if oldValue == .spectrum {
                spectrumViewModel.stop()
            }
        }
        // Add an efficient animation timer that only updates the visual state
        // without creating new arrays or doing heavy processing
        .onReceive(Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()) { _ in
            if isActive {
                // Only trigger a visual refresh without heavy data processing
                // This creates the appearance of smoother animation without the memory overhead
                refreshTrigger.toggle()
            }
        }
        .onDisappear {
            // Ensure we clean up resources when the view disappears
            viewModel.stopTimer()
            
            // Always stop the spectrum analyzer when the view disappears
            spectrumViewModel.stop()
        }
    }
    
    // MARK: - Waveform Styles
    
    /// Bars style waveform visualization
    private var barsWaveform: some View {
        Canvas { context, size in
            // Using refreshTrigger to ensure canvas redraws when timer fires
            let _ = refreshTrigger
            // Calculate bar width based on available space
            let barWidth = (size.width - (spacing * CGFloat(barCount - 1))) / CGFloat(barCount)
            
            // Draw each bar
            for i in 0..<barCount {
                if viewModel.levelHistory.count <= i {
                    continue
                }
                
                let level = viewModel.levelHistory[i]
                
                // Calculate bar height based on level (minimum 2 pixels)
                let barHeight = max(2, level * size.height)
                
                // Calculate bar position
                let x = CGFloat(i) * (barWidth + spacing)
                let y = (size.height - barHeight) / 2
                
                // Create bar path
                let barRect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
                let barPath = Path(roundedRect: barRect, cornerRadius: 4)
                
                // Draw bar with solid color instead of gradient for better performance
                context.fill(
                    barPath,
                    with: .color(primaryColor)
                )
            }
        }
    }
    
    /// Curve style waveform visualization
    private var curveWaveform: some View {
        Canvas { context, size in
            // Using refreshTrigger to ensure canvas redraws when timer fires
            let _ = refreshTrigger
            // Create a path for the waveform curve
            var path = Path()
            
            // Start at the left edge
            path.move(to: CGPoint(x: 0, y: size.height / 2))
            
            // Calculate points for the curve
            let pointCount = min(barCount, viewModel.levelHistory.count)
            let pointSpacing = size.width / CGFloat(pointCount - 1)
            
            for i in 0..<pointCount {
                let level = viewModel.levelHistory[i]
                let x = CGFloat(i) * pointSpacing
                let y = (size.height / 2) - (level * size.height / 2)
                
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            
            // Mirror the curve for the bottom half
            for i in (0..<pointCount).reversed() {
                let level = viewModel.levelHistory[i]
                let x = CGFloat(i) * pointSpacing
                let y = (size.height / 2) + (level * size.height / 2)
                
                path.addLine(to: CGPoint(x: x, y: y))
            }
            
            // Close the path
            path.closeSubpath()
            
            // Fill the path with solid color for better performance
            context.fill(
                path,
                with: .color(primaryColor.opacity(0.7))
            )
        }
    }
    
    /// Circles style waveform visualization
    private var circlesWaveform: some View {
        Canvas { context, size in
            // Using refreshTrigger to ensure canvas redraws when timer fires
            let _ = refreshTrigger
            // Calculate circle spacing based on available space
            let circleSpacing = size.width / CGFloat(barCount)
            let maxRadius = min(circleSpacing / 2 - 1, size.height / 2 - 1)
            
            // Draw each circle
            for i in 0..<barCount {
                if viewModel.levelHistory.count <= i {
                    continue
                }
                
                let level = viewModel.levelHistory[i]
                
                // Calculate circle radius based on level
                let radius = max(2, level * maxRadius)
                
                // Calculate circle position
                let x = CGFloat(i) * circleSpacing + circleSpacing / 2
                let y = size.height / 2
                
                // Create circle path
                let circleRect = CGRect(
                    x: x - radius,
                    y: y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                let circlePath = Path(ellipseIn: circleRect)
                
                // Draw circle with solid color for better performance
                context.fill(
                    circlePath,
                    with: .color(primaryColor)
                )
            }
        }
    }
}

// MARK: - Waveform Style Enum

/// The style of the waveform visualization
enum WaveformStyle {
    /// Traditional bar-style visualization
    case bars
    
    /// Curved line visualization
    case curve
    
    /// Circles visualization
    case circles
    
    /// Spectrum analyzer visualization
    case spectrum
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Bars style waveform
        EnhancedWaveformView(
            audioLevel: 0.5,
            primaryColor: .blue,
            secondaryColor: .purple,
            isActive: true,
            style: .bars
        )
        .frame(height: 60)
        .padding()
        
        // Curve style waveform
        EnhancedWaveformView(
            audioLevel: 0.7,
            primaryColor: .green,
            secondaryColor: .blue,
            isActive: true,
            style: .curve
        )
        .frame(height: 60)
        .padding()
        
        // Circles style waveform
        EnhancedWaveformView(
            audioLevel: 0.6,
            primaryColor: .orange,
            secondaryColor: .red,
            isActive: true,
            style: .circles
        )
        .frame(height: 60)
        .padding()
        
        // Spectrum analyzer waveform
        EnhancedWaveformView(
            audioLevel: 0.8,
            primaryColor: .blue,
            secondaryColor: .purple,
            isActive: true,
            style: .spectrum
        )
        .frame(height: 80)
        .padding()
        
        // Inactive waveform
        EnhancedWaveformView(
            audioLevel: 0.0,
            primaryColor: .gray,
            secondaryColor: .gray.opacity(0.5),
            isActive: false,
            style: .bars
        )
        .frame(height: 60)
        .padding()
    }
    .padding()
    .background(Color(.systemBackground))
}
