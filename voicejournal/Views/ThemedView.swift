//
//  ThemedView.swift
//  voicejournal
//
//  Created on 5/17/25.
//

import SwiftUI

// MARK: - Theme View Modifier

struct ThemedViewModifier: ViewModifier {
    @Environment(\.themeManager) var themeManager
    
    func body(content: Content) -> some View {
        content
            .background(themeManager.theme.background)
            .foregroundColor(themeManager.theme.text)
            .preferredColorScheme(colorScheme(for: themeManager.currentThemeID))
    }
    
    private func colorScheme(for themeID: String) -> ColorScheme? {
        switch themeID {
        case "light":
            return .light
        case "dark", "futuristic", "purplehaze":
            return .dark
        default:
            // Custom themes default to dark mode
            return .dark
        }
    }
}

// MARK: - List Theme Modifier

struct ThemedListModifier: ViewModifier {
    @Environment(\.themeManager) var themeManager
    
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(themeManager.theme.background)
            .listStyle(PlainListStyle())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

// MARK: - Navigation Theme Modifier

struct ThemedNavigationModifier: ViewModifier {
    @Environment(\.themeManager) var themeManager
    
    func body(content: Content) -> some View {
        content
            .toolbarBackground(.automatic, for: .navigationBar)
            .toolbarColorScheme(colorScheme(for: themeManager.currentThemeID), for: .navigationBar)
    }
    
    private func colorScheme(for themeID: String) -> ColorScheme? {
        switch themeID {
        case "light":
            return .light
        case "dark", "futuristic", "purplehaze":
            return .dark
        default:
            // Custom themes default to dark mode
            return .dark
        }
    }
}

// MARK: - View Extensions

extension View {
    func themed() -> some View {
        self.modifier(ThemedViewModifier())
    }
    
    func themedList() -> some View {
        self.modifier(ThemedListModifier())
    }
    
    func themedNavigation() -> some View {
        self.modifier(ThemedNavigationModifier())
    }
}
