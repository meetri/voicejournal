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
    
    // Always use spectrum analyzer style
    
    // MARK: - View Model
    
    /// The view model for managing waveform state
    @StateObject private var viewModel: WaveformViewModel
    
    
    /// External frequency data for spectrum visualization
    var frequencyData: [Float] = []
    
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
        frequencyData: [Float] = []
    ) {
        self.audioLevel = audioLevel
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor ?? primaryColor.opacity(0.6)
        self.barCount = barCount
        self.spacing = spacing
        self.isActive = isActive
        self.frequencyData = frequencyData
        
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
            
            // Always use spectrum visualization
            GeometryReader { geometry in
                if !frequencyData.isEmpty {
                    // Use the frequency data directly
                    Canvas { context, size in
                        let barCount = frequencyData.count
                        let barSpacing: CGFloat = 2
                        let barWidth = (size.width - (barSpacing * CGFloat(barCount - 1))) / CGFloat(barCount)
                        
                        for i in 0..<barCount {
                            let level = frequencyData[i]
                            let barHeight = min(size.height, max(2, CGFloat(level) * size.height * 2.0))
                            let x = CGFloat(i) * (barWidth + barSpacing)
                            let y = size.height - barHeight
                            
                            let barRect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
                            let barPath = Path(roundedRect: barRect, cornerRadius: 2)
                            
                            let color = primaryColor.opacity(Double(level * 0.8 + 0.2))
                            context.fill(barPath, with: .color(color))
                        }
                    }
                } else {
                    // Fallback to empty spectrum if no data
                    Rectangle()
                        .fill(Color.clear)
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
        }
        .onChange(of: isActive) { oldValue, newValue in
            // Update the view model with the new active state
            viewModel.update(audioLevel: audioLevel, isActive: newValue)
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
        }
    }
    
    // MARK: - Waveform Styles
    
    // Removed old waveform styles (bars, curve, circles) - always using spectrum now
}

// MARK: - Waveform Style Enum

// WaveformStyle enum removed - always using spectrum analyzer now

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Active spectrum analyzer
        EnhancedWaveformView(
            audioLevel: 0.8,
            primaryColor: .blue,
            secondaryColor: .purple,
            isActive: true,
            frequencyData: [0.3, 0.5, 0.7, 0.6, 0.4, 0.3, 0.5, 0.6, 0.7, 0.8, 0.6, 0.4, 0.3, 0.2, 0.3, 0.4, 0.5, 0.6, 0.5, 0.4, 0.3, 0.2, 0.3, 0.4, 0.5, 0.4, 0.3, 0.2, 0.1, 0.2]
        )
        .frame(height: 80)
        .padding()
        
        // Inactive spectrum analyzer
        EnhancedWaveformView(
            audioLevel: 0.0,
            primaryColor: .gray,
            secondaryColor: .gray.opacity(0.5),
            isActive: false,
            frequencyData: []
        )
        .frame(height: 60)
        .padding()
    }
    .padding()
    .background(Color(.systemBackground))
}
