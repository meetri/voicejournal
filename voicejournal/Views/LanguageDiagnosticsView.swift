//
//  LanguageDiagnosticsView.swift
//  voicejournal
//
//  Created by meetri on 5/18/25.
//

import SwiftUI
import Speech

struct LanguageDiagnosticsView: View {
    @State private var supportedLocales: [Locale] = []
    @State private var currentLocale: Locale = Locale.current
    @State private var selectedLocale: Locale = LanguageSettings.shared.selectedLocale
    @State private var recognizerStatus: [Locale: String] = [:]
    @Environment(\.themeManager) var themeManager
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Current Settings")) {
                    LabeledContent("System Locale") {
                        Text(Locale.current.identifier)
                    }
                    LabeledContent("Selected Locale") {
                        Text(LanguageSettings.shared.selectedLocale.identifier)
                    }
                    LabeledContent("Speech Service Locale") {
                        Text(SpeechRecognitionService().currentLocale.identifier)
                    }
                }
                
                Section(header: Text("Supported Languages")) {
                    Text("Total: \(supportedLocales.count) languages")
                    
                    ForEach(supportedLocales, id: \.identifier) { locale in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(localizedName(for: locale))
                                    .font(.headline)
                                Text(locale.identifier)
                                    .font(.caption)
                                    .foregroundColor(themeManager.theme.textSecondary)
                            }
                            
                            Spacer()
                            
                            if let status = recognizerStatus[locale] {
                                Text(status)
                                    .font(.caption)
                                    .foregroundColor(statusColor(for: status))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section(header: Text("Test Recognition")) {
                    Button("Test All Languages") {
                        testAllLanguages()
                    }
                    .foregroundColor(themeManager.theme.accent)
                }
            }
            .navigationTitle("Language Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .themedNavigation()
            .onAppear {
                loadSupportedLocales()
            }
        }
    }
    
    private func loadSupportedLocales() {
        supportedLocales = SFSpeechRecognizer.supportedLocales()
            .sorted { $0.identifier < $1.identifier }
    }
    
    private func testAllLanguages() {
        for locale in supportedLocales {
            let recognizer = SFSpeechRecognizer(locale: locale)
            
            if let recognizer = recognizer {
                if recognizer.isAvailable {
                    recognizerStatus[locale] = "Available"
                } else {
                    recognizerStatus[locale] = "Downloading"
                }
            } else {
                recognizerStatus[locale] = "Unavailable"
            }
        }
    }
    
    private func localizedName(for locale: Locale) -> String {
        if let languageCode = locale.languageCode {
            if let displayName = Locale.current.localizedString(forLanguageCode: languageCode) {
                if let regionCode = locale.regionCode,
                   let regionName = Locale.current.localizedString(forRegionCode: regionCode) {
                    return "\(displayName) (\(regionName))"
                }
                return displayName
            }
        }
        return locale.identifier
    }
    
    private func statusColor(for status: String) -> Color {
        switch status {
        case "Available":
            return .green
        case "Downloading":
            return .orange
        case "Unavailable":
            return .red
        default:
            return themeManager.theme.textSecondary
        }
    }
}

#Preview {
    LanguageDiagnosticsView()
        .environment(\.themeManager, ThemeManager())
}