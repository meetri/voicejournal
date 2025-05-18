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
            print("[LanguageSettings] Locale changed from \(oldValue.identifier) to \(selectedLocale.identifier)")
            
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
            print("[LanguageSettings] Loading saved locale: \(savedIdentifier)")
            
            // Create locale from saved identifier
            selectedLocale = Locale(identifier: savedIdentifier)
            
            // Verify the locale is supported for speech recognition
            // More flexible comparison using language and region codes
            let isSupported = SFSpeechRecognizer.supportedLocales().contains(where: { supportedLocale in
                return supportedLocale.languageCode == selectedLocale.languageCode &&
                       (supportedLocale.regionCode == selectedLocale.regionCode || 
                        selectedLocale.regionCode == nil)
            })
            
            if !isSupported {
                print("[LanguageSettings] Saved locale not supported, falling back to current locale")
                // Fall back to current locale if saved locale is not supported
                selectedLocale = Locale.current
            } else {
                print("[LanguageSettings] Saved locale is supported")
            }
        } else {
            print("[LanguageSettings] No saved locale, using system default: \(Locale.current.identifier)")
            selectedLocale = Locale.current
        }
        
        // Load available locales
        loadAvailableLocales()
        print("[LanguageSettings] Initialized with locale: \(selectedLocale.identifier)")
    }
    
    // Cache for supported locales
    private var cachedSupportedLocales: Set<Locale>?
    
    func loadAvailableLocales() {
        // Get supported locales for speech recognition (using cache if available)
        if cachedSupportedLocales == nil {
            cachedSupportedLocales = SFSpeechRecognizer.supportedLocales()
        }
        
        guard let supportedLocales = cachedSupportedLocales else { return }
        
        // Sort locales by their localized names
        availableLocales = Array(supportedLocales).sorted { 
            localizedName(for: $0).lowercased() < localizedName(for: $1).lowercased()
        }
    }
    
    func localizedName(for locale: Locale) -> String {
        // Fallback implementation for all iOS versions
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
