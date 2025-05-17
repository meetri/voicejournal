//
//  ThemeEditorView.swift
//  voicejournal
//
//  Created on 5/17/25.
//

import SwiftUI
import CoreData

/// View for creating and editing themes
struct ThemeEditorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var themeData: ThemeData
    @State private var showingSaveError = false
    @State private var saveErrorMessage = ""
    @State private var showingPreview = false
    
    let isEditMode: Bool
    let existingTheme: CustomTheme?
    
    // MARK: - Initialization
    
    init(editingTheme: CustomTheme? = nil) {
        self.existingTheme = editingTheme
        self.isEditMode = editingTheme != nil
        
        if let existingTheme = editingTheme,
           let data = existingTheme.themeData {
            self._themeData = State(initialValue: data)
        } else {
            // Create default theme data
            let lightTheme = LightTheme()
            self._themeData = State(initialValue: ThemeData(
                from: lightTheme,
                name: "New Theme",
                author: nil,
                isBuiltIn: false
            ))
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            Form {
                // Theme metadata section
                Section(header: Text("Theme Information")) {
                    HStack {
                        Text("Name")
                        Spacer()
                        TextField("Theme Name", text: $themeData.name)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Author")
                        Spacer()
                        TextField("Author Name", text: Binding(
                            get: { themeData.author ?? "" },
                            set: { themeData.author = $0.isEmpty ? nil : $0 }
                        ))
                        .multilineTextAlignment(.trailing)
                    }
                }
                
                // Color properties sections
                Section(header: Text("Primary Colors")) {
                    ThemeColorPicker(
                        color: $themeData.primaryHex,
                        property: .primary
                    )
                    
                    ThemeColorPicker(
                        color: $themeData.secondaryHex,
                        property: .secondary
                    )
                    
                    ThemeColorPicker(
                        color: $themeData.accentHex,
                        property: .accent
                    )
                }
                
                Section(header: Text("Background Colors")) {
                    ThemeColorPicker(
                        color: $themeData.backgroundHex,
                        property: .background
                    )
                    
                    ThemeColorPicker(
                        color: $themeData.surfaceHex,
                        property: .surface
                    )
                    
                    ThemeColorPicker(
                        color: $themeData.surfaceLightHex,
                        property: .surfaceLight
                    )
                }
                
                Section(header: Text("Text Colors")) {
                    ThemeColorPicker(
                        color: $themeData.textHex,
                        property: .text
                    )
                    
                    ThemeColorPicker(
                        color: $themeData.textSecondaryHex,
                        property: .textSecondary
                    )
                }
                
                Section(header: Text("UI Elements")) {
                    ThemeColorPicker(
                        color: $themeData.cellBackgroundHex,
                        property: .cellBackground
                    )
                    
                    ThemeColorPicker(
                        color: $themeData.cellBorderHex,
                        property: .cellBorder
                    )
                    
                    ThemeColorPicker(
                        color: $themeData.shadowColorHex,
                        property: .shadowColor
                    )
                    
                    ThemeColorPicker(
                        color: $themeData.tabBarBackgroundHex,
                        property: .tabBarBackground
                    )
                }
                
                Section(header: Text("Special Colors")) {
                    ThemeColorPicker(
                        color: $themeData.errorHex,
                        property: .error
                    )
                }
                
                // Preview button
                Section {
                    Button(action: { showingPreview = true }) {
                        HStack {
                            Image(systemName: "eye")
                            Text("Preview Theme")
                        }
                    }
                }
            }
            .navigationTitle(isEditMode ? "Edit Theme" : "Create Theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTheme()
                    }
                    .disabled(themeData.name.isEmpty)
                }
            }
            .sheet(isPresented: $showingPreview) {
                ThemePreviewSheet(themeData: themeData)
            }
            .alert("Save Error", isPresented: $showingSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage)
            }
        }
    }
    
    // MARK: - Methods
    
    private func saveTheme() {
        themeData.lastModified = Date()
        
        if isEditMode, let existingTheme = existingTheme {
            // Update existing theme
            existingTheme.updateFromThemeData(themeData)
        } else {
            // Create new theme
            _ = CustomTheme.create(from: themeData, in: viewContext)
        }
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            saveErrorMessage = "Failed to save theme: \(error.localizedDescription)"
            showingSaveError = true
        }
    }
}

/// Preview sheet showing how the theme looks
struct ThemePreviewSheet: View {
    let themeData: ThemeData
    @Environment(\.dismiss) private var dismiss
    
    var previewTheme: ThemeProtocol {
        return voicejournal.CustomTheme(data: themeData)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Text(themeData.name)
                            .font(.largeTitle)
                            .foregroundColor(previewTheme.text)
                        
                        if let author = themeData.author, !author.isEmpty {
                            Text("by \(author)")
                                .font(.subheadline)
                                .foregroundColor(previewTheme.textSecondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(previewTheme.surface)
                    
                    // Sample components
                    VStack(spacing: 16) {
                        // Buttons
                        HStack(spacing: 12) {
                            Button("Primary") {}
                                .foregroundColor(.white)
                                .padding()
                                .background(previewTheme.primary)
                                .cornerRadius(8)
                            
                            Button("Secondary") {}
                                .foregroundColor(.white)
                                .padding()
                                .background(previewTheme.secondary)
                                .cornerRadius(8)
                            
                            Button("Accent") {}
                                .foregroundColor(.white)
                                .padding()
                                .background(previewTheme.accent)
                                .cornerRadius(8)
                        }
                        
                        // Text samples
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Primary Text")
                                .foregroundColor(previewTheme.text)
                                .font(.headline)
                            
                            Text("Secondary text for less important content")
                                .foregroundColor(previewTheme.textSecondary)
                                .font(.subheadline)
                            
                            Text("Error message example")
                                .foregroundColor(previewTheme.error)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(previewTheme.surface)
                        .cornerRadius(8)
                        
                        // List sample
                        VStack(spacing: 1) {
                            ForEach(0..<3) { index in
                                HStack {
                                    Text("List Item \(index + 1)")
                                        .foregroundColor(previewTheme.text)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(previewTheme.textSecondary)
                                }
                                .padding()
                                .background(previewTheme.cellBackground)
                                .overlay(
                                    Rectangle()
                                        .stroke(previewTheme.cellBorder, lineWidth: 1)
                                        .shadow(color: previewTheme.shadowColor, radius: 3)
                                )
                            }
                        }
                        
                        // Tab bar preview
                        HStack {
                            ForEach(["house", "magnifyingglass", "mic", "gear"], id: \.self) { icon in
                                VStack {
                                    Image(systemName: icon)
                                    Text(icon.capitalized)
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .foregroundColor(icon == "mic" ? previewTheme.primary : previewTheme.textSecondary)
                            }
                        }
                        .padding()
                        .background(previewTheme.tabBarBackground)
                        .cornerRadius(8)
                    }
                    .padding()
                }
            }
            .background(previewTheme.background.ignoresSafeArea())
            .navigationTitle("Theme Preview")
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

#Preview("Create New Theme") {
    ThemeEditorView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
}

#Preview("Edit Existing Theme") {
    let context = PersistenceController.preview.container.viewContext
    let sampleTheme = CustomTheme(context: context)
    sampleTheme.updateFromThemeData(ThemeData(
        from: LightTheme(),
        name: "Sample Theme",
        author: "John Doe",
        isBuiltIn: false
    ))
    
    return ThemeEditorView(editingTheme: sampleTheme)
        .environment(\.managedObjectContext, context)
        .environmentObject(ThemeManager())
}