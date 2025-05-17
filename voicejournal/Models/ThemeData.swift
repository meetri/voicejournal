//
//  ThemeData.swift
//  voicejournal
//
//  Created on 5/17/25.
//

import SwiftUI
import Foundation

// MARK: - Theme Data Model

struct ThemeData: Codable, Identifiable {
    let id: UUID
    var name: String
    var author: String?
    var createdDate: Date
    var lastModified: Date
    var isBuiltIn: Bool
    var isEditable: Bool
    
    // Color properties as hex strings for Codable
    var primaryHex: String
    var secondaryHex: String
    var backgroundHex: String
    var surfaceHex: String
    var accentHex: String
    var errorHex: String
    var textHex: String
    var textSecondaryHex: String
    var surfaceLightHex: String
    var cellBackgroundHex: String
    var cellBorderHex: String
    var shadowColorHex: String
    var tabBarBackgroundHex: String
    
    // MARK: - Initialization
    
    init(id: UUID = UUID(),
         name: String,
         author: String? = nil,
         createdDate: Date = Date(),
         lastModified: Date = Date(),
         isBuiltIn: Bool = false,
         isEditable: Bool = true,
         primaryHex: String,
         secondaryHex: String,
         backgroundHex: String,
         surfaceHex: String,
         accentHex: String,
         errorHex: String,
         textHex: String,
         textSecondaryHex: String,
         surfaceLightHex: String,
         cellBackgroundHex: String,
         cellBorderHex: String,
         shadowColorHex: String,
         tabBarBackgroundHex: String) {
        self.id = id
        self.name = name
        self.author = author
        self.createdDate = createdDate
        self.lastModified = lastModified
        self.isBuiltIn = isBuiltIn
        self.isEditable = isEditable
        self.primaryHex = primaryHex
        self.secondaryHex = secondaryHex
        self.backgroundHex = backgroundHex
        self.surfaceHex = surfaceHex
        self.accentHex = accentHex
        self.errorHex = errorHex
        self.textHex = textHex
        self.textSecondaryHex = textSecondaryHex
        self.surfaceLightHex = surfaceLightHex
        self.cellBackgroundHex = cellBackgroundHex
        self.cellBorderHex = cellBorderHex
        self.shadowColorHex = shadowColorHex
        self.tabBarBackgroundHex = tabBarBackgroundHex
    }
    
    // MARK: - Convenience init from ThemeProtocol
    
    init(from theme: ThemeProtocol, name: String, author: String? = nil, isBuiltIn: Bool = false) {
        self.id = UUID()
        self.name = name
        self.author = author
        self.createdDate = Date()
        self.lastModified = Date()
        self.isBuiltIn = isBuiltIn
        self.isEditable = !isBuiltIn
        
        // Convert colors to hex strings
        self.primaryHex = theme.primary.hexString
        self.secondaryHex = theme.secondary.hexString
        self.backgroundHex = theme.background.hexString
        self.surfaceHex = theme.surface.hexString
        self.accentHex = theme.accent.hexString
        self.errorHex = theme.error.hexString
        self.textHex = theme.text.hexString
        self.textSecondaryHex = theme.textSecondary.hexString
        self.surfaceLightHex = theme.surfaceLight.hexString
        self.cellBackgroundHex = theme.cellBackground.hexString
        self.cellBorderHex = theme.cellBorder.hexString
        self.shadowColorHex = theme.shadowColor.hexString
        self.tabBarBackgroundHex = theme.tabBarBackground.hexString
    }
}

// MARK: - ThemeData to Theme Conversion

struct CustomThemeData: ThemeProtocol {
    let data: ThemeData
    
    var primary: Color { Color(hex: data.primaryHex) }
    var secondary: Color { Color(hex: data.secondaryHex) }
    var background: Color { Color(hex: data.backgroundHex) }
    var surface: Color { Color(hex: data.surfaceHex) }
    var accent: Color { Color(hex: data.accentHex) }
    var error: Color { Color(hex: data.errorHex) }
    var text: Color { Color(hex: data.textHex) }
    var textSecondary: Color { Color(hex: data.textSecondaryHex) }
    var surfaceLight: Color { Color(hex: data.surfaceLightHex) }
    var cellBackground: Color { Color(hex: data.cellBackgroundHex) }
    var cellBorder: Color { Color(hex: data.cellBorderHex) }
    var shadowColor: Color { Color(hex: data.shadowColorHex) }
    var tabBarBackground: Color { Color(hex: data.tabBarBackgroundHex) }
}

