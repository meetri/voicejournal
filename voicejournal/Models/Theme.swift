//
//  Theme.swift
//  voicejournal
//
//  Created on 5/17/25.
//

import SwiftUI

// MARK: - Theme Protocol

protocol ThemeProtocol {
    var primary: Color { get }
    var secondary: Color { get }
    var background: Color { get }
    var surface: Color { get }
    var accent: Color { get }
    var error: Color { get }
    var text: Color { get }
    var textSecondary: Color { get }
    var surfaceLight: Color { get }
    var cellBackground: Color { get }
    var cellBorder: Color { get }
    var shadowColor: Color { get }
    var tabBarBackground: Color { get }
}

// MARK: - Light Theme

struct LightTheme: ThemeProtocol {
    let primary = Color.blue
    let secondary = Color.gray
    let background = Color(.systemBackground)
    let surface = Color(.secondarySystemBackground)
    let accent = Color.purple
    let error = Color.red
    let text = Color(.label)
    let textSecondary = Color(.secondaryLabel)
    let surfaceLight = Color(.tertiarySystemBackground)
    let cellBackground = Color(.systemBackground)
    let cellBorder = Color.gray.opacity(0.1)
    let shadowColor = Color.black.opacity(0.05)
    let tabBarBackground = Color(.systemBackground)
}

// MARK: - Dark Theme

struct DarkTheme: ThemeProtocol {
    let primary = Color.indigo
    let secondary = Color.gray
    let background = Color.black
    let surface = Color(.black)
    let accent = Color.purple
    let error = Color.red
    let text = Color.white
    let textSecondary = Color(.lightGray)
    let surfaceLight = Color(.systemGray5)
    let cellBackground = Color(white: 0.06)
    let cellBorder = Color.white.opacity(0.04)
    let shadowColor = Color.clear  // No shadows in dark mode for cleaner look
    let tabBarBackground = Color(white: 0.08)
}

// MARK: - Futuristic Theme

struct FuturisticTheme: ThemeProtocol {
    let primary = Color(red: 0.0, green: 0.8, blue: 0.4)  // Bright green
    let secondary = Color(red: 0.0, green: 0.6, blue: 0.8)  // Cyan
    let background = Color(red: 0.05, green: 0.05, blue: 0.1)  // Deep blue-black
    let surface = Color(red: 0.05, green: 0.05, blue: 0.1)  // Deep blue-black
    let accent = Color(red: 1.0, green: 0.4, blue: 0.0)  // Orange
    let error = Color(red: 1.0, green: 0.2, blue: 0.2)
    let text = Color(red: 0.9, green: 0.95, blue: 1.0)  // Light blue-white
    let textSecondary = Color(red: 0.6, green: 0.7, blue: 0.8)
    let surfaceLight = Color(red: 0.15, green: 0.15, blue: 0.25)
    let cellBackground = Color(red: 0.08, green: 0.08, blue: 0.15)
    let cellBorder = Color(red: 0.0, green: 0.8, blue: 0.4).opacity(0.15)
    let shadowColor = Color(red: 0.0, green: 0.8, blue: 0.4).opacity(0.1)
    let tabBarBackground = Color(red: 0.05, green: 0.05, blue: 0.1)  // Deep blue-black
}

// MARK: - PurpleHaze Theme

struct PurpleHazeTheme: ThemeProtocol {
    let primary = Color(red: 0.0, green: 0.8, blue: 0.4)  // Bright green
    let secondary = Color(red: 0.0, green: 0.6, blue: 0.8)  // Cyan
    let background = Color(red: 0.05, green: 0.05, blue: 0.1)  // Deep blue-black
    let surface = Color(red: 0.15, green: 0.05, blue: 0.1)  // Deep Red-black
    let accent = Color(red: 1.0, green: 0.4, blue: 0.0)  // Orange
    let error = Color(red: 1.0, green: 0.2, blue: 0.2)
    let text = Color(red: 0.9, green: 0.95, blue: 1.0)  // Light blue-white
    let textSecondary = Color(red: 0.6, green: 0.7, blue: 0.8)
    let surfaceLight = Color(red: 0.15, green: 0.15, blue: 0.25)
    let cellBackground = Color(red: 0.08, green: 0.08, blue: 0.15)
    let cellBorder = Color(red: 0.0, green: 0.8, blue: 0.4).opacity(0.15)
    let shadowColor = Color(red: 0.0, green: 0.8, blue: 0.4).opacity(0.1)
    let tabBarBackground = Color(red: 0.05, green: 0.05, blue: 0.1)  // Deep blue-black
}


// MARK: - Theme ID Enum

enum ThemeID: String, CaseIterable {
    case light
    case dark
    case futuristic
    case purplehaze
    
    var theme: ThemeProtocol {
        switch self {
        case .light:
            return LightTheme()
        case .dark:
            return DarkTheme()
        case .futuristic:
            return FuturisticTheme()
        case .purplehaze:
            return PurpleHazeTheme()
        }
    }
    
    var displayName: String {
        switch self {
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        case .futuristic:
            return "Futuristic"
        case .purplehaze:
            return "Purple Haze"
        }
    }
}
