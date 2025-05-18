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
    
    /// Current language being used for transcription
    @Published private(set) var currentTranscriptionLanguage: String = ""
    
    /// Select a language for transcription
    func selectLanguage(_ locale: Locale) {
        speechRecognitionService.setRecognitionLocale(locale)
        currentTranscriptionLanguage = locale.localizedLanguageName ?? locale.identifier
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
    @Published private(set) var transcriptionText: String = "" {
        didSet {
            print("[AudioRecording] TranscriptionText updated: '\(transcriptionText)'")
        }
    }
    
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
    
    /// Frequency data for spectrum visualization
    @Published private(set) var frequencyData: [Float] = []
    
    // MARK: - Private Properties
    
    private let recordingService: AudioRecordingService
    private var speechRecognitionService: SpeechRecognitionService
    private let spectrumAnalyzerService: SpectrumAnalyzerService
    private var cancellables = Set<AnyCancellable>()
    private var managedObjectContext: NSManagedObjectContext
    private var processingTask: Task<Void, Never>?
    private var timingDataFromLiveRecognition: String?
    private var recordingStartTime: Date?
    private var speechRecognitionStartTime: Date?
    
    // Audio buffer processing
    private var audioBufferCancellable: AnyCancellable?
    
    // MARK: - Initialization
    
    init(context: NSManagedObjectContext, recordingService: AudioRecordingService, speechRecognitionService: SpeechRecognitionService? = nil, existingEntry: JournalEntry? = nil) {
        self.managedObjectContext = context
        self.recordingService = recordingService
        // Use 30 frequency bins to match the playback view bar count
        self.spectrumAnalyzerService = SpectrumAnalyzerService(frequencyBinCount: 30)
        self.journalEntry = existingEntry
        
        // Always create a speech recognition service 
        if let service = speechRecognitionService {
            self.speechRecognitionService = service
        } else {
            // Create a new instance with the correct locale
            let locale = LanguageSettings.shared.selectedLocale
            print("[AudioRecording] Creating speech recognizer with locale: \(locale.identifier)")
            self.speechRecognitionService = SpeechRecognitionService(locale: locale)
        }
        
        // Set the speech recognition locale from settings
        let locale = LanguageSettings.shared.selectedLocale
        print("[AudioRecording] Setting recognition locale to: \(locale.identifier)")
        self.speechRecognitionService.setRecognitionLocale(locale)
        currentTranscriptionLanguage = locale.localizedLanguageName ?? locale.identifier
        print("[AudioRecording] Current transcription language: \(currentTranscriptionLanguage)")
        
        // Always set up publishers in the init
        setupPublishers()
    }
    
    /// Update the speech recognition service from environment
    func updateSpeechRecognitionService(_ service: SpeechRecognitionService) {
        print("[AudioRecording] Updating speech recognition service from environment")
        self.speechRecognitionService = service
        
        // Ensure the correct locale is set
        let locale = LanguageSettings.shared.selectedLocale
        print("[AudioRecording] Updating service locale to: \(locale.identifier)")
        service.setRecognitionLocale(locale)
        currentTranscriptionLanguage = locale.localizedLanguageName ?? locale.identifier
        print("[AudioRecording] Updated transcription language: \(currentTranscriptionLanguage)")
        
        // Re-setup publishers with the new service
        cancellables.removeAll()
        setupPublishers()
        print("[AudioRecording] Re-setup publishers for new speech recognition service")
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
            
            // Start recording and capture the start time
            recordingStartTime = Date()
            try await recordingService.startRecording()
            print("[AudioRecording] Recording started at: \(recordingStartTime!)")
            
            // Set up audio buffer callback to share with spectrum analyzer
            recordingService.audioBufferCallback = { [weak self] buffer in
                self?.spectrumAnalyzerService.processAudioBuffer(buffer)
            }
            
            // Start spectrum analysis
            spectrumAnalyzerService.startMicrophoneAnalysis()
            do {
                try spectrumAnalyzerService.start()
            } catch {
            }
            
            isRecording = true
            isPaused = false
            hasRecordingSaved = false
            // Removed: journalEntry = nil (This was causing the double entry bug)
        
            // Start speech recognition if permission is granted
            if checkSpeechRecognitionPermission() {
                print("[AudioRecording] Speech recognition permission granted - starting recognition")
                do {
                    try await startSpeechRecognition()
                } catch {
                    print("[AudioRecording] Speech recognition error: \(error)")
                    // Handle speech recognition errors but continue recording
                }
            } else {
                print("[AudioRecording] Speech recognition permission not granted - requesting")
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
            print("[AudioRecording] Starting speech recognition")
            print("[AudioRecording] Language Settings locale: \(LanguageSettings.shared.selectedLocale.identifier)")
            print("[AudioRecording] Speech service current locale: \(speechRecognitionService.currentLocale.identifier)")
            
            // Check language status before starting
            speechRecognitionService.updateLanguageStatus()
            let status = speechRecognitionService.languageStatus
            print("[AudioRecording] Language status: \(status.description)")
            
            // Update the language display based on status
            let locale = speechRecognitionService.currentLocale
            
            // Set the language name with status if not available
            if status == .downloading {
                currentTranscriptionLanguage = "\(locale.localizedLanguageName ?? locale.identifier) (Downloading...)"
            } else if status == .unavailable {
                currentTranscriptionLanguage = "\(locale.localizedLanguageName ?? locale.identifier) (Unavailable)"
                
                // Try to fall back to English if the selected language is unavailable
                if locale.identifier != "en-US" {
                    print("[AudioRecording] Attempting fallback to English")
                    speechRecognitionService.setRecognitionLocale(Locale(identifier: "en-US"))
                    speechRecognitionService.updateLanguageStatus()
                    
                    if speechRecognitionService.languageStatus == .available {
                        currentTranscriptionLanguage = "English (Fallback)"
                        print("[AudioRecording] Fallback to English successful")
                    } else {
                        print("[AudioRecording] English fallback also unavailable")
                        throw SpeechRecognitionError.languageNotAvailable
                    }
                } else {
                    throw SpeechRecognitionError.languageNotAvailable
                }
            } else {
                currentTranscriptionLanguage = locale.localizedLanguageName ?? locale.identifier
            }
            
            // Log the language being used for debugging
            print("[AudioRecording] Using language: \(currentTranscriptionLanguage)")
            
            // Start live recognition
            speechRecognitionStartTime = Date()
            try await speechRecognitionService.startLiveRecognition()
            isTranscribing = true
            transcriptionText = ""
            transcriptionProgress = 0.0
            
            // Log timing offset
            if let recordingStart = recordingStartTime {
                let offset = speechRecognitionStartTime!.timeIntervalSince(recordingStart)
                print("[AudioRecording] Speech recognition started at: \(speechRecognitionStartTime!), offset: \(offset)s")
            }
            
        } catch let error as SpeechRecognitionError {
            // Don't stop recording if speech recognition fails
            isTranscribing = false
            
            // Update the language display based on the error
            switch error {
            case .languageModelDownloadRequired:
                currentTranscriptionLanguage = "\(speechRecognitionService.currentLocale.localizedLanguageName ?? speechRecognitionService.currentLocale.identifier) (Downloading...)"
            case .languageNotAvailable, .languageNotSupported:
                currentTranscriptionLanguage = "\(speechRecognitionService.currentLocale.localizedLanguageName ?? speechRecognitionService.currentLocale.identifier) (Unavailable)"
            default:
                break // Keep the current language name but show error
            }
            
            // Show error message
            errorMessage = error.localizedDescription
            showErrorAlert = true
            
        } catch {
            // Handle other errors
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
            guard let recordingURL = try await recordingService.stopRecording() else {
                return
            }
            
            isRecording = false
            isPaused = false
            
            // Stop spectrum analysis
            spectrumAnalyzerService.stop()
            
            // Stop speech recognition if active
            if isTranscribing {
                // Save the current transcription text before stopping
                let savedTranscription = self.transcriptionText
                print("[AudioRecording] Saved transcription before stop: '\(savedTranscription)'")
                
                // Get the complete transcription (including interim) before stopping
                let completeTranscription = speechRecognitionService.currentTranscription
                print("[AudioRecording] Complete transcription on stop: '\(completeTranscription)'")
                
                // Use whichever transcription has more content
                let bestTranscription = completeTranscription.count > savedTranscription.count ? completeTranscription : savedTranscription
                
                // Get timing data BEFORE stopping recognition
                if let timingDataJSON = speechRecognitionService.getTimingDataJSON() {
                    print("[AudioRecording] Original timing data from live recognition (before stop): \(timingDataJSON.prefix(200))...")
                    
                    // Calculate offset if we have both timestamps
                    if let recordingStart = recordingStartTime, let speechStart = speechRecognitionStartTime {
                        let offset = speechStart.timeIntervalSince(recordingStart)
                        print("[AudioRecording] Timing offset between recording and speech recognition: \(offset)s")
                        
                        // Adjust timing data by the offset
                        if let adjustedData = adjustTimingData(timingDataJSON, byOffset: offset) {
                            self.timingDataFromLiveRecognition = adjustedData
                            print("[AudioRecording] Adjusted timing data: \(adjustedData.prefix(200))...")
                        } else {
                            self.timingDataFromLiveRecognition = timingDataJSON
                        }
                    } else {
                        print("[AudioRecording] Missing timestamps - recording: \(recordingStartTime != nil), speech: \(speechRecognitionStartTime != nil)")
                        self.timingDataFromLiveRecognition = timingDataJSON
                    }
                } else {
                    print("[AudioRecording] No timing data available from live recognition")
                    self.timingDataFromLiveRecognition = nil
                }
                
                // Mark transcribing as false BEFORE stopping recognition to prevent updates
                isTranscribing = false
                
                // Now stop recognition
                speechRecognitionService.stopRecognition()
                
                // Use the best transcription we captured
                transcriptionText = bestTranscription
                print("[AudioRecording] Final transcription text: '\(transcriptionText)'")
            }
            
            // Create a journal entry with the recording and transcription
            await createJournalEntry(recordingURL: recordingURL)
            
            // If no live transcription was done, process the audio file for transcription
            if transcriptionText.isEmpty && checkSpeechRecognitionPermission() {
                processingTask?.cancel()
                processingTask = Task {
                    await processAudioFileForTranscription(recordingURL)
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
            // Don't show error alert for transcription failures
            // This is a background task and shouldn't interrupt the user
            // Transcription failed
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
            
            // Stop spectrum analysis
            spectrumAnalyzerService.stop()
            
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
        
        // Update the current language display
        let locale = speechRecognitionService.currentLocale
        currentTranscriptionLanguage = locale.localizedLanguageName ?? locale.identifier
        
        // Cancel any background processing
        processingTask?.cancel()
        processingTask = nil
        
        // Reset speech recognition service
        speechRecognitionService.reset()
            
        // Reset timing data
        timingDataFromLiveRecognition = nil
    }
    
    // MARK: - Private Methods
    
    private func setupPublishers() {
        print("[AudioRecording] Setting up publishers")
        
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
                print("[AudioRecording] Final transcription update: '\(text)'")
                if !text.isEmpty {
                    self?.transcriptionText = text
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to interim transcription changes
        speechRecognitionService.$interimTranscription
            .receive(on: RunLoop.main)
            .sink { [weak self] text in
                print("[AudioRecording] Interim transcription update: '\(text)'")
                print("[AudioRecording] isTranscribing: \(self?.isTranscribing ?? false)")
                if let self = self {
                    // Always update transcription text when we receive interim updates
                    let currentText = self.speechRecognitionService.currentTranscription
                    print("[AudioRecording] Combined transcription: '\(currentText)'")
                    if self.isTranscribing || !currentText.isEmpty {
                        self.transcriptionText = currentText
                        print("[AudioRecording] Updated transcriptionText to: '\(self.transcriptionText)'")
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
        
        // Subscribe to frequency data from spectrum analyzer
        spectrumAnalyzerService.frequencyDataPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] data in
                if !data.isEmpty {
                }
                self?.frequencyData = data
            }
            .store(in: &cancellables)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Timing Data Scaling
    
    /// Scale timing data to match the actual audio duration
    private func scaleTimingDataToAudioDuration(segments: [TranscriptionSegment], audioDuration: TimeInterval) -> [TranscriptionSegment] {
        guard !segments.isEmpty, audioDuration > 0 else { return segments }
        
        // Find the current range of the timing data
        let minTime = segments.map(\.startTime).min() ?? 0
        let maxTime = segments.map(\.endTime).max() ?? 1
        let currentDuration = maxTime - minTime
        
        // If duration is already reasonable, don't scale
        if currentDuration > audioDuration * 0.8 {
            return segments
        }
        
        // Calculate scaling factor to distribute segments across actual duration
        // Leave some buffer at the end (95% of duration)
        let targetDuration = audioDuration * 0.95
        let scaleFactor = targetDuration / currentDuration
        
        // Scale and adjust segments
        var scaledSegments: [TranscriptionSegment] = []
        for segment in segments {
            let scaledStartTime = (segment.startTime - minTime) * scaleFactor
            let scaledEndTime = (segment.endTime - minTime) * scaleFactor
            
            let scaledSegment = TranscriptionSegment(
                text: segment.text,
                startTime: scaledStartTime,
                endTime: scaledEndTime,
                range: segment.textRange,
                locale: segment.locale
            )
            scaledSegments.append(scaledSegment)
        }
        
        print("[AudioRecording] Scaled \(segments.count) segments from \(currentDuration)s to \(targetDuration)s")
        return scaledSegments
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
        do {
            // Use existing entry or create a new one
            let entry: JournalEntry
            
            if let existingEntry = journalEntry {
                entry = existingEntry
            } else {
                entry = JournalEntry.create(in: managedObjectContext)
                entry.title = "Vox Cipher - \(Date().formatted(date: .abbreviated, time: .shortened))"
            }
            
            // Convert absolute path to relative path before storing
            let relativePath = FilePathUtility.toRelativePath(from: recordingURL.path)
            
            // Create audio recording with relative path
            let recording = entry.createAudioRecording(filePath: relativePath)
            recording.duration = duration
            recording.fileSize = recordingService.fileSize ?? 0
            
            // Add transcription if available
            if !transcriptionText.isEmpty {
                print("[AudioRecording] Creating transcription with text: '\(transcriptionText)'")
                let transcription = entry.createTranscription(text: transcriptionText)
                print("[AudioRecording] Transcription created: \(transcription)")
                
                // Enhance transcription if enabled and AI is configured
                if TranscriptionSettings.shared.autoEnhanceNewTranscriptions,
                   AIConfigurationManager.shared.activeConfiguration != nil {
                    let aiService = AITranscriptionService.shared
                    let enabledFeatures = TranscriptionSettings.shared.enabledFeatures
                    
                    // Perform enhancement asynchronously
                    Task {
                        do {
                            let enhanced = try await aiService.enhanceTranscription(
                                text: transcriptionText,
                                features: enabledFeatures,
                                context: managedObjectContext
                            )
                            
                            // Update the transcription with enhanced text
                            await MainActor.run {
                                transcription.text = enhanced.enhancedText
                                transcription.modifiedAt = Date()
                                do {
                                    try managedObjectContext.save()
                                } catch {
                                    print("Failed to save enhanced transcription: \(error)")
                                }
                            }
                        } catch {
                            // Enhancement failed, continue with original text
                            print("Transcription enhancement failed: \(error.localizedDescription)")
                        }
                    }
                }
                
                // Store timing data if available - first try from live recognition, then from file processing
                let timingData = timingDataFromLiveRecognition ?? speechRecognitionService.getTimingDataJSON()
                if let timingDataJSON = timingData {
                    // Convert string to data for JSON decoding
                    if let jsonData = timingDataJSON.data(using: .utf8),
                       let segments = try? JSONDecoder().decode([TranscriptionSegment].self, from: jsonData) {
                        // Check if all segments have very short durations (indicating interim results)
                        let allInterim = segments.allSatisfy { $0.endTime - $0.startTime <= 0.15 }
                        
                        if allInterim && duration > 0 {
                            // Scale segments to distribute evenly across the audio duration
                            let scaledSegments = scaleTimingDataToAudioDuration(segments: segments, audioDuration: duration)
                            if let scaledData = try? JSONEncoder().encode(scaledSegments),
                               let scaledJSON = String(data: scaledData, encoding: .utf8) {
                                transcription.timingData = scaledJSON
                                print("[AudioRecording] Stored scaled timing data to match audio duration: \(duration)s")
                            } else {
                                transcription.timingData = timingDataJSON
                                print("[AudioRecording] Failed to scale timing data, using original")
                            }
                        } else {
                            transcription.timingData = timingDataJSON
                            print("[AudioRecording] Stored timing data in transcription (appears to have final results)")
                        }
                    } else {
                        transcription.timingData = timingDataJSON
                        print("[AudioRecording] Stored timing data in transcription: \(timingDataJSON.prefix(200))...")
                    }
                } else {
                    print("[AudioRecording] No timing data available to store")
                }
                
                // Store the locale used for transcription in the journal entry
                // Note: Transcription model doesn't have a locale property
            }
            
            // Save the context
            do {
                try managedObjectContext.save()
                journalEntry = entry
                hasRecordingSaved = true
                print("[AudioRecording] Journal entry saved successfully")
                print("[AudioRecording] Transcription text: '\(entry.transcription?.text ?? "none")'")
            } catch {
                print("[AudioRecording] Failed to save journal entry: \(error)")
                // Failed to save managed object context
                throw error
            }
        } catch {
            handleError(error)
        }
    }
    
    /// Update journal entry with transcription
    private func updateJournalEntryWithTranscription(_ entry: JournalEntry, text: String) async {
        do {
            let transcription: Transcription
            
            // Check if entry already has a transcription
            if let existingTranscription = entry.transcription {
                existingTranscription.text = text
                existingTranscription.modifiedAt = Date()
                transcription = existingTranscription
                
                // Update timing data if available
                if let timingDataJSON = speechRecognitionService.getTimingDataJSON() {
                    existingTranscription.timingData = timingDataJSON
                }
                
                // Update the modified date (locale is not available on Transcription)
            } else {
                // Create new transcription
                transcription = entry.createTranscription(text: text)
                
                // Store timing data if available
                if let timingDataJSON = speechRecognitionService.getTimingDataJSON() {
                    transcription.timingData = timingDataJSON
                }
                
                // Note: Transcription model doesn't have a locale property
            }
            
            // Save the context first
            try managedObjectContext.save()
            
            // Enhance transcription if enabled and AI is configured
            if TranscriptionSettings.shared.autoEnhanceNewTranscriptions,
               AIConfigurationManager.shared.activeConfiguration != nil {
                let aiService = AITranscriptionService.shared
                let enabledFeatures = TranscriptionSettings.shared.enabledFeatures
                
                // Perform enhancement asynchronously
                Task {
                    do {
                        let enhanced = try await aiService.enhanceTranscription(
                            text: text,
                            features: enabledFeatures,
                            context: managedObjectContext
                        )
                        
                        // Update the transcription with enhanced text
                        await MainActor.run {
                            transcription.text = enhanced.enhancedText
                            transcription.modifiedAt = Date()
                            do {
                                try managedObjectContext.save()
                            } catch {
                                print("Failed to save enhanced transcription: \(error)")
                            }
                        }
                    } catch {
                        // Enhancement failed, continue with original text
                        print("Transcription enhancement failed: \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            // Failed to update journal entry with transcription
            // Don't throw the error up to the caller as this is a background operation
        }
    }
    
    /// Adjust timing data by a given offset
    private func adjustTimingData(_ timingDataJSON: String, byOffset offset: TimeInterval) -> String? {
        guard let data = timingDataJSON.data(using: .utf8) else { 
            print("[AudioRecording] Failed to convert timing data to Data")
            return nil 
        }
        
        do {
            // Parse the timing data JSON
            let decoder = JSONDecoder()
            let segments = try decoder.decode([TranscriptionSegment].self, from: data)
            
            print("[AudioRecording] Adjusting \(segments.count) segments by offset: \(offset)s")
            if let firstSegment = segments.first, let lastSegment = segments.last {
                print("[AudioRecording] Original timing: \(firstSegment.startTime)s - \(lastSegment.endTime)s")
            }
            
            // Adjust all segment timings by ADDING the offset, since segments are relative to speech recognition start
            // and we need to adjust them to be relative to recording start
            let adjustedSegments = segments.map { segment in
                TranscriptionSegment(
                    text: segment.text,
                    startTime: segment.startTime + offset,
                    endTime: segment.endTime + offset,
                    range: segment.textRange,
                    locale: segment.locale
                )
            }
            
            if let firstAdjusted = adjustedSegments.first, let lastAdjusted = adjustedSegments.last {
                print("[AudioRecording] Adjusted timing: \(firstAdjusted.startTime)s - \(lastAdjusted.endTime)s")
            }
            
            // Encode back to JSON
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let adjustedData = try encoder.encode(adjustedSegments)
            
            return String(data: adjustedData, encoding: .utf8)
        } catch {
            print("[AudioRecording] Failed to adjust timing data: \(error)")
            return nil
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

extension Locale {
    /// Returns the localized display name of the language for this locale
    var localizedLanguageName: String? {
        return (Locale.current).localizedString(forIdentifier: identifier)
    }
}
