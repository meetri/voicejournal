//
//  AudioRecordingViewModelTests.swift
//  voicejournalTests
//
//  Created on 4/28/25.
//

import XCTest
import CoreData
@testable import voicejournal

class AudioRecordingViewModelTests: XCTestCase {
    
    var viewModel: AudioRecordingViewModel!
    var mockRecordingService: MockAudioRecordingService!
    var mockSpeechRecognitionService: MockSpeechRecognitionService!
    var context: NSManagedObjectContext!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Set up in-memory Core Data stack for testing
        let persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        
        // Create mock services
        mockRecordingService = MockAudioRecordingService()
        mockSpeechRecognitionService = MockSpeechRecognitionService()
        
        // Create view model with mock services
        viewModel = AudioRecordingViewModel(
            context: context,
            recordingService: mockRecordingService,
            speechRecognitionService: mockSpeechRecognitionService
        )
    }
    
    override func tearDownWithError() throws {
        viewModel = nil
        mockRecordingService = nil
        mockSpeechRecognitionService = nil
        context = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Tests
    
    func testStartRecordingPreservesExistingJournalEntry() async {
        // Given
        let existingEntry = JournalEntry.create(in: context)
        existingEntry.title = "Custom Title"
        try? context.save()
        
        // Set the existing entry in the view model
        viewModel = AudioRecordingViewModel(
            context: context,
            recordingService: mockRecordingService,
            speechRecognitionService: mockSpeechRecognitionService,
            existingEntry: existingEntry
        )
        
        // When
        await viewModel.startRecording()
        
        // Then
        XCTAssertNotNil(viewModel.journalEntry, "Journal entry should be preserved after starting recording")
        XCTAssertEqual(viewModel.journalEntry?.title, "Custom Title", "Journal entry title should remain unchanged")
    }
    
    func testStopRecordingUsesExistingJournalEntry() async {
        // Given
        let existingEntry = JournalEntry.create(in: context)
        existingEntry.title = "Custom Title"
        try? context.save()
        
        // Set the existing entry in the view model
        viewModel = AudioRecordingViewModel(
            context: context,
            recordingService: mockRecordingService,
            speechRecognitionService: mockSpeechRecognitionService,
            existingEntry: existingEntry
        )
        
        // When
        await viewModel.startRecording()
        await viewModel.stopRecording()
        
        // Then
        XCTAssertNotNil(viewModel.journalEntry, "Journal entry should exist after stopping recording")
        XCTAssertEqual(viewModel.journalEntry?.title, "Custom Title", "Journal entry should maintain its original title")
        XCTAssertNotNil(viewModel.journalEntry?.audioRecording, "Journal entry should have an audio recording")
    }
    
    func testNoDoubleEntryCreation() async {
        // Given
        let existingEntry = JournalEntry.create(in: context)
        existingEntry.title = "Custom Title"
        try? context.save()
        
        let initialCount = try? context.count(for: JournalEntry.fetchRequest())
        
        // Set the existing entry in the view model
        viewModel = AudioRecordingViewModel(
            context: context,
            recordingService: mockRecordingService,
            speechRecognitionService: mockSpeechRecognitionService,
            existingEntry: existingEntry
        )
        
        // When
        await viewModel.startRecording()
        await viewModel.stopRecording()
        
        // Then
        let finalCount = try? context.count(for: JournalEntry.fetchRequest())
        XCTAssertEqual(initialCount, finalCount, "No new journal entries should be created")
    }
}

// MARK: - Mock Services

class MockAudioRecordingService: AudioRecordingService {
    override func startRecording() async throws {
        // Mock implementation
        self.audioLevel = 0.5
        self.duration = 10.0
    }
    
    override func stopRecording() async throws -> URL? {
        // Return a mock URL
        return URL(string: "file:///mock/recording.m4a")
    }
    
    override func pauseRecording() async throws {
        // Mock implementation
    }
    
    override func resumeRecording() async throws {
        // Mock implementation
    }
    
    override func deleteRecording() async {
        // Mock implementation
    }
    
    override var fileSize: Int64? {
        return 1024 * 1024 // 1MB
    }
}

class MockSpeechRecognitionService: SpeechRecognitionService {
    override func startLiveRecognition() async throws {
        // Mock implementation
        self.transcription = "Mock transcription"
    }
    
    override func stopRecognition() {
        // Mock implementation
    }
    
    override func pauseRecognition() {
        // Mock implementation
    }
    
    override func resumeRecognition() throws {
        // Mock implementation
    }
    
    override func recognizeFromFile(url: URL) async throws -> String {
        return "Mock file transcription"
    }
    
    override func getTimingDataJSON() -> String? {
        return "{\"segments\": []}"
    }
}
