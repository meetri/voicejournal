//
//  WaveformView.swift
//  voicejournal
//
//  Created on 4/27/25.
//

import SwiftUI

/// A view that displays an audio waveform visualization
struct WaveformView: View {
    // MARK: - Properties
    
    /// The audio level to visualize (0.0 to 1.0)
    var audioLevel: CGFloat
    
    /// The color of the waveform
    var color: Color = .blue
    
    /// The number of bars to display in the waveform
    var barCount: Int = 20
    
    /// The spacing between bars
    var spacing: CGFloat = 3
    
    /// The corner radius of the bars
    var cornerRadius: CGFloat = 4
    
    /// Whether the waveform is active (recording)
    var isActive: Bool = true
    
    // MARK: - View Model
    
    /// The view model for managing waveform state
    @StateObject private var viewModel: WaveformViewModel
    
    // MARK: - Initialization
    
    init(audioLevel: CGFloat, color: Color = .blue, barCount: Int = 30, spacing: CGFloat = 4, cornerRadius: CGFloat = 4, isActive: Bool = true) {
        self.audioLevel = audioLevel
        self.color = color
        self.barCount = barCount
        self.spacing = spacing
        self.cornerRadius = cornerRadius
        self.isActive = isActive
        
        // Initialize the view model
        _viewModel = StateObject(wrappedValue: WaveformViewModel(barCount: barCount))
    }
    
    // MARK: - Body
    
    var body: some View {
        Canvas { context, size in
            // Draw the waveform
            drawWaveform(context: context, size: size)
        }
        .onAppear {
            print("DEBUG: WaveformView appeared with audioLevel: \(audioLevel), isActive: \(isActive)")
            
            // Update the view model with the current audio level and active state
            viewModel.update(audioLevel: audioLevel, isActive: isActive)
        }
        .onChange(of: audioLevel) { oldValue, newValue in
            print("DEBUG: WaveformView audioLevel changed from \(oldValue) to \(newValue)")
            
            // Update the view model with the new audio level
            viewModel.update(audioLevel: newValue, isActive: isActive)
        }
        .onChange(of: isActive) { oldValue, newValue in
            print("DEBUG: WaveformView isActive changed from \(oldValue) to \(newValue)")
            
            // Update the view model with the new active state
            viewModel.update(audioLevel: audioLevel, isActive: newValue)
        }
        // Add a timer to ensure continuous updates even if audioLevel doesn't change
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
            if isActive {
                // Force a small update to keep the animation going
                viewModel.update(audioLevel: audioLevel, isActive: true)
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Draw the waveform on the canvas
    private func drawWaveform(context: GraphicsContext, size: CGSize) {
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
            let barPath = Path(roundedRect: barRect, cornerRadius: cornerRadius)
            
            // Draw bar with gradient
            context.fill(
                barPath,
                with: .linearGradient(
                    Gradient(colors: [color.opacity(0.7), color]),
                    startPoint: CGPoint(x: x, y: y + barHeight),
                    endPoint: CGPoint(x: x, y: y)
                )
            )
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Inactive waveform
        WaveformView(audioLevel: 0.0, color: .gray, isActive: false)
            .frame(height: 50)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        
        // Low level waveform
        WaveformView(audioLevel: 0.2, color: .blue, isActive: true)
            .frame(height: 50)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        
        // Medium level waveform
        WaveformView(audioLevel: 0.5, color: .green, isActive: true)
            .frame(height: 50)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        
        // High level waveform
        WaveformView(audioLevel: 0.8, color: .red, isActive: true)
            .frame(height: 50)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
    }
    .padding()
}
