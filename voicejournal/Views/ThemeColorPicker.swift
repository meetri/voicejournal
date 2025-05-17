//
//  ThemeColorPicker.swift
//  voicejournal
//
//  Created on 5/17/25.
//

import SwiftUI

/// A color picker component for theme colors with hex input and preview
struct ThemeColorPicker: View {
    @Binding var color: String
    let property: ThemeProperty
    @State private var tempHex: String = ""
    @State private var showingColorPicker = false
    @State private var selectedColor: Color = .blue
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Property label and description
            VStack(alignment: .leading, spacing: 4) {
                Text(property.displayName)
                    .font(.headline)
                
                Text(property.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Color preview and controls
            HStack(spacing: 12) {
                // Color preview button
                Button(action: {
                    showingColorPicker.toggle()
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: color) ?? .gray)
                            .frame(width: 60, height: 40)
                        
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            .frame(width: 60, height: 40)
                    }
                }
                
                // Hex value input
                HStack {
                    Text("#")
                        .foregroundColor(.secondary)
                    
                    TextField("FFFFFF", text: $tempHex, onCommit: {
                        if isValidHex(tempHex) {
                            color = "#\(tempHex)"
                            selectedColor = Color(hex: color) ?? .gray
                        }
                    })
                    .textFieldStyle(PlainTextFieldStyle())
                    .onChange(of: tempHex) { newValue in
                        // Limit to 8 characters max (RRGGBBAA)
                        if newValue.count > 8 {
                            tempHex = String(newValue.prefix(8))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                )
                
                // Color picker button for iOS 14+
                if #available(iOS 14.0, *) {
                    ColorPicker("", selection: $selectedColor)
                        .labelsHidden()
                        .frame(width: 40, height: 40)
                        .onChange(of: selectedColor) { newColor in
                            color = newColor.hexString
                            updateTempHex()
                        }
                }
            }
        }
        .onAppear {
            updateTempHex()
            selectedColor = Color(hex: color) ?? .gray
        }
        .sheet(isPresented: $showingColorPicker) {
            ColorPickerSheet(color: $color, selectedColor: $selectedColor)
        }
    }
    
    private func updateTempHex() {
        // Remove the # from the hex string for display
        tempHex = color.replacingOccurrences(of: "#", with: "")
    }
    
    private func isValidHex(_ hex: String) -> Bool {
        let hexRegex = "^[0-9A-Fa-f]{6}$|^[0-9A-Fa-f]{8}$"
        let hexPredicate = NSPredicate(format: "SELF MATCHES %@", hexRegex)
        return hexPredicate.evaluate(with: hex)
    }
}

/// Custom color picker sheet for older iOS versions or custom UI
struct ColorPickerSheet: View {
    @Binding var color: String
    @Binding var selectedColor: Color
    @Environment(\.dismiss) private var dismiss
    
    // Preset colors
    let presetColors: [Color] = [
        .black, .white, .gray,
        .red, .orange, .yellow,
        .green, .blue, .indigo,
        .purple, .pink, .brown
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Color preview
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedColor)
                    .frame(height: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                    )
                
                // Preset colors
                VStack(alignment: .leading, spacing: 12) {
                    Text("Preset Colors")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 16) {
                        ForEach(presetColors, id: \.self) { presetColor in
                            Button(action: {
                                selectedColor = presetColor
                                color = presetColor.hexString
                            }) {
                                Circle()
                                    .fill(presetColor)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Choose Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        ThemeColorPicker(
            color: .constant("#FF0000"),
            property: .primary
        )
        
        ThemeColorPicker(
            color: .constant("#00FF00"),
            property: .background
        )
        
        ThemeColorPicker(
            color: .constant("#0000FF"),
            property: .text
        )
    }
    .padding()
}