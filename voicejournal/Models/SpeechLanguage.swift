import Foundation
import Speech

struct SpeechLanguage: Identifiable, Equatable {
    let id: String // locale identifier (e.g., "en-US")
    let name: String // localized name
    let nativeName: String // name in its own language
    let locale: Locale
    
    var displayName: String {
        "\(name) - \(nativeName)"
    }
    
    init(locale: Locale) {
        self.id = locale.identifier
        self.locale = locale
        
        // Get localized name in the app's current language
        if #available(iOS 16.0, *) {
            self.name = locale.localizedString(forLanguageCode: locale.language.languageCode?.identifier ?? "") ?? locale.identifier
        } else {
            self.name = locale.localizedString(forLanguageCode: locale.languageCode ?? "") ?? locale.identifier
        }
        
        // Get native name (language name in its own language)
        let nativeLocale = Locale(identifier: locale.identifier)
        if #available(iOS 16.0, *) {
            self.nativeName = nativeLocale.localizedString(forLanguageCode: locale.language.languageCode?.identifier ?? "") ?? locale.identifier
        } else {
            self.nativeName = nativeLocale.localizedString(forLanguageCode: locale.languageCode ?? "") ?? locale.identifier
        }
    }
    
    static func availableLanguages() -> [SpeechLanguage] {
        // Get all supported locales from SFSpeechRecognizer
        let supportedLocales = SFSpeechRecognizer.supportedLocales()
        
        // Convert to SpeechLanguage objects and sort by name
        return supportedLocales
            .map { SpeechLanguage(locale: $0) }
            .sorted { $0.name < $1.name }
    }
    
    static func defaultLanguage() -> SpeechLanguage {
        // Try to use the device's current locale if supported
        let currentLocale = Locale.current
        if SFSpeechRecognizer.supportedLocales().contains(currentLocale) {
            return SpeechLanguage(locale: currentLocale)
        }
        
        // Fallback to en-US if current locale is not supported
        let fallbackLocale = Locale(identifier: "en-US")
        return SpeechLanguage(locale: fallbackLocale)
    }
    
    static func == (lhs: SpeechLanguage, rhs: SpeechLanguage) -> Bool {
        lhs.id == rhs.id
    }
}