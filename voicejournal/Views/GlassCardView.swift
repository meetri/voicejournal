//
//  GlassCardView.swift
//  voicejournal
//
//  Created on 5/17/25.
//

import SwiftUI

struct GlassCardView<Content: View>: View {
    @Environment(\.themeManager) var themeManager
    
    let content: Content
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    
    init(
        cornerRadius: CGFloat = 20,
        shadowRadius: CGFloat = 10,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
        self.content = content()
    }
    
    var body: some View {
        content
            .background(
                ZStack {
                    // Glass effect layer
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                    
                    // Border layer for glass effect
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    themeManager.theme.primary.opacity(0.3),
                                    themeManager.theme.accent.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .shadow(
                color: themeManager.theme.primary.opacity(0.1),
                radius: shadowRadius,
                x: 0,
                y: shadowRadius/2
            )
    }
}

// MARK: - Enhanced Glass View

struct EnhancedGlassView: View {
    @Environment(\.themeManager) var themeManager
    
    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    themeManager.theme.surface.opacity(0.8),
                    themeManager.theme.background.opacity(0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Frosted glass effect
            Rectangle()
                .fill(.ultraThinMaterial)
        }
    }
}

// MARK: - Preview

#Preview {
    GlassCardView {
        VStack(spacing: 16) {
            Text("Glass Card")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("This is a modern glass-morphic card")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    .padding()
    .previewLayout(.sizeThatFits)
}