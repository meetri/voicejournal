//
//  AIAnalysisView.swift
//  voicejournal
//
//  Created on 5/18/25.
//

import SwiftUI
import CoreData

struct AIAnalysisView: View {
    @ObservedObject var journalEntry: JournalEntry
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
        
        // Log pre-analysis state for debugging
        print("🧠 [AIAnalysisView.startAnalysis] Starting analysis with current state:")
        print("  - Has transcription: \(journalEntry.transcription != nil)")
        if let transcription = journalEntry.transcription {
            print("  - Current AI analysis: \(transcription.aiAnalysis?.count ?? 0) characters")
            print("  - Encrypted AI analysis: \(transcription.encryptedAIAnalysis?.count ?? 0) bytes")
        }
        print("  - Audio URL path: \(audioURL.path)")
        print("  - Audio URL exists: \(FileManager.default.fileExists(atPath: audioURL.path))")
        
        Task {
            do {
                print("🧠 [AIAnalysisView.startAnalysis] Creating analysis task")
                let transcription = journalEntry.transcription
                
                // Make API call to analyze audio
                let result = try await aiService.analyzeAudioFile(
                    audioURL: audioURL,
                    transcription: transcription
                )
                
                // Update UI on main thread
                await MainActor.run {
                    print("🧠 [AIAnalysisView.startAnalysis] Analysis completed successfully, updating UI")
                    self.analysisResult = result
                    self.isAnalyzing = false
                }
                
                // Log post-analysis content before saving
                print("✅ [AIAnalysisView.startAnalysis] Analysis completed with length: \(result.count) characters")
                
                // Automatically save the analysis (on the main thread)
                await MainActor.run {
                    // Get the transcription or create it if it doesn't exist
                    var transcription = journalEntry.transcription
                    if transcription == nil {
                        transcription = journalEntry.createTranscription(text: "")
                    }
                    
                    if let transcription = transcription {
                        transcription.aiAnalysis = result
                        transcription.modifiedAt = Date()
                        
                        // Check if entry needs encryption after AI analysis
                        if journalEntry.hasEncryptedContent {
                            print("🔐 [AIAnalysisView] Entry has encrypted tag, checking encryption status")
                            
                            // Check if tag is globally accessible (has decryption key available)
                            if let encryptedTag = journalEntry.encryptedTag,
                               let key = EncryptedTagsAccessManager.shared.getEncryptionKey(for: encryptedTag) {
                                print("🔐 [AIAnalysisView] Encryption key available, encrypting AI analysis")
                                
                                // Encrypt the AI analysis with the tag's key
                                if let encryptedData = EncryptionManager.encrypt(result, using: key) {
                                    transcription.encryptedAIAnalysis = encryptedData
                                    transcription.aiAnalysis = nil
                                    print("✅ [AIAnalysisView] AI analysis encrypted successfully")
                                } else {
                                    print("❌ [AIAnalysisView] Failed to encrypt AI analysis")
                                }
                            } else {
                                print("⚠️ [AIAnalysisView] No encryption key available - analysis will remain unencrypted until tag is unlocked")
                            }
                        } else if journalEntry.isBaseEncrypted {
                            // Apply base encryption
                            print("🔐 [AIAnalysisView] Applying base encryption to AI analysis")
                            _ = journalEntry.applyBaseEncryption()
                        }
                        
                        do {
                            try viewContext.save()
                            print("✅ [AIAnalysisView] Successfully saved AI analysis to transcription")
                            
                            // Create a local copy of the journal entry object ID before refreshing
                            let entryObjectID = journalEntry.objectID
                            
                            // Force refresh the journal entry and related objects
                            viewContext.refresh(journalEntry, mergeChanges: true)
                            if let transcription = journalEntry.transcription {
                                viewContext.refresh(transcription, mergeChanges: true)
                                
                                // Log the state after refresh
                                print("📊 [AIAnalysisView] Transcription after refresh:")
                                print("  - AI analysis present: \(transcription.aiAnalysis != nil)")
                                print("  - Encrypted AI analysis present: \(transcription.encryptedAIAnalysis != nil)")
                                print("  - AI analysis length: \(transcription.aiAnalysis?.count ?? 0) characters")
                            }
                            if let audioRecording = journalEntry.audioRecording {
                                viewContext.refresh(audioRecording, mergeChanges: true)
                            }
                            
                            // Notify any observers about the change
                            NotificationCenter.default.post(
                                name: Notification.Name.aiEnhancementCompleted,
                                object: journalEntry,
                                userInfo: ["objectID": entryObjectID]
                            )
                            
                            print("✅ [AIAnalysisView] Notification posted via aiEnhancementCompleted")
                            
                            // Log final analysis state for debugging
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                if let transcription = journalEntry.transcription {
                                    print("📊 [AIAnalysisView] Final analysis state check:")
                                    print("  - AI analysis present: \(transcription.aiAnalysis != nil)")
                                    print("  - Encrypted AI analysis present: \(transcription.encryptedAIAnalysis != nil)")
                                    print("  - AI analysis length: \(transcription.aiAnalysis?.count ?? 0) characters")
                                }
                            }
                            
                            // Automatically dismiss the sheet after 1 second
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                isPresented = false
                                print("✅ [AIAnalysisView] Auto-dismissed after analysis completion")
                            }
                        } catch {
                            print("Failed to auto-save AI analysis: \(error)")
                        }
                    }
                }
            } catch {
                // Enhanced error reporting
                print("❌ [AIAnalysisView.startAnalysis] Analysis error: \(error)")
                
                // Get more specific error information
                let errorDetails: String
                if let aiError = error as? AITranscriptionError {
                    errorDetails = "AI Analysis Error: \(aiError.localizedDescription)"
                    print("  - AI Error type: \(String(describing: aiError))")
                } else {
                    errorDetails = "Error: \(error.localizedDescription)"
                    
                    // If it's a network or system error, print more details
                    if let nsError = error as NSError? {
                        print("  - Error domain: \(nsError.domain)")
                        print("  - Error code: \(nsError.code)")
                        if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                            print("  - Underlying error: \(underlyingError)")
                        }
                    }
                }
                
                // Update UI on main thread
                await MainActor.run {
                    self.errorMessage = errorDetails
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
            
            // Check if entry needs encryption after saving AI analysis
            if journalEntry.hasEncryptedContent {
                print("🔐 [AIAnalysisView] Entry has encrypted tag, checking encryption status")
                
                // Check if tag is globally accessible (has decryption key available)
                if let encryptedTag = journalEntry.encryptedTag,
                   let key = EncryptedTagsAccessManager.shared.getEncryptionKey(for: encryptedTag) {
                    print("🔐 [AIAnalysisView] Encryption key available, encrypting AI analysis")
                    
                    // Encrypt the AI analysis with the tag's key
                    if let encryptedData = EncryptionManager.encrypt(analysis, using: key) {
                        transcription.encryptedAIAnalysis = encryptedData
                        transcription.aiAnalysis = nil
                        print("✅ [AIAnalysisView] AI analysis encrypted successfully")
                    } else {
                        print("❌ [AIAnalysisView] Failed to encrypt AI analysis")
                    }
                } else {
                    print("⚠️ [AIAnalysisView] No encryption key available - analysis will remain unencrypted until tag is unlocked")
                }
            } else if journalEntry.isBaseEncrypted {
                // Apply base encryption
                print("🔐 [AIAnalysisView] Applying base encryption to AI analysis")
                _ = journalEntry.applyBaseEncryption()
            }
            
            do {
                try viewContext.save()
                print("✅ [AIAnalysisView] Successfully saved AI analysis using manual save")
                
                // Create a local copy of the journal entry object ID before refreshing
                let entryObjectID = journalEntry.objectID
                
                // Force refresh the journal entry and related objects
                viewContext.refresh(journalEntry, mergeChanges: true)
                if let transcription = journalEntry.transcription {
                    viewContext.refresh(transcription, mergeChanges: true)
                    
                    // Log the state after refresh
                    print("📊 [AIAnalysisView] Transcription after manual save and refresh:")
                    print("  - AI analysis present: \(transcription.aiAnalysis != nil)")
                    print("  - Encrypted AI analysis present: \(transcription.encryptedAIAnalysis != nil)")
                    print("  - AI analysis length: \(transcription.aiAnalysis?.count ?? 0) characters")
                }
                if let audioRecording = journalEntry.audioRecording {
                    viewContext.refresh(audioRecording, mergeChanges: true)
                }
                
                // Notify any observers about the change
                NotificationCenter.default.post(
                    name: Notification.Name.aiEnhancementCompleted,
                    object: journalEntry,
                    userInfo: ["objectID": entryObjectID]
                )
                
                print("✅ [AIAnalysisView] Manual save: Notification posted via aiEnhancementCompleted")
                
                // Dismiss the sheet after 0.5 seconds 
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    // Log final state before dismissing
                    if let transcription = journalEntry.transcription {
                        print("📊 [AIAnalysisView] Final analysis state before dismissal (manual save):")
                        print("  - AI analysis present: \(transcription.aiAnalysis != nil)")
                        print("  - Encrypted AI analysis present: \(transcription.encryptedAIAnalysis != nil)")
                        print("  - AI analysis length: \(transcription.aiAnalysis?.count ?? 0) characters")
                    }
                    
                    isPresented = false
                    print("✅ [AIAnalysisView] Auto-dismissed after manual save")
                }
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