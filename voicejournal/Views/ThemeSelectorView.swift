//
//  ThemeSelectorView.swift
//  voicejournal
//
//  Created on 5/17/25.
//

import SwiftUI
import CoreData

/// View for selecting and managing themes
struct ThemeSelectorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var themeManager: ThemeManager
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CustomTheme.name, ascending: true)],
        animation: .default)
    private var customThemes: FetchedResults<CustomTheme>
    
    @State private var showingThemeEditor = false
    @State private var selectedThemeForEditing: CustomTheme?
    @State private var showingDeleteConfirmation = false
    @State private var themeToDelete: CustomTheme?
    
    private let builtInThemes = ThemeID.allCases
    
    var body: some View {
        NavigationView {
            List {
                // Built-in themes section
                Section(header: Text("Built-in Themes")) {
                    ForEach(builtInThemes, id: \.self) { themeID in
                        ThemeRow(
                            theme: themeID.theme,
                            name: themeID.displayName,
                            isSelected: themeManager.currentThemeID == themeID.rawValue,
                            isBuiltIn: true,
                            onTap: {
                                themeManager.setTheme(themeID)
                            }
                        )
                    }
                }
                
                // Custom themes section
                if !customThemes.isEmpty {
                    Section(header: Text("Custom Themes")) {
                        ForEach(customThemes, id: \.id) { customTheme in
                            if let themeData = customTheme.themeData {
                                let theme = voicejournal.CustomTheme(data: themeData)
                                
                                ThemeRow(
                                    theme: theme,
                                    name: themeData.name,
                                    author: themeData.author,
                                    isSelected: themeManager.currentThemeID == customTheme.id?.uuidString,
                                    isBuiltIn: false,
                                    onTap: {
                                        themeManager.setCustomTheme(customTheme)
                                    },
                                    onEdit: {
                                        selectedThemeForEditing = customTheme
                                    },
                                    onDelete: {
                                        themeToDelete = customTheme
                                        showingDeleteConfirmation = true
                                    }
                                )
                            }
                        }
                    }
                }
            }
            .navigationTitle("Themes")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingThemeEditor = true }) {
                        Label("Create Theme", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingThemeEditor) {
                ThemeEditorView()
                    .environment(\.managedObjectContext, viewContext)
                    .environmentObject(themeManager)
            }
            .sheet(item: $selectedThemeForEditing) { theme in
                ThemeEditorView(editingTheme: theme)
                    .environment(\.managedObjectContext, viewContext)
                    .environmentObject(themeManager)
            }
            .alert("Delete Theme", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    deleteTheme()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete \"\(themeToDelete?.name ?? "this theme")\"? This action cannot be undone.")
            }
        }
    }
    
    private func deleteTheme() {
        guard let theme = themeToDelete else { return }
        
        // If this is the currently selected theme, switch to default
        if theme.isSelected || themeManager.currentThemeID == theme.id?.uuidString {
            themeManager.setTheme(.light)
        }
        
        viewContext.delete(theme)
        
        do {
            try viewContext.save()
        } catch {
            print("Error deleting theme: \(error)")
        }
        
        themeToDelete = nil
    }
}

/// Individual theme row in the list
struct ThemeRow: View {
    let theme: ThemeProtocol
    let name: String
    let author: String?
    let isSelected: Bool
    let isBuiltIn: Bool
    let onTap: () -> Void
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    
    init(theme: ThemeProtocol,
         name: String,
         author: String? = nil,
         isSelected: Bool,
         isBuiltIn: Bool,
         onTap: @escaping () -> Void,
         onEdit: (() -> Void)? = nil,
         onDelete: (() -> Void)? = nil) {
        self.theme = theme
        self.name = name
        self.author = author
        self.isSelected = isSelected
        self.isBuiltIn = isBuiltIn
        self.onTap = onTap
        self.onEdit = onEdit
        self.onDelete = onDelete
    }
    
    var body: some View {
        HStack {
            // Theme preview colors
            HStack(spacing: 4) {
                Circle()
                    .fill(theme.primary)
                    .frame(width: 24, height: 24)
                
                Circle()
                    .fill(theme.secondary)
                    .frame(width: 24, height: 24)
                
                Circle()
                    .fill(theme.accent)
                    .frame(width: 24, height: 24)
                
                Circle()
                    .fill(theme.background)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
            
            // Theme info
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.headline)
                
                if let author = author, !author.isEmpty {
                    Text("by \(author)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Selected checkmark
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(theme.primary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            if !isBuiltIn {
                Button(action: { onEdit?() }) {
                    Label("Edit", systemImage: "pencil")
                }
                
                Button(action: { onDelete?() }, role: .destructive) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ThemeSelectorView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
}