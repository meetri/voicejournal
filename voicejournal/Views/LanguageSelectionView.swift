//
//  LanguageSelectionView.swift
//  voicejournal
//
//  Created on current date.
//

import SwiftUI

struct LanguageSelectionView: View {
    @ObservedObject private var languageSettings = LanguageSettings.shared
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var speechRecognitionService: SpeechRecognitionService
    
    var body: some View {
        NavigationView {
            List {
                ForEach(languageSettings.availableLocales, id: \.identifier) { locale in
                    Button(action: {
                        languageSettings.selectedLocale = locale
                        speechRecognitionService.setRecognitionLocale(locale)
                        dismiss()
                    }) {
                        HStack {
                            Text(languageSettings.localizedName(for: locale))
                            Spacer()
                            if locale.identifier == languageSettings.selectedLocale.identifier {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("Transcription Language")
            .navigationBarItems(trailing: Button("Cancel") {
                dismiss()
            })
        }
    }
}

struct LanguageSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        LanguageSelectionView()
            .environmentObject(SpeechRecognitionService())
    }
}
