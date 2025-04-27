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
    var barCount: Int = 30
    
    /// The spacing between bars
    var spacing: CGFloat = 3
    
    /// The corner radius of the bars
    var cornerRadius: CGFloat = 3
    
    /// Whether the waveform is active (recording)
    var isActive: Bool = true
    
    /// The history of audio levels for animation
    @State private var levelHistory: [CGFloat] = []
    
    /// Timer for updating the waveform
    @State private var timer: Timer? = nil
    
    // MARK: - Body
    
    var body: some View {
        Canvas { context, size in
            // Draw the waveform
            drawWaveform(context: context, size: size)
        }
        .onAppear {
            // Initialize level history
            levelHistory = Array(repeating: 0, count: barCount)
            
            // Start timer for animation
            startTimer()
        }
        .onDisappear {
            // Stop timer
            stopTimer()
        }
        .onChange(of: isActive) { oldValue, newValue in
            if newValue {
                startTimer()
            } else {
                stopTimer()
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
            
            if levelHistory.count <= i {
                continue
            }
            
            let level = levelHistory[i]
            
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
    
    /// Start the timer for waveform animation
    private func startTimer() {
        // Stop existing timer if any
        stopTimer()
        
        // Create new timer
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            updateLevelHistory()
        }
    }
    
    /// Stop the animation timer
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    /// Update the level history for animation
    private func updateLevelHistory() {
        // Add new level at the beginning
        var newHistory = levelHistory
        
        if isActive {
            // When active, use the current audio level with some randomization for visual interest
            let randomFactor = CGFloat.random(in: 0.8...1.2)
            let newLevel = min(1.0, audioLevel * randomFactor)
            newHistory.insert(newLevel, at: 0)
        } else {
            // When inactive, gradually reduce levels
            newHistory.insert(0, at: 0)
        }
        
        // Remove last element to maintain fixed size
        if !newHistory.isEmpty {
            newHistory.removeLast()
        }
        
        // Update state
        levelHistory = newHistory
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
