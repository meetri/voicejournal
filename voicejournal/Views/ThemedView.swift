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
            .preferredColorScheme(colorScheme(for: themeManager.themeID))
    }
    
    private func colorScheme(for themeID: ThemeID) -> ColorScheme? {
        switch themeID {
        case .light:
            return .light
        case .dark, .futuristic:
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
    }
}

// MARK: - Navigation Theme Modifier

struct ThemedNavigationModifier: ViewModifier {
    @Environment(\.themeManager) var themeManager
    
    func body(content: Content) -> some View {
        content
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(themeManager.theme.surface, for: .navigationBar)
            .toolbarColorScheme(colorScheme(for: themeManager.themeID), for: .navigationBar)
    }
    
    private func colorScheme(for themeID: ThemeID) -> ColorScheme? {
        switch themeID {
        case .light:
            return .light
        case .dark, .futuristic:
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