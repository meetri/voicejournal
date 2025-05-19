import SwiftUI
import Speech

struct RecordingLanguagePickerSheet: View {
    @Binding var selectedLanguage: SpeechLanguage
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @StateObject private var languageSettings = LanguageSettings.shared
    
    let availableLanguages = SpeechLanguage.availableLanguages()
    
    var filteredLanguages: [SpeechLanguage] {
        if searchText.isEmpty {
            return availableLanguages
        } else {
            return availableLanguages.filter { language in
                language.name.localizedCaseInsensitiveContains(searchText) ||
                language.nativeName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if #available(iOS 15.0, *) {
                    List(filteredLanguages) { language in
                        LanguageRowView(
                            language: language,
                            selectedLanguage: selectedLanguage,
                            onSelect: {
                                selectedLanguage = language
                                languageSettings.updateDefaultRecordingLanguage(language)
                                isPresented = false
                            }
                        )
                    }
                    .searchable(text: $searchText, prompt: "Search languages")
                } else {
                    // iOS 14 compatible version
                    VStack {
                        SearchBar(text: $searchText)
                            .padding(.horizontal)
                        
                        List(filteredLanguages) { language in
                            LanguageRowView(
                                language: language,
                                selectedLanguage: selectedLanguage,
                                onSelect: {
                                    selectedLanguage = language
                                    languageSettings.updateDefaultRecordingLanguage(language)
                                    isPresented = false
                                }
                            )
                        }
                    }
                }
            }
            .navigationTitle("Select Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    // Helper function to get country name from locale
    private func getCountryName(for locale: Locale) -> String? {
        if #available(iOS 16.0, *) {
            if let regionCode = locale.region?.identifier {
                return Locale.current.localizedString(forRegionCode: regionCode)
            }
        } else {
            if let regionCode = locale.regionCode {
                return Locale.current.localizedString(forRegionCode: regionCode)
            }
        }
        return nil
    }
}

// Language row view component
struct LanguageRowView: View {
    let language: SpeechLanguage
    let selectedLanguage: SpeechLanguage
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    languageNameView
                    
                    if language.nativeName != language.name {
                        Text(language.nativeName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    additionalDetailsView
                }
                
                Spacer()
                
                if language == selectedLanguage {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var languageNameView: some View {
        HStack {
            Text(language.name)
                .foregroundColor(.primary)
                .fontWeight(.medium)
            
            if let countryName = getCountryName(for: language.locale) {
                Text("(\(countryName))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var additionalDetailsView: some View {
        HStack(spacing: 8) {
            Text(language.locale.identifier)
                .font(.caption2)
                .foregroundColor(Color(.tertiaryLabel))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(.systemGray5))
                .cornerRadius(4)
            
            if let recognizer = SFSpeechRecognizer(locale: language.locale),
               recognizer.supportsOnDeviceRecognition {
                offlineIndicatorView
            }
        }
    }
    
    @ViewBuilder
    private var offlineIndicatorView: some View {
        if #available(iOS 14.0, *) {
            Label("Offline", systemImage: "arrow.down.circle.fill")
                .font(.caption2)
                .foregroundColor(.green)
        } else {
            HStack(spacing: 2) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.caption2)
                Text("Offline")
                    .font(.caption2)
            }
            .foregroundColor(.green)
        }
    }
    
    private func getCountryName(for locale: Locale) -> String? {
        if #available(iOS 16.0, *) {
            if let regionCode = locale.region?.identifier {
                return Locale.current.localizedString(forRegionCode: regionCode)
            }
        } else {
            if let regionCode = locale.regionCode {
                return Locale.current.localizedString(forRegionCode: regionCode)
            }
        }
        return nil
    }
}

// iOS 14 compatible search bar
struct SearchBar: UIViewRepresentable {
    @Binding var text: String
    
    func makeUIView(context: Context) -> UISearchBar {
        let searchBar = UISearchBar()
        searchBar.delegate = context.coordinator
        searchBar.placeholder = "Search languages"
        searchBar.searchBarStyle = .minimal
        return searchBar
    }
    
    func updateUIView(_ uiView: UISearchBar, context: Context) {
        uiView.text = text
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UISearchBarDelegate {
        let parent: SearchBar
        
        init(_ parent: SearchBar) {
            self.parent = parent
        }
        
        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            parent.text = searchText
        }
    }
}

#Preview {
    RecordingLanguagePickerSheet(
        selectedLanguage: .constant(SpeechLanguage.defaultLanguage()),
        isPresented: .constant(true)
    )
}