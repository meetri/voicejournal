//
//  LanguageDebugView.swift
//  voicejournal
//
//  Created by meetri on 5/18/25.
//

import SwiftUI
import Speech

struct LanguageDebugView: View {
    @EnvironmentObject private var speechRecognitionService: SpeechRecognitionService
    @ObservedObject private var languageSettings = LanguageSettings.shared
    @Environment(\.themeManager) var themeManager
    
    @State private var timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    @State private var refreshId = UUID()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Current State")) {
                    LabeledContent("Language Settings") {
                        Text(languageSettings.selectedLocale.identifier)
                            .foregroundColor(themeManager.theme.accent)
                    }
                    
                    LabeledContent("Speech Service Locale") {
                        Text(speechRecognitionService.currentLocale.identifier)
                            .foregroundColor(themeManager.theme.accent)
                    }
                    
                    LabeledContent("Language Status") {
                        Text(speechRecognitionService.languageStatus.description)
                            .foregroundColor(statusColor)
                    }
                    
                    LabeledContent("Recognition State") {
                        Text(stateDescription)
                            .foregroundColor(stateColor)
                    }
                    
                    LabeledContent("Is Transcribing") {
                        Text(speechRecognitionService.state == .recognizing ? "Yes" : "No")
                            .foregroundColor(speechRecognitionService.state == .recognizing ? .green : .red)
                    }
                }
                
                Section(header: Text("Available Languages")) {
                    ForEach(languageSettings.availableLocales, id: \.identifier) { locale in
                        HStack {
                            Text(languageSettings.localizedName(for: locale))
                            
                            Spacer()
                            
                            if locale.identifier == languageSettings.selectedLocale.identifier {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                            
                            if locale.identifier == speechRecognitionService.currentLocale.identifier {
                                Image(systemName: "waveform")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                Section(header: Text("Actions")) {
                    Button("Refresh") {
                        refreshId = UUID()
                    }
                    .foregroundColor(themeManager.theme.accent)
                    
                    Button("Test Recognition") {
                        testRecognition()
                    }
                    .foregroundColor(themeManager.theme.accent)
                    
                    Button("Print Debug Info") {
                        printDebugInfo()
                    }
                    .foregroundColor(themeManager.theme.accent)
                }
                
                Section(header: Text("Console Output")) {
                    Text("Check Xcode console for detailed logs")
                        .font(.caption)
                        .foregroundColor(themeManager.theme.textSecondary)
                }
            }
            .navigationTitle("Language Debug")
            .navigationBarTitleDisplayMode(.inline)
            .themedNavigation()
            .id(refreshId) // Force refresh
            .onReceive(timer) { _ in
                // Force a refresh every second
                refreshId = UUID()
            }
        }
    }
    
    private var statusColor: Color {
        switch speechRecognitionService.languageStatus {
        case .available:
            return .green
        case .downloading:
            return .orange
        case .unavailable:
            return .red
        case .unknown:
            return themeManager.theme.textSecondary
        }
    }
    
    private var stateDescription: String {
        switch speechRecognitionService.state {
        case .unavailable:
            return "Unavailable"
        case .notAuthorized:
            return "Not Authorized"
        case .ready:
            return "Ready"
        case .recognizing:
            return "Recognizing"
        case .paused:
            return "Paused"
        case .finished:
            return "Finished"
        case .error(let error):
            return "Error: \(error.localizedDescription)"
        }
    }
    
    private var stateColor: Color {
        switch speechRecognitionService.state {
        case .recognizing:
            return .green
        case .ready:
            return .blue
        case .error:
            return .red
        default:
            return themeManager.theme.textSecondary
        }
    }
    
    private func testRecognition() {
        Task {
            do {
                // Testing recognition with locale
                try await speechRecognitionService.startLiveRecognition()
                
                // Stop after 2 seconds
                try await Task.sleep(nanoseconds: 2_000_000_000)
                speechRecognitionService.stopRecognition()
                
                // Test complete
            } catch {
                // Test failed: \(error)
            }
        }
    }
    
    private func printDebugInfo() {
        // Language debug info logged internally
        // Debug info separator
    }
}

#Preview {
    LanguageDebugView()
        .environment(\.themeManager, ThemeManager())
        .environmentObject(SpeechRecognitionService())
}