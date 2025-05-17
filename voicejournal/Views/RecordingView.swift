//
//  RecordingView.swift
//  voicejournal
//
//  Created on 4/27/25.
//

import SwiftUI
import CoreData
import Speech

/// The main view for recording audio journal entries
struct RecordingView: View {
    // MARK: - Environment
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - View Model
    
    @StateObject private var viewModel: AudioRecordingViewModel
    
    // MARK: - Properties
    
    /// The journal entry being edited (if in edit mode)
    private var existingEntry: JournalEntry?
    
    /// Called when recording is complete (if in edit mode)
    private var onComplete: (() -> Void)?
    
    /// Whether the view is in edit mode (modifying an existing entry)
    private var isEditMode: Bool {
        existingEntry != nil
    }
    
    // MARK: - State
    
    @State private var showingPermissionSettings = false
    @State private var showingSpeechPermissionSettings = false
    @State private var showingTranscriptionEditor = false
    
    // MARK: - Initialization
    
    /// Initialize the recording view
    /// - Parameters:
    ///   - context: The managed object context to use
    ///   - existingEntry: An optional existing journal entry to edit
    ///   - onComplete: An optional callback when recording is complete (for edit mode)
    init(context: NSManagedObjectContext? = nil, existingEntry: JournalEntry? = nil, onComplete: (() -> Void)? = nil) {
        self.existingEntry = existingEntry
        self.onComplete = onComplete
        
        let ctx = context ?? PersistenceController.shared.container.viewContext
        // Create the AudioRecordingService on the main actor
        let recordingService = AudioRecordingService()
        
        // Initialize the view model with the existing entry if in edit mode
        _viewModel = StateObject(wrappedValue: AudioRecordingViewModel(
            context: ctx,
            recordingService: recordingService,
            existingEntry: existingEntry
        ))
    }
    
    // MARK: - Body
    
    var body: some View {
        let content = VStack(spacing: 20) {
            // Title (different based on mode)
            if let entry = existingEntry, let title = entry.title {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
            } else {
                Text("Voice Journal")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top)
            }
            
            Spacer()
            
            // Spectrum analyzer visualization
            AudioVisualizationView(
                audioLevel: viewModel.visualizationLevel,
                primaryColor: recordingColor,
                secondaryColor: recordingSecondaryColor,
                isActive: viewModel.isRecording && !viewModel.isPaused,
                frequencyData: viewModel.frequencyData,
                height: 70
            )
            .padding()
            .onAppear {
                print("DEBUG: RecordingView appeared - frequency data count: \(viewModel.frequencyData.count)")
            }
            
            // Timer display
            Text(viewModel.formattedDuration)
                .font(.system(size: 48, weight: .medium, design: .monospaced))
                .foregroundColor(recordingColor)
                .padding()
            
            // Transcription status and text
            transcriptionView
                .padding(.horizontal)
            
            Spacer()
            
            // Recording controls
            recordingControls
                .padding(.bottom, 40)
        }
        .padding()
        .background(Color(.systemBackground))
        .alert("Error", isPresented: $viewModel.showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
        .alert("Microphone Access Required", isPresented: $viewModel.showPermissionDeniedAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Settings") {
                showingPermissionSettings = true
            }
        } message: {
            Text("Voice Journal needs access to your microphone to record audio. Please grant permission in Settings.")
        }
        .alert("Speech Recognition Access Required", isPresented: $viewModel.showSpeechPermissionDeniedAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Settings") {
                showingSpeechPermissionSettings = true
            }
        } message: {
            Text("Voice Journal needs access to speech recognition to transcribe your recordings. Please grant permission in Settings.")
        }
        .sheet(isPresented: $showingPermissionSettings) {
            SettingsView(title: "Microphone Settings", message: "To enable microphone access, please go to your device settings.")
        }
        .sheet(isPresented: $showingSpeechPermissionSettings) {
            SettingsView(title: "Speech Recognition Settings", message: "To enable speech recognition, please go to your device settings.")
        }
        // Only show the RecordingSavedView sheet if not in edit mode
        .sheet(isPresented: isEditMode ? .constant(false) : viewModel.hasRecordingSavedBinding) {
            if let entry = viewModel.journalEntry {
                RecordingSavedView(journalEntry: entry)
            }
        }
        .onAppear {
            Task {
                await checkPermissions()
                
                // Auto-start recording if in edit mode
                if isEditMode {
                    await viewModel.startRecording()
                }
            }
        }
        
        // Wrap in NavigationView if in edit mode
        if isEditMode {
            NavigationView {
                content
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            if !viewModel.isRecording {
                                Button("Done") {
                                    if let completion = onComplete {
                                        completion()
                                    } else {
                                        dismiss()
                                    }
                                }
                            }
                        }
                    }
            }
        } else {
            content
        }
    }
    
    // MARK: - Subviews
    
    /// The recording controls view
    private var recordingControls: some View {
        HStack(spacing: 40) {
            // Cancel button (only shown when recording)
            if viewModel.isRecording {
                Button(action: {
                    Task {
                        await viewModel.cancelRecording()
                        // If in edit mode, call the completion handler after canceling
                        if isEditMode, let completion = onComplete {
                            completion()
                        }
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.red)
                }
                .transition(.scale)
            }
            
            // Record/Stop button
            Button(action: {
                if viewModel.isRecording {
                    Task {
                        await viewModel.stopRecording()
                        // If in edit mode, call the completion handler after stopping
                        if isEditMode, let completion = onComplete {
                            completion()
                        }
                    }
                } else {
                    Task {
                        await viewModel.startRecording()
                    }
                }
            }) {
                ZStack {
                    Circle()
                        .fill(viewModel.isRecording ? Color.red : Color.blue)
                        .frame(width: 80, height: 80)
                    
                    if viewModel.isRecording {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white)
                            .frame(width: 30, height: 30)
                    }
                }
            }
            .shadow(radius: 3)
            
            // Pause/Resume button (only shown when recording)
            if viewModel.isRecording {
                Button(action: {
                    if viewModel.isPaused {
                        Task {
                            await viewModel.resumeRecording()
                        }
                    } else {
                        Task {
                            await viewModel.pauseRecording()
                        }
                    }
                }) {
                    Image(systemName: viewModel.isPaused ? "play.circle.fill" : "pause.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.blue)
                }
                .transition(.scale)
            }
        }
        .animation(.spring(), value: viewModel.isRecording)
        .animation(.spring(), value: viewModel.isPaused)
    }
    
    // MARK: - Computed Properties
    
    /// The color to use for the recording visualization and timer
    private var recordingColor: Color {
        if !viewModel.isRecording {
            return .gray
        } else if viewModel.isPaused {
            return .orange
        } else {
            return .red
        }
    }
    
    /// The secondary color for gradient effects
    private var recordingSecondaryColor: Color {
        if !viewModel.isRecording {
            return .gray.opacity(0.6)
        } else if viewModel.isPaused {
            return .yellow
        } else {
            return .pink
        }
    }
    
    // MARK: - Subviews
    
    /// The transcription view
    private var transcriptionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.isTranscribing || !viewModel.transcriptionText.isEmpty {
                HStack {
                    Text("Transcription")
                        .font(.headline)
                    
                    // Language indicator
                    if !viewModel.currentTranscriptionLanguage.isEmpty {
                        // Log the language being displayed
                        let _ = print("DEBUG: Displaying language in UI: \(viewModel.currentTranscriptionLanguage)")
                        
                        // Determine color based on language status
                        let (displayText, textColor, bgColor) = getLanguageDisplayInfo(viewModel.currentTranscriptionLanguage)
                        
                        Text(displayText)
                            .font(.subheadline.bold())
                            .foregroundColor(textColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(bgColor)
                            .cornerRadius(4)
                            .onAppear {
                                print("DEBUG: Language indicator appeared with: \(viewModel.currentTranscriptionLanguage)")
                            }
                    } else {
                        let _ = print("DEBUG: Language is empty, not displaying indicator")
                    }
                    
                    Spacer()
                    
                    if viewModel.isTranscribing {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.7)
                            
                            Text("\(Int(viewModel.transcriptionProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if !viewModel.transcriptionText.isEmpty {
                    ScrollView {
                        Text(viewModel.transcriptionText)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    .frame(maxHeight: 100)
                } else if viewModel.isTranscribing {
                    Text("Transcribing...")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - Methods
    
    /// Check if microphone and speech recognition permissions are granted
    private func checkPermissions() async {
        _ = await viewModel.checkMicrophonePermission()
        
        // Also check speech recognition permission
        if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
            await viewModel.requestSpeechRecognitionPermission()
        }
    }
}

/// A view that shows settings for the app
struct SettingsView: View {
    var title: String
    var message: String
    
    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            
            Text(message)
                .multilineTextAlignment(.center)
                .padding()
            
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .padding()
            
            Spacer()
        }
        .padding()
    }
}

/// A view that shows when a recording has been saved
struct RecordingSavedView: View {
    let journalEntry: JournalEntry
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var isEditingTranscription = false
    @State private var transcriptionText: String = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                        .padding()
                    
                    Text("Recording Saved!")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    if let title = journalEntry.title {
                        Text(title)
                            .font(.headline)
                    }
                    
                    if let recording = journalEntry.audioRecording {
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Duration:")
                                Spacer()
                                Text(formatDuration(recording.duration))
                            }
                            
                            HStack {
                                Text("File Size:")
                                Spacer()
                                Text(formatFileSize(recording.fileSize))
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                    
                    // Transcription section
                    if let transcription = journalEntry.transcription, let text = transcription.text {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Transcription")
                                    .font(.headline)
                                
                                // Display language if available
                                if let timingData = transcription.timingData,
                                   let data = timingData.data(using: .utf8),
                                   let segments = try? JSONDecoder().decode([TranscriptionSegment].self, from: data),
                                   let firstSegment = segments.first,
                                   let locale = firstSegment.locale,
                                   !locale.isEmpty {
                                    // Log the language being displayed in saved view
                                    let _ = print("DEBUG: Displaying language in saved view: \(locale)")
                                    
                                    // Get the language name
                                    let languageName = Locale(identifier: locale).localizedLanguageName ?? locale
                                    
                                    // Determine color based on language status
                                    let (displayText, textColor, bgColor) = getLanguageDisplayInfo("(\(languageName))")
                                    
                                    Text(displayText)
                                        .font(.subheadline.bold())
                                        .foregroundColor(textColor)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(bgColor)
                                        .cornerRadius(4)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    transcriptionText = text
                                    isEditingTranscription = true
                                }) {
                                    Image(systemName: "pencil")
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            Text(text)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Transcription")
                                .font(.headline)
                            
                            Text("Processing transcription...")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                    
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $isEditingTranscription) {
                TranscriptionEditView(
                    journalEntry: journalEntry,
                    transcriptionText: $transcriptionText,
                    onSave: saveTranscription
                )
            }
        }
    }
    
    private func saveTranscription() {
        // Check if entry already has a transcription
        if let existingTranscription = journalEntry.transcription {
            existingTranscription.text = transcriptionText
            existingTranscription.modifiedAt = Date()
        } else {
            // Create new transcription
            let _ = journalEntry.createTranscription(text: transcriptionText)
        }
        
        // Save the context
        do {
            try viewContext.save()
        } catch {
            print("Error saving transcription: \(error.localizedDescription)")
        }
    }
    
    /// Format duration in seconds to MM:SS
    private func formatDuration(_ duration: Double) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// Format file size in bytes to human-readable string
    private func formatFileSize(_ size: Int64) -> String {
        let byteCountFormatter = ByteCountFormatter()
        byteCountFormatter.allowedUnits = [.useKB, .useMB]
        byteCountFormatter.countStyle = .file
        
        return byteCountFormatter.string(fromByteCount: size)
    }
}

// MARK: - Helper Functions

/// Get display information for the language indicator based on the language status
func getLanguageDisplayInfo(_ languageText: String) -> (String, Color, Color) {
    // Default values
    var displayText = languageText
    var textColor = Color.blue
    var bgColor = Color.blue.opacity(0.1)
    
    // Check for status indicators in the language text
    if languageText.contains("(Downloading...)") {
        displayText = languageText
        textColor = Color.orange
        bgColor = Color.orange.opacity(0.1)
    } else if languageText.contains("(Unavailable)") {
        displayText = languageText
        textColor = Color.red
        bgColor = Color.red.opacity(0.1)
    }
    
    return (displayText, textColor, bgColor)
}

// MARK: - Preview

#Preview {
    RecordingView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
