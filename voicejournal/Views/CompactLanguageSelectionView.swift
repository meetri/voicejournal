import SwiftUI

struct CompactLanguageSelectionView: View {
    @Binding var selectedLanguage: SpeechLanguage
    @State private var showingPicker = false
    
    var body: some View {
        Button(action: {
            showingPicker = true
        }) {
            HStack {
                Image(systemName: "globe")
                    .foregroundColor(.secondary)
                
                Text("Language")
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack {
                    Text(selectedLanguage.name)
                        .foregroundColor(.primary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingPicker) {
            RecordingLanguagePickerSheet(selectedLanguage: $selectedLanguage, isPresented: $showingPicker)
        }
    }
}

#Preview {
    CompactLanguageSelectionView(selectedLanguage: .constant(SpeechLanguage.defaultLanguage()))
}