//
//  ThemeManager.swift
//  voicejournal
//
//  Created on 5/17/25.
//

import SwiftUI
import Combine

@Observable
class ThemeManager {
    private(set) var themeID: ThemeID
    private(set) var theme: ThemeProtocol
    
    init() {
        let saved = UserDefaults.standard.string(forKey: "selectedThemeID")
        let id = ThemeID(rawValue: saved ?? "") ?? .light
        self.themeID = id
        self.theme = id.theme
        // Theme update
    }
    
    func setTheme(_ id: ThemeID) {
        withAnimation(.easeInOut(duration: 0.3)) {
            self.themeID = id
            self.theme = id.theme
            UserDefaults.standard.setValue(id.rawValue, forKey: "selectedThemeID")
            // Theme update
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