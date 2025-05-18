//
//  MissingAudioView.swift
//  voicejournal
//
//  Created on 4/27/25.
//

import SwiftUI

struct MissingAudioView: View {
    @Environment(\.themeManager) var themeManager
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Audio File Missing")
                    .font(.headline)
                    .foregroundColor(themeManager.theme.text)
                
                Text("The audio file for this entry could not be found")
                    .font(.caption)
                    .foregroundColor(themeManager.theme.textSecondary)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct MissingAudioIndicator: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundColor(.orange)
            
            Text("Missing Audio")
                .font(.caption)
                .foregroundColor(.orange)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    Capsule()
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        MissingAudioView()
            .padding()
        
        MissingAudioIndicator()
            .padding()
    }
}