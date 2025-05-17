//
//  CellBorderTestView.swift
//  voicejournal
//
//  Created on 5/17/25.
//

import SwiftUI

/// Test view to verify cell border visibility
struct CellBorderTestView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Current Theme: \(String(describing: themeManager.currentThemeID))")
                    .font(.headline)
                
                // Regular cell with border
                VStack(alignment: .leading, spacing: 5) {
                    Text("Cell with Border")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("Sample Cell Content")
                            .foregroundColor(themeManager.theme.text)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(themeManager.theme.textSecondary)
                    }
                    .padding()
                    .background(themeManager.theme.cellBackground)
                    .overlay(
                        Rectangle()
                            .stroke(themeManager.theme.cellBorder, lineWidth: 1)
                    )
                    .cornerRadius(8)
                }
                
                // Cell with thicker border for visibility
                VStack(alignment: .leading, spacing: 5) {
                    Text("Cell with Thick Border (3pt)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("Sample Cell Content")
                            .foregroundColor(themeManager.theme.text)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(themeManager.theme.textSecondary)
                    }
                    .padding()
                    .background(themeManager.theme.cellBackground)
                    .overlay(
                        Rectangle()
                            .stroke(themeManager.theme.cellBorder, lineWidth: 3)
                    )
                    .cornerRadius(8)
                }
                
                // Show actual border color
                VStack(alignment: .leading, spacing: 5) {
                    Text("Cell Border Color Sample")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Rectangle()
                        .fill(themeManager.theme.cellBorder)
                        .frame(height: 50)
                        .overlay(
                            Text("Cell Border Color")
                                .foregroundColor(.white)
                        )
                        .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
            .background(themeManager.theme.background)
            .navigationTitle("Cell Border Test")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    CellBorderTestView()
        .environmentObject(ThemeManager())
}