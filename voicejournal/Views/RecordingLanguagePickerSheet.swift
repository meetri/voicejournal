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
                        Button(action: {
                            selectedLanguage = language
                            languageSettings.updateDefaultRecordingLanguage(language)
                            isPresented = false
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(language.name)
                                        .foregroundColor(.primary)
                                    Text(language.nativeName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if language == selectedLanguage {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .searchable(text: $searchText, prompt: "Search languages")
                } else {
                    // iOS 14 compatible version
                    VStack {
                        SearchBar(text: $searchText)
                            .padding(.horizontal)
                        
                        List(filteredLanguages) { language in
                            Button(action: {
                                selectedLanguage = language
                                languageSettings.updateDefaultRecordingLanguage(language)
                                isPresented = false
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(language.name)
                                            .foregroundColor(.primary)
                                        Text(language.nativeName)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if language == selectedLanguage {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
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