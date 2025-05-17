//
//  AudioVisualizationView.swift
//  voicejournal
//
//  Created on 5/16/2025.
//

import SwiftUI

/// A consolidated view that provides audio visualization for both recording and playback
struct AudioVisualizationView: View {
    // MARK: - Properties
    
    /// The audio level to visualize (0.0 to 1.0)
    var audioLevel: CGFloat
    
    /// The primary color of the visualization
    var primaryColor: Color
    
    /// The secondary color for gradient effects
    var secondaryColor: Color
    
    /// Whether the visualization is active (recording/playing)
    var isActive: Bool
    
    /// External frequency data for spectrum visualization
    var frequencyData: [Float]
    
    /// The height of the visualization
    var height: CGFloat = 120
    
    /// Visual amplification factor to scale the bars to fill more of the view height
    var visualAmplification: CGFloat = 1.0
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            primaryColor.opacity(0.2),
                            lineWidth: 1
                        )
                )
            
            // Use spectrum analyzer visualization
            Group {
                if !frequencyData.isEmpty {
                    Canvas { context, size in
                        let barCount = frequencyData.count
                        guard barCount > 0 else { return }
                        
                        let barSpacing: CGFloat = 2
                        let totalSpacing = barSpacing * CGFloat(barCount - 1)
                        let availableWidth = size.width - totalSpacing
                        
                        // Ensure we have valid dimensions
                        guard availableWidth > 0, size.height > 0 else { return }
                        
                        let barWidth = max(1, availableWidth / CGFloat(barCount))
                        
                        for i in 0..<barCount {
                            let level = frequencyData[i]
                            
                            // Check for NaN or invalid values
                            let safeLevel = level.isNaN || level.isInfinite ? 0 : max(0, min(1, level))
                            
                            // Apply visual amplification
                            let barHeight = min(size.height * 0.95, max(2, CGFloat(safeLevel) * size.height * visualAmplification))
                            let x = CGFloat(i) * (barWidth + barSpacing)
                            let y = size.height - barHeight
                            
                            // Ensure valid rect
                            let safeX = max(0, min(size.width - barWidth, x))
                            let safeY = max(0, min(size.height - barHeight, y))
                            
                            let barRect = CGRect(x: safeX, y: safeY, width: barWidth, height: barHeight)
                            let barPath = Path(roundedRect: barRect, cornerRadius: 2)
                            
                            // Color mapping based on frequency
                            let opacity = Double(safeLevel * 0.7 + 0.3)
                            let color = interpolatedColor(for: i, count: barCount, level: safeLevel).opacity(opacity)
                            context.fill(barPath, with: .color(color))
                        }
                    }
                } else {
                    // Fallback visualization showing minimal bars when no data
                    Canvas { context, size in
                        let barCount = 30
                        let barSpacing: CGFloat = 2
                        let totalSpacing = barSpacing * CGFloat(barCount - 1)
                        let availableWidth = size.width - totalSpacing
                        
                        guard availableWidth > 0, size.height > 0 else { return }
                        
                        let barWidth = max(1, availableWidth / CGFloat(barCount))
                        
                        for i in 0..<barCount {
                            let minHeight: CGFloat = 2
                            let x = CGFloat(i) * (barWidth + barSpacing)
                            let y = size.height - minHeight
                            
                            let barRect = CGRect(x: x, y: y, width: barWidth, height: minHeight)
                            let barPath = Path(roundedRect: barRect, cornerRadius: 1)
                            
                            let color = primaryColor.opacity(0.2)
                            context.fill(barPath, with: .color(color))
                        }
                    }
                }
            }
            .padding(8)
            
            // Activity indicator
            if isActive && audioLevel > 0.1 {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        primaryColor.opacity(0.3),
                        lineWidth: 1
                    )
            }
        }
        .frame(height: height)
    }
    
    // MARK: - Helper Methods
    
    /// Interpolates colors based on frequency position
    private func interpolatedColor(for index: Int, count: Int, level: Float) -> Color {
        let position = CGFloat(index) / CGFloat(max(1, count - 1))
        
        // Color transition from primary to secondary based on frequency
        let interpolatedColor = Color(
            red: primaryColor.components.red * (1 - position) + secondaryColor.components.red * position,
            green: primaryColor.components.green * (1 - position) + secondaryColor.components.green * position,
            blue: primaryColor.components.blue * (1 - position) + secondaryColor.components.blue * position
        )
        
        return interpolatedColor
    }
}

// MARK: - Color Extension

extension Color {
    /// Extracts RGB components from Color
    var components: (red: Double, green: Double, blue: Double) {
        // Use UIColor to extract components
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return (red: Double(red), green: Double(green), blue: Double(blue))
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Active visualization with data
        AudioVisualizationView(
            audioLevel: 0.8,
            primaryColor: .blue,
            secondaryColor: .purple,
            isActive: true,
            frequencyData: [0.3, 0.5, 0.7, 0.6, 0.4, 0.3, 0.5, 0.6, 0.7, 0.8, 0.6, 0.4, 0.3, 0.2, 0.3, 0.4, 0.5, 0.6, 0.5, 0.4, 0.3, 0.2, 0.3, 0.4, 0.5, 0.4, 0.3, 0.2, 0.1, 0.2]
        )
        .padding()
        
        // Inactive visualization
        AudioVisualizationView(
            audioLevel: 0.0,
            primaryColor: .gray,
            secondaryColor: .gray.opacity(0.5),
            isActive: false,
            frequencyData: []
        )
        .padding()
    }
    .padding()
    .background(Color(.systemBackground))
}
