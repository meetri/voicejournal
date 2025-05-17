//
//  ThemeManager.swift
//  voicejournal
//
//  Created on 5/17/25.
//

import SwiftUI
import Combine
import CoreData

@Observable
class ThemeManager: ObservableObject {
    private(set) var currentThemeID: String
    private(set) var theme: ThemeProtocol
    private var viewContext: NSManagedObjectContext?
    
    init() {
        let saved = UserDefaults.standard.string(forKey: "selectedThemeID") ?? ThemeID.light.rawValue
        self.currentThemeID = saved
        
        // Try to load built-in theme first
        if let builtInTheme = ThemeID(rawValue: saved) {
            self.theme = builtInTheme.theme
        } else {
            // If not built-in, it must be a custom theme UUID
            self.theme = ThemeID.light.theme  // Default fallback
            // Custom theme will be loaded when Core Data context is set
        }
    }
    
    /// Set Core Data context for loading custom themes
    func setContext(_ context: NSManagedObjectContext) {
        self.viewContext = context
        
        // Try to load custom theme if current ID is not a built-in theme
        if ThemeID(rawValue: currentThemeID) == nil {
            loadCustomTheme(withID: currentThemeID)
        }
    }
    
    /// Set a built-in theme
    func setTheme(_ id: ThemeID) {
        withAnimation(.easeInOut(duration: 0.3)) {
            self.currentThemeID = id.rawValue
            self.theme = id.theme
            UserDefaults.standard.setValue(id.rawValue, forKey: "selectedThemeID")
            clearCustomThemeSelection()
        }
    }
    
    /// Set a custom theme
    func setCustomTheme(_ customTheme: CustomTheme) {
        guard let themeData = customTheme.themeData,
              let id = customTheme.id else { return }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            self.currentThemeID = id.uuidString
            self.theme = CustomThemeData(data: themeData)
            UserDefaults.standard.setValue(id.uuidString, forKey: "selectedThemeID")
            
            // Update selection state in Core Data
            clearCustomThemeSelection()
            customTheme.isSelected = true
            saveContext()
        }
    }
    
    /// Load a custom theme by ID
    private func loadCustomTheme(withID id: String) {
        guard let viewContext = viewContext,
              let uuid = UUID(uuidString: id) else { return }
        
        let request = CustomTheme.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        request.fetchLimit = 1
        
        do {
            let themes = try viewContext.fetch(request)
            if let customTheme = themes.first,
               let themeData = customTheme.themeData {
                self.theme = CustomThemeData(data: themeData)
                customTheme.isSelected = true
                saveContext()
            }
        } catch {
            print("Error loading custom theme: \(error)")
        }
    }
    
    /// Clear selection state for all custom themes
    private func clearCustomThemeSelection() {
        guard let viewContext = viewContext else { return }
        
        let request = CustomTheme.fetchRequest()
        request.predicate = NSPredicate(format: "isSelected == YES")
        
        do {
            let selectedThemes = try viewContext.fetch(request)
            for theme in selectedThemes {
                theme.isSelected = false
            }
            saveContext()
        } catch {
            print("Error clearing theme selection: \(error)")
        }
    }
    
    /// Save Core Data context
    private func saveContext() {
        guard let viewContext = viewContext,
              viewContext.hasChanges else { return }
        
        do {
            try viewContext.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }
    
    /// Create a new custom theme and select it
    func createAndSelectTheme(_ themeData: ThemeData) {
        guard let viewContext = viewContext else { return }
        
        let customTheme = CustomTheme.create(from: themeData, in: viewContext)
        saveContext()
        setCustomTheme(customTheme)
    }
    
    /// Get all available themes (built-in + custom)
    func getAllThemes(from context: NSManagedObjectContext) -> (builtIn: [ThemeID], custom: [CustomTheme]) {
        let builtInThemes = ThemeID.allCases
        
        let request = CustomTheme.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CustomTheme.name, ascending: true)]
        
        do {
            let customThemes = try context.fetch(request)
            return (builtIn: builtInThemes, custom: customThemes)
        } catch {
            print("Error fetching custom themes: \(error)")
            return (builtIn: builtInThemes, custom: [])
        }
    }
}

// MARK: - Environment Key

private struct ThemeManagerKey: EnvironmentKey {
    static let defaultValue = ThemeManager()
}

extension EnvironmentValues {
    var themeManager: ThemeManager {
        get { self[ThemeManagerKey.self] }
        set { self[ThemeManagerKey.self] = newValue }
    }
}