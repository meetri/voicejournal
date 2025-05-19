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
            
            // Update default recording language to match
            defaultRecordingLanguage = SpeechLanguage(locale: selectedLocale)
            
            // Notify any observers that the locale has changed
            NotificationCenter.default.post(name: .localeDidChange, object: selectedLocale)
        }
    }
    
    @Published var availableLocales: [Locale] = []
    
    @Published var defaultRecordingLanguage: SpeechLanguage
    
    private init() {
        // Temporary variable to hold the locale
        let tempLocale: Locale
        
        // Load saved locale or use system default
        if let savedIdentifier = UserDefaults.standard.string(forKey: "selectedLocaleIdentifier") {
            // Create locale from saved identifier
            let savedLocale = Locale(identifier: savedIdentifier)
            
            // Verify the locale is supported for speech recognition
            // More flexible comparison using language and region codes
            let isSupported = SFSpeechRecognizer.supportedLocales().contains(where: { supportedLocale in
                if #available(iOS 16.0, *) {
                    return supportedLocale.language.languageCode?.identifier == savedLocale.language.languageCode?.identifier &&
                           (supportedLocale.region?.identifier == savedLocale.region?.identifier || 
                            savedLocale.region?.identifier == nil)
                } else {
                    return supportedLocale.languageCode == savedLocale.languageCode &&
                           (supportedLocale.regionCode == savedLocale.regionCode || 
                            savedLocale.regionCode == nil)
                }
            })
            
            if !isSupported {
                // Fall back to current locale if saved locale is not supported
                tempLocale = Locale.current
            } else {
                tempLocale = savedLocale
            }
        } else {
            tempLocale = Locale.current
        }
        
        // Initialize both properties together
        selectedLocale = tempLocale
        defaultRecordingLanguage = SpeechLanguage(locale: tempLocale)
        
        // Load default recording language
        if let savedRecordingLanguageId = UserDefaults.standard.string(forKey: "defaultRecordingLanguageId") {
            if let savedLocale = SFSpeechRecognizer.supportedLocales().first(where: { $0.identifier == savedRecordingLanguageId }) {
                defaultRecordingLanguage = SpeechLanguage(locale: savedLocale)
            } else {
                defaultRecordingLanguage = SpeechLanguage.defaultLanguage()
            }
        } else {
            defaultRecordingLanguage = SpeechLanguage.defaultLanguage()
        }
        
        // Load available locales
        loadAvailableLocales()
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
        if #available(iOS 16.0, *) {
            if let languageCode = locale.language.languageCode?.identifier {
                if let displayName = Locale.current.localizedString(forLanguageCode: languageCode), !displayName.isEmpty {
                    // If there's a region code, add it in parentheses
                    if let regionCode = locale.region?.identifier, 
                       let regionName = Locale.current.localizedString(forRegionCode: regionCode) {
                        return "\(displayName) (\(regionName))"
                    }
                    return displayName
                }
            }
        } else {
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
        }
        
        // Last resort fallback
        return locale.identifier
    }
    
    func updateDefaultRecordingLanguage(_ language: SpeechLanguage) {
        defaultRecordingLanguage = language
        UserDefaults.standard.set(language.id, forKey: "defaultRecordingLanguageId")
    }
}