// MARK: - Color Extensions for Hex Conversion

extension Color {
    var hexString: String {
        guard let components = UIColor(self).cgColor.components else { return "#FFFFFF" }
        
        let r = Int(components[0] * 255.0)
        let g = Int(components.count > 1 ? components[1] * 255.0 : components[0] * 255.0)
        let b = Int(components.count > 2 ? components[2] * 255.0 : components[0] * 255.0)
        let a = Int(components.count > 3 ? components[3] * 255.0 : 255.0)
        
        if a == 255 {
            return String(format: "#%02lX%02lX%02lX", r, g, b)
        } else {
            return String(format: "#%02lX%02lX%02lX%02lX", r, g, b, a)
        }
    }
}

// MARK: - Theme Property Info

enum ThemeProperty: String, CaseIterable {
    case primary
    case secondary
    case background
    case surface
    case accent
    case error
    case text
    case textSecondary
    case surfaceLight
    case cellBackground
    case cellBorder
    case shadowColor
    case tabBarBackground
    
    var displayName: String {
        switch self {
        case .primary: return "Primary"
        case .secondary: return "Secondary"
        case .background: return "Background"
        case .surface: return "Surface"
        case .accent: return "Accent"
        case .error: return "Error"
        case .text: return "Text"
        case .textSecondary: return "Secondary Text"
        case .surfaceLight: return "Light Surface"
        case .cellBackground: return "Cell Background"
        case .cellBorder: return "Cell Border"
        case .shadowColor: return "Shadow"
        case .tabBarBackground: return "Tab Bar Background"
        }
    }
    
    var description: String {
        switch self {
        case .primary: return "Main brand color, used for primary actions"
        case .secondary: return "Secondary color for less prominent elements"
        case .background: return "Main background color for views"
        case .surface: return "Surface color for cards and elevated elements"
        case .accent: return "Accent color for highlights and special elements"
        case .error: return "Color for error states and warnings"
        case .text: return "Primary text color"
        case .textSecondary: return "Secondary text color for less important content"
        case .surfaceLight: return "Lighter surface variant"
        case .cellBackground: return "Background color for list cells"
        case .cellBorder: return "Border color for list cells"
        case .shadowColor: return "Color for shadows and elevation"
        case .tabBarBackground: return "Background color for tab bar"
        }
    }
    
    func getColor(from data: ThemeData) -> String {
        switch self {
        case .primary: return data.primaryHex
        case .secondary: return data.secondaryHex
        case .background: return data.backgroundHex
        case .surface: return data.surfaceHex
        case .accent: return data.accentHex
        case .error: return data.errorHex
        case .text: return data.textHex
        case .textSecondary: return data.textSecondaryHex
        case .surfaceLight: return data.surfaceLightHex
        case .cellBackground: return data.cellBackgroundHex
        case .cellBorder: return data.cellBorderHex
        case .shadowColor: return data.shadowColorHex
        case .tabBarBackground: return data.tabBarBackgroundHex
        }
    }
    
    func setColor(in data: inout ThemeData, hexValue: String) {
        switch self {
        case .primary: data.primaryHex = hexValue
        case .secondary: data.secondaryHex = hexValue
        case .background: data.backgroundHex = hexValue
        case .surface: data.surfaceHex = hexValue
        case .accent: data.accentHex = hexValue
        case .error: data.errorHex = hexValue
        case .text: data.textHex = hexValue
        case .textSecondary: data.textSecondaryHex = hexValue
        case .surfaceLight: data.surfaceLightHex = hexValue
        case .cellBackground: data.cellBackgroundHex = hexValue
        case .cellBorder: data.cellBorderHex = hexValue
        case .shadowColor: data.shadowColorHex = hexValue
        case .tabBarBackground: data.tabBarBackgroundHex = hexValue
        }
    }
}