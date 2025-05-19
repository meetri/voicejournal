//
//  AIAnalysisView.swift
//  voicejournal
//
//  Created on 5/18/25.
//

import SwiftUI
import CoreData

struct AIAnalysisView: View {
    let journalEntry: JournalEntry
    let audioURL: URL
    @Binding var isPresented: Bool
    
    @State private var isAnalyzing = false
    @State private var analysisResult: String?
    @State private var showError = false
    @State private var errorMessage = ""
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.themeManager) var themeManager
    
    private let aiService = AITranscriptionService.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                if isAnalyzing {
                    analysisLoadingView
                } else if let analysis = analysisResult {
                    analysisContentView(analysis)
                } else {
                    analysisStartView
                }
            }
            .navigationTitle("AI Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(themeManager.theme.accent)
                }
                
                if analysisResult != nil {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: saveAnalysis) {
                            Image(systemName: "square.and.arrow.down")
                                .foregroundColor(themeManager.theme.accent)
                        }
                    }
                }
            }
        }
        .alert("Analysis Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private var analysisLoadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: themeManager.theme.accent))
                .scaleEffect(1.5)
            
            Text("Analyzing audio...")
                .font(.headline)
                .foregroundColor(themeManager.theme.text)
            
            Text("This may take a few moments")
                .font(.caption)
                .foregroundColor(themeManager.theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeManager.theme.background)
    }
    
    private var analysisStartView: some View {
        VStack(spacing: 30) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundColor(themeManager.theme.accent)
            
            VStack(spacing: 12) {
                Text("AI Audio Analysis")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.theme.text)
                
                Text("Generate a comprehensive analysis of this audio recording")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(themeManager.theme.textSecondary)
                    .padding(.horizontal)
            }
            
            Button(action: startAnalysis) {
                HStack {
                    Image(systemName: "waveform.badge.magnifyingglass")
                    Text("Start Analysis")
                }
                .font(.headline)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(themeManager.theme.accent)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeManager.theme.background)
    }
    
    private func analysisContentView(_ analysis: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Markdown content will be displayed here
                // For now, we'll use a simple text view
                Text(analysis)
                    .font(.body)
                    .foregroundColor(themeManager.theme.text)
                    .padding()
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeManager.theme.background)
    }
    
    private func startAnalysis() {
        isAnalyzing = true
        
        Task {
            do {
                let transcription = journalEntry.transcription
                let result = try await aiService.analyzeAudioFile(
                    audioURL: audioURL,
                    transcription: transcription
                )
                
                await MainActor.run {
                    self.analysisResult = result
                    self.isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                    self.isAnalyzing = false
                }
            }
        }
    }
    
    private func saveAnalysis() {
        guard let analysis = analysisResult else { return }
        
        // Save the analysis to the transcription
        if let transcription = journalEntry.transcription {
            transcription.aiAnalysis = analysis
            transcription.modifiedAt = Date()
            
            do {
                try viewContext.save()
            } catch {
                print("Failed to save AI analysis: \(error)")
            }
        }
        
        isPresented = false
    }
}

// MARK: - Preview

#Preview {
    AIAnalysisView(
        journalEntry: JournalEntry(),
        audioURL: URL(fileURLWithPath: "/path/to/audio.m4a"),
        isPresented: .constant(true)
    )
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    .environment(\.themeManager, ThemeManager())
}