//
//  LanguageSettings.swift
//  voicejournal
//
//  Created on 2025-05-01.
//

import Foundation
import Speech
import Combine

// Notification name for locale changes
extension Notification.Name {
    static let localeDidChange = Notification.Name("localeDidChange")
}

class LanguageSettings: ObservableObject {
    static let shared = LanguageSettings()
    
    @Published var selectedLocale: Locale {
        didSet {
            // Save the selected locale identifier to UserDefaults
            UserDefaults.standard.set(selectedLocale.identifier, forKey: "selectedLocaleIdentifier")
            
            // Notify any observers that the locale has changed
            NotificationCenter.default.post(name: .localeDidChange, object: selectedLocale)
        }
    }
    
    @Published var availableLocales: [Locale] = []
    
    private init() {
        // Load saved locale or use system default
        if let savedIdentifier = UserDefaults.standard.string(forKey: "selectedLocaleIdentifier") {
            selectedLocale = Locale(identifier: savedIdentifier)
        } else {
            selectedLocale = Locale.current
        }
        
        // Load available locales
        loadAvailableLocales()
    }
    
    func loadAvailableLocales() {
        // Get supported locales for speech recognition
        let supportedLocales = SFSpeechRecognizer.supportedLocales()
        
        // Sort locales by their localized names
        availableLocales = supportedLocales.sorted { 
            localizedName(for: $0).lowercased() < localizedName(for: $1).lowercased()
        }
    }
    
    func localizedName(for locale: Locale) -> String {
        // Get the display name in the current locale
        if let languageCode = locale.languageCode {
            let displayName = Locale.current.localizedString(forLanguageCode: languageCode)
            if let name = displayName, !name.isEmpty {
                // If there's a region code, add it in parentheses
                if let regionCode = locale.regionCode, let regionName = Locale.current.localizedString(forRegionCode: regionCode) {
                    return "\(name) (\(regionName))"
                }
                return name
            }
        }
        
        // Fallback to identifier if we couldn't get a proper name
        return locale.identifier
    }
}
