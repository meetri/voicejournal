//
//  LanguageSettings.swift
//  voicejournal
//
//  Created on current date.
//

import Foundation
import Speech
import Combine

class LanguageSettings: ObservableObject {
    static let shared = LanguageSettings()
    
    @Published var selectedLocale: Locale {
        didSet {
            UserDefaults.standard.set(selectedLocale.identifier, forKey: "selectedLocaleIdentifier")
        }
    }
    
    @Published var availableLocales: [Locale] = []
    
    private init() {
        // Load saved locale or use system default
        if let savedIdentifier = UserDefaults.standard.string(forKey: "selectedLocaleIdentifier"),
           let savedLocale = Locale(identifier: savedIdentifier) {
            selectedLocale = savedLocale
        } else {
            selectedLocale = Locale.current
        }
        
        // Load available locales
        loadAvailableLocales()
    }
    
    func loadAvailableLocales() {
        availableLocales = SFSpeechRecognizer.supportedLocales().sorted { 
            localizedName(for: $0).lowercased() < localizedName(for: $1).lowercased()
        }
    }
    
    func localizedName(for locale: Locale) -> String {
        return locale.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
    }
}
