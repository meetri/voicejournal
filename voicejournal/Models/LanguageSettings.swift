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
            // Create locale from saved identifier
            selectedLocale = Locale(identifier: savedIdentifier)
            
            // Verify the locale is supported for speech recognition
            if !SFSpeechRecognizer.supportedLocales().contains(where: { $0.identifier == selectedLocale.identifier }) {
                // Fall back to current locale if saved locale is not supported
                selectedLocale = Locale.current
            }
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
        // First try to get the display name for the locale
        if #available(iOS 16.0, *) {
            // Use newer API on iOS 16+
            return locale.localizedLanguageName
        } else {
            // Fallback for older iOS versions
            if let languageCode = locale.languageCode {
                if let displayName = Locale.current.localizedString(forLanguageCode: languageCode), !displayName.isEmpty {
                    // If there's a region code, add it in parentheses
                    if let regionCode = locale.regionCode, 
                       let regionName = Locale.current.localizedString(forRegionCode: regionCode) {
                        return "\(displayName) (\(regionName))"
                    }
                    return displayName
                }
            }
            
            // Last resort fallback
            return locale.identifier
        }
    }
}
