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
    
    /// Whether the recording has been saved
    @Published private(set) var hasRecordingSaved = false
    
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
    private var cancellables = Set<AnyCancellable>()
    private var managedObjectContext: NSManagedObjectContext
    
    // MARK: - Initialization
    
    init(context: NSManagedObjectContext, recordingService: AudioRecordingService) {
        self.managedObjectContext = context
        self.recordingService = recordingService
        
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
    
    /// Start recording
    func startRecording() async {
        do {
            // Check permission first
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
            journalEntry = nil
            
        } catch {
            handleError(error)
        }
    }
    
    /// Pause recording
    func pauseRecording() async {
        do {
            try await recordingService.pauseRecording()
            isPaused = true
        } catch {
            handleError(error)
        }
    }
    
    /// Resume recording
    func resumeRecording() async {
        do {
            try await recordingService.resumeRecording()
            isPaused = false
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
                
                // Create a journal entry with the recording
                await createJournalEntry(recordingURL: recordingURL)
            }
        } catch {
            handleError(error)
        }
    }
    
    /// Cancel recording
    func cancelRecording() async {
        do {
            _ = try await recordingService.stopRecording()
            await recordingService.deleteRecording()
            
            isRecording = false
            isPaused = false
            hasRecordingSaved = false
            journalEntry = nil
            
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
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func handleError(_ error: Error) {
        if let recordingError = error as? AudioRecordingError {
            errorMessage = recordingError.localizedDescription
        } else {
            errorMessage = "An error occurred: \(error.localizedDescription)"
        }
        
        showErrorAlert = true
        
        // Reset recording state if needed
        if isRecording {
            isRecording = false
            isPaused = false
        }
    }
    
    private func createJournalEntry(recordingURL: URL) async {
        // Create a new journal entry
        let entry = JournalEntry.create(in: managedObjectContext)
        entry.title = "Voice Journal - \(Date().formatted(date: .abbreviated, time: .shortened))"
        
        // Create audio recording
        let recording = entry.createAudioRecording(filePath: recordingURL.path)
        recording.duration = duration
        recording.fileSize = recordingService.fileSize ?? 0
        
        // Save the context
        do {
            try managedObjectContext.save()
            journalEntry = entry
            hasRecordingSaved = true
        } catch {
            handleError(error)
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
