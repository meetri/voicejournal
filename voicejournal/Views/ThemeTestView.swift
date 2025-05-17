//
//  ThemeTestView.swift
//  voicejournal
//
//  Created on 5/17/25.
//

import SwiftUI
import CoreData

/// Test view to verify theme properties are being saved correctly
struct ThemeTestView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CustomTheme.name, ascending: true)],
        animation: .default)
    private var customThemes: FetchedResults<CustomTheme>
    
    var body: some View {
        NavigationView {
            List {
                ForEach(customThemes) { theme in
                    if let themeData = theme.themeData {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Theme: \(themeData.name)")
                                .font(.headline)
                            
                            Text("Cell Border: \(themeData.cellBorderHex)")
                                .font(.caption)
                            
                            HStack {
                                Text("Cell Border Color:")
                                Rectangle()
                                    .fill(Color(hex: themeData.cellBorderHex))
                                    .frame(width: 50, height: 20)
                                    .border(Color.black, width: 1)
                            }
                            
                            // Display all other properties for verification
                            ScrollView(.horizontal) {
                                HStack(spacing: 10) {
                                    ColorSwatch(name: "Primary", hex: themeData.primaryHex)
                                    ColorSwatch(name: "Secondary", hex: themeData.secondaryHex)
                                    ColorSwatch(name: "Background", hex: themeData.backgroundHex)
                                    ColorSwatch(name: "Surface", hex: themeData.surfaceHex)
                                    ColorSwatch(name: "Cell Background", hex: themeData.cellBackgroundHex)
                                    ColorSwatch(name: "Cell Border", hex: themeData.cellBorderHex)
                                    ColorSwatch(name: "Shadow", hex: themeData.shadowColorHex)
                                }
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
            }
            .navigationTitle("Theme Properties Test")
        }
    }
}

struct ColorSwatch: View {
    let name: String
    let hex: String
    
    var body: some View {
        VStack {
            Rectangle()
                .fill(Color(hex: hex))
                .frame(width: 60, height: 40)
                .border(Color.black, width: 1)
            
            Text(name)
                .font(.caption2)
                .lineLimit(2)
                .frame(width: 60)
            
            Text(hex)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    ThemeTestView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}