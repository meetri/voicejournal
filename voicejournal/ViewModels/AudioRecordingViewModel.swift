//
//  AudioRecordingViewModel.swift
//  voicejournal
//
//  Created on 4/27/25.
//

import Foundation
import SwiftUI
import CoreData
import Combine
import AVFoundation
import Speech

/// ViewModel for handling audio recording functionality
@MainActor
class AudioRecordingViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Current state of the recording
    @Published private(set) var isRecording = false
    
    /// Whether the recording is paused
    @Published private(set) var isPaused = false
    
    /// Current audio level (0.0 to 1.0)
    @Published private(set) var audioLevel: Float = 0.0
    
    /// Whether to show language selection sheet
    @Published var showingLanguageSelection = false
    
    /// Select a language for transcription
    @MainActor
    func selectLanguage(_ locale: Locale) {
        speechRecognitionService.setRecognitionLocale(locale)
        showingLanguageSelection = false
    }
    
    /// Duration of the current recording in seconds
    @Published private(set) var duration: TimeInterval = 0.0
    
    /// Formatted duration string (MM:SS)
    @Published private(set) var formattedDuration: String = "00:00"
    
    /// Error message to display
    @Published var errorMessage: String?
    
    /// Whether to show the error alert
    @Published var showErrorAlert = false
    
    /// Whether to show the permission denied alert
    @Published var showPermissionDeniedAlert = false
    
    /// Whether to show the speech recognition permission denied alert
    @Published var showSpeechPermissionDeniedAlert = false
    
    /// Whether the recording has been saved
    @Published private(set) var hasRecordingSaved = false
    
    /// Current transcription text (from speech recognition)
    @Published private(set) var transcriptionText: String = ""
    
    /// Whether transcription is in progress
    @Published private(set) var isTranscribing = false
    
    /// Transcription progress (0.0 to 1.0)
    @Published private(set) var transcriptionProgress: Float = 0.0
    
    /// Binding for hasRecordingSaved to use with sheet presentation
    var hasRecordingSavedBinding: Binding<Bool> {
        Binding(
            get: { self.hasRecordingSaved },
            set: { newValue in
                // Only allow setting to false (when sheet is dismissed)
                if newValue == false {
                    self.hasRecordingSaved = false
                }
            }
        )
    }
    
    /// The journal entry associated with the recording
    @Published private(set) var journalEntry: JournalEntry?
    
    // MARK: - Private Properties
    
    private let recordingService: AudioRecordingService
    private let speechRecognitionService: SpeechRecognitionService
    private var cancellables = Set<AnyCancellable>()
    private var managedObjectContext: NSManagedObjectContext
    private var processingTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init(context: NSManagedObjectContext, recordingService: AudioRecordingService, speechRecognitionService: SpeechRecognitionService = SpeechRecognitionService(), existingEntry: JournalEntry? = nil) {
        self.managedObjectContext = context
        self.recordingService = recordingService
        self.speechRecognitionService = speechRecognitionService
        self.journalEntry = existingEntry
        
        // Set the speech recognition locale from settings
        speechRecognitionService.setRecognitionLocale(LanguageSettings.shared.selectedLocale)
        
        // Set up publishers
        setupPublishers()
    }
    
    // MARK: - Public Methods
    
    /// Request microphone permission
    func requestMicrophonePermission() async {
        let granted = await recordingService.requestPermission()
        
        if !granted {
            showPermissionDeniedAlert = true
        }
    }
    
    /// Check if microphone permission is granted
    func checkMicrophonePermission() async -> Bool {
        let permission = await recordingService.checkPermission()
        return permission == .granted
    }
    
    /// Request speech recognition permission
    func requestSpeechRecognitionPermission() async {
        let permission = await speechRecognitionService.requestAuthorization()
        
        if permission != .granted {
            showSpeechPermissionDeniedAlert = true
        }
    }
    
    /// Check if speech recognition permission is granted
    func checkSpeechRecognitionPermission() -> Bool {
        let permission = speechRecognitionService.checkAuthorization()
        return permission == .granted
    }
    
    /// Start recording
    func startRecording() async {
        do {
            // Check microphone permission first
            let hasPermission = await checkMicrophonePermission()
            if !hasPermission {
                await requestMicrophonePermission()
                return
            }
            
            // Start recording
            try await recordingService.startRecording()
            
            isRecording = true
            isPaused = false
            hasRecordingSaved = false
            // Removed: journalEntry = nil (This was causing the double entry bug)
        
            // Start speech recognition if permission is granted
            if checkSpeechRecognitionPermission() {
                try await startSpeechRecognition()
            } else {
                // Request permission for future recordings
                await requestSpeechRecognitionPermission()
            }
            
        } catch {
            handleError(error)
        }
    }
    
    /// Start speech recognition
    private func startSpeechRecognition() async throws {
        do {
            // Start live recognition
            try await speechRecognitionService.startLiveRecognition()
            isTranscribing = true
            transcriptionText = ""
            transcriptionProgress = 0.0
        } catch {
            // Don't stop recording if speech recognition fails
            isTranscribing = false
        }
    }
    
    /// Pause recording
    func pauseRecording() async {
        do {
            try await recordingService.pauseRecording()
            isPaused = true
            
            // Pause speech recognition if active
            if isTranscribing {
                speechRecognitionService.pauseRecognition()
            }
        } catch {
            handleError(error)
        }
    }
    
    /// Resume recording
    func resumeRecording() async {
        do {
            try await recordingService.resumeRecording()
            isPaused = false
            
            // Resume speech recognition if it was active
            if isTranscribing {
                try speechRecognitionService.resumeRecognition()
            }
        } catch {
            handleError(error)
        }
    }
    
    /// Stop recording
    func stopRecording() async {
        do {
            if let recordingURL = try await recordingService.stopRecording() {
                isRecording = false
                isPaused = false
                
                // Stop speech recognition if active
                if isTranscribing {
                    speechRecognitionService.stopRecognition()
                    isTranscribing = false
                    
                    // Get final transcription and timing data
                    let finalTranscription = speechRecognitionService.transcription
                    transcriptionText = finalTranscription
                    
                    // Get timing data if available
                    let timingDataJSON = speechRecognitionService.getTimingDataJSON()
                }
                
                // Create a journal entry with the recording and transcription
                await createJournalEntry(recordingURL: recordingURL)
                
                // If no live transcription was done, process the audio file for transcription
                if transcriptionText.isEmpty && checkSpeechRecognitionPermission() {
                    processingTask = Task {
                        await processAudioFileForTranscription(recordingURL)
                    }
                }
            }
        } catch {
            handleError(error)
        }
    }
    
    /// Process audio file for transcription after recording
    private func processAudioFileForTranscription(_ url: URL) async {
        do {
            isTranscribing = true
            transcriptionProgress = 0.0
            
            // Get absolute URL from relative path if needed
            let fileURL = FilePathUtility.toAbsolutePath(from: url.path)
            
            // Recognize speech from file
            let transcription = try await speechRecognitionService.recognizeFromFile(url: fileURL)
            
            // Update transcription text
            transcriptionText = transcription
            transcriptionProgress = 1.0
            isTranscribing = false
            
            // Update journal entry with transcription if it exists
            if let entry = journalEntry {
                await updateJournalEntryWithTranscription(entry, text: transcription)
            }
        } catch {
            isTranscribing = false
            transcriptionProgress = 0.0
        }
    }
    
    /// Cancel recording
    func cancelRecording() async {
        do {
            _ = try await recordingService.stopRecording()
            await recordingService.deleteRecording()
            
            // Stop speech recognition if active
            if isTranscribing {
                speechRecognitionService.stopRecognition()
                isTranscribing = false
            }
            
            // Cancel any background processing
            processingTask?.cancel()
            processingTask = nil
            
            isRecording = false
            isPaused = false
            hasRecordingSaved = false
            journalEntry = nil
            transcriptionText = ""
            transcriptionProgress = 0.0
            
        } catch {
            handleError(error)
        }
    }
    
    /// Reset the view model state
    func reset() {
        isRecording = false
        isPaused = false
        audioLevel = 0.0
        duration = 0.0
        formattedDuration = "00:00"
        errorMessage = nil
        showErrorAlert = false
        hasRecordingSaved = false
        journalEntry = nil
        transcriptionText = ""
        isTranscribing = false
        transcriptionProgress = 0.0
        
        // Cancel any background processing
        processingTask?.cancel()
        processingTask = nil
        
        // Reset speech recognition service
        speechRecognitionService.reset()
    }
    
    // MARK: - Private Methods
    
    private func setupPublishers() {
        // Subscribe to audio level changes
        recordingService.$audioLevel
            .receive(on: RunLoop.main)
            .sink { [weak self] level in
                self?.audioLevel = level
            }
            .store(in: &cancellables)
        
        // Subscribe to duration changes
        recordingService.$duration
            .receive(on: RunLoop.main)
            .sink { [weak self] duration in
                self?.duration = duration
                self?.formattedDuration = self?.formatDuration(duration) ?? "00:00"
            }
            .store(in: &cancellables)
        
        // Subscribe to transcription changes
        speechRecognitionService.$transcription
            .receive(on: RunLoop.main)
            .sink { [weak self] text in
                if !text.isEmpty {
                    self?.transcriptionText = text
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to interim transcription changes
        speechRecognitionService.$interimTranscription
            .receive(on: RunLoop.main)
            .sink { [weak self] text in
                if let self = self, !text.isEmpty && self.isTranscribing {
                    // Combine final and interim transcriptions for display
                    let currentText = self.speechRecognitionService.currentTranscription
                    if !currentText.isEmpty {
                        self.transcriptionText = currentText
                    }
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to transcription progress
        speechRecognitionService.$progress
            .receive(on: RunLoop.main)
            .sink { [weak self] progress in
                self?.transcriptionProgress = progress
            }
            .store(in: &cancellables)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func handleError(_ error: Error) {
        if let recordingError = error as? AudioRecordingError {
            errorMessage = recordingError.localizedDescription
        } else if let recognitionError = error as? SpeechRecognitionError {
            errorMessage = recognitionError.localizedDescription
        } else {
            errorMessage = "An error occurred: \(error.localizedDescription)"
        }
        
        showErrorAlert = true
        
        // Reset recording state if needed
        if isRecording {
            isRecording = false
            isPaused = false
        }
        
        // Reset transcription state if needed
        if isTranscribing {
            isTranscribing = false
            speechRecognitionService.stopRecognition()
        }
    }
    
    private func createJournalEntry(recordingURL: URL) async {
        // Use existing entry or create a new one
        let entry: JournalEntry
        
        if let existingEntry = journalEntry {
            entry = existingEntry
        } else {
            entry = JournalEntry.create(in: managedObjectContext)
            entry.title = "Voice Journal - \(Date().formatted(date: .abbreviated, time: .shortened))"
        }
        
        // Convert absolute path to relative path before storing
        let relativePath = FilePathUtility.toRelativePath(from: recordingURL.path)
        
        // Create audio recording with relative path
        let recording = entry.createAudioRecording(filePath: relativePath)
        recording.duration = duration
        recording.fileSize = recordingService.fileSize ?? 0
        
        // Add transcription if available
        if !transcriptionText.isEmpty {
            let transcription = entry.createTranscription(text: transcriptionText)
            
            // Store timing data if available
            if let timingDataJSON = speechRecognitionService.getTimingDataJSON() {
                transcription.timingData = timingDataJSON
            }
            
            // Store the locale used for transcription
            transcription.locale = LanguageSettings.shared.selectedLocale.identifier
        }
        
        // Save the context
        do {
            try managedObjectContext.save()
            journalEntry = entry
            hasRecordingSaved = true
        } catch {
            handleError(error)
        }
    }
    
    /// Update journal entry with transcription
    private func updateJournalEntryWithTranscription(_ entry: JournalEntry, text: String) async {
        // Check if entry already has a transcription
        if let existingTranscription = entry.transcription {
            existingTranscription.text = text
            existingTranscription.modifiedAt = Date()
            
            // Update timing data if available
            if let timingDataJSON = speechRecognitionService.getTimingDataJSON() {
                existingTranscription.timingData = timingDataJSON
            }
            
            // Update the locale
            existingTranscription.locale = LanguageSettings.shared.selectedLocale.identifier
        } else {
            // Create new transcription
            let transcription = entry.createTranscription(text: text)
            
            // Store timing data if available
            if let timingDataJSON = speechRecognitionService.getTimingDataJSON() {
                transcription.timingData = timingDataJSON
            }
            
            // Store the locale
            transcription.locale = LanguageSettings.shared.selectedLocale.identifier
        }
        
        // Save the context
        do {
            try managedObjectContext.save()
        } catch {
            // Error handling without debug logs
        }
    }
}

// MARK: - Extensions

extension AudioRecordingViewModel {
    /// Get audio level for visualization (0.0 to 1.0)
    var visualizationLevel: CGFloat {
        return CGFloat(audioLevel)
    }
    
    /// Get recording duration in seconds
    var recordingDuration: Double {
        return duration
    }
    
    /// Check if the recording is in progress (either recording or paused)
    var isRecordingInProgress: Bool {
        return isRecording
    }
}
