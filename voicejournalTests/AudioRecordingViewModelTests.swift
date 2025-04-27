//
//  AudioRecordingViewModelTests.swift
//  voicejournalTests
//
//  Created on 4/27/25.
//

import XCTest
import CoreData
import Combine
import AVFoundation
@testable import voicejournal

// MARK: - Mocks

/// Mock AudioRecordingService for testing the ViewModel
class MockAudioRecordingService: AudioRecordingService {
    var mockState: RecordingState = .ready
    var mockAudioLevel: Float = 0.0
    var mockDuration: TimeInterval = 0.0
    var mockRecordingURL: URL?
    var mockFileSize: Int64 = 0
    
    var startRecordingCalled = false
    var pauseRecordingCalled = false
    var resumeRecordingCalled = false
    var stopRecordingCalled = false
    var deleteRecordingCalled = false
    
    var shouldThrowError = false
    var errorToThrow: AudioRecordingError = .unknown(NSError(domain: "test", code: 1, userInfo: nil))
    
    // Use our custom RecordingPermission enum
    var permissionToReturn = RecordingPermission.granted
    var permissionGrantedToReturn = true
    
    // Override published properties
    override var state: RecordingState {
        get { return mockState }
        set { }
    }
    
    override var audioLevel: Float {
        get { return mockAudioLevel }
        set { }
    }
    
    override var duration: TimeInterval {
        get { return mockDuration }
        set { }
    }
    
    override var recordingURL: URL? {
        get { return mockRecordingURL }
        set { }
    }
    
    // We can't override fileSize since it's in an extension
    // Instead, we'll provide our own implementation
    var mockFileSizeValue: Int64? {
        return mockFileSize
    }
    
    // Override methods
    override func requestPermission() async -> Bool {
        return permissionGrantedToReturn
    }
    
    // Updated to use our custom RecordingPermission enum
    override func checkPermission() async -> RecordingPermission {
        return permissionToReturn
    }
    
    override func startRecording() async throws {
        startRecordingCalled = true
        if shouldThrowError {
            throw errorToThrow
        }
        mockState = .recording
    }
    
    override func pauseRecording() async throws {
        pauseRecordingCalled = true
        if shouldThrowError {
            throw errorToThrow
        }
        mockState = .paused
    }
    
    override func resumeRecording() async throws {
        resumeRecordingCalled = true
        if shouldThrowError {
            throw errorToThrow
        }
        mockState = .recording
    }
    
    override func stopRecording() async throws -> URL? {
        stopRecordingCalled = true
        if shouldThrowError {
            throw errorToThrow
        }
        mockState = .stopped
        return mockRecordingURL
    }
    
    override func deleteRecording() async {
        deleteRecordingCalled = true
        mockRecordingURL = nil
    }
    
    // Helper methods for testing
    func simulateAudioLevelChange(to level: Float) {
        mockAudioLevel = level
    }
    
    func simulateDurationChange(to duration: TimeInterval) {
        mockDuration = duration
    }
}

// MARK: - Tests

@MainActor
final class AudioRecordingViewModelTests: XCTestCase {
    var viewModel: AudioRecordingViewModel!
    var mockService: MockAudioRecordingService!
    var container: NSPersistentContainer!
    var context: NSManagedObjectContext!
    var cancellables = Set<AnyCancellable>()
    
    @MainActor
    override func setUpWithError() throws {
        // Set up an in-memory Core Data stack for testing
        container = NSPersistentContainer(name: "voicejournal")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { (description, error) in
            if let error = error {
                fatalError("Failed to load in-memory Core Data stack: \(error)")
            }
        }
        
        context = container.viewContext
        
        // Create mock service
        mockService = MockAudioRecordingService()
        
        // Create view model with mock service directly injected
        viewModel = AudioRecordingViewModel(context: context, recordingService: mockService)
    }
    
    @MainActor
    override func tearDownWithError() throws {
        cancellables.removeAll()
        viewModel = nil
        mockService = nil
        context = nil
        container = nil
    }
    
    
    // MARK: - Permission Tests
    
    @MainActor
    func testRequestMicrophonePermission() async {
        // Test permission granted
        mockService.permissionGrantedToReturn = true
        await viewModel.requestMicrophonePermission()
        XCTAssertFalse(viewModel.showPermissionDeniedAlert, "Permission alert should not be shown when permission is granted")
        
        // Test permission denied
        mockService.permissionGrantedToReturn = false
        await viewModel.requestMicrophonePermission()
        XCTAssertTrue(viewModel.showPermissionDeniedAlert, "Permission alert should be shown when permission is denied")
    }
    
    @MainActor
    func testCheckMicrophonePermission() async {
        // Test granted permission
        mockService.permissionToReturn = RecordingPermission.granted
        let granted = await viewModel.checkMicrophonePermission()
        XCTAssertTrue(granted, "Should return true for granted permission")
        
        // Test denied permission
        mockService.permissionToReturn = RecordingPermission.denied
        let denied = await viewModel.checkMicrophonePermission()
        XCTAssertFalse(denied, "Should return false for denied permission")
        
        // Test undetermined permission
        mockService.permissionToReturn = RecordingPermission.undetermined
        let undetermined = await viewModel.checkMicrophonePermission()
        XCTAssertFalse(undetermined, "Should return false for undetermined permission")
    }
    
    // MARK: - Recording Lifecycle Tests
    
    @MainActor
    func testStartRecording() async {
        // Test successful start
        await viewModel.startRecording()
        
        XCTAssertTrue(mockService.startRecordingCalled, "startRecording should be called on the service")
        XCTAssertTrue(viewModel.isRecording, "isRecording should be true")
        XCTAssertFalse(viewModel.isPaused, "isPaused should be false")
        XCTAssertFalse(viewModel.hasRecordingSaved, "hasRecordingSaved should be false")
        XCTAssertNil(viewModel.journalEntry, "journalEntry should be nil")
    }
    
    @MainActor
    func testStartRecordingWithPermissionDenied() async {
        // Set up permission denied
        mockService.permissionToReturn = RecordingPermission.denied
        
        // Start recording
        await viewModel.startRecording()
        
        // Should request permission
        XCTAssertFalse(mockService.startRecordingCalled, "startRecording should not be called when permission is denied")
        XCTAssertFalse(viewModel.isRecording, "isRecording should be false")
    }
    
    @MainActor
    func testStartRecordingWithError() async {
        // Set up error
        mockService.shouldThrowError = true
        mockService.errorToThrow = .audioEngineSetupFailed
        
        // Start recording
        await viewModel.startRecording()
        
        // Should show error
        XCTAssertTrue(mockService.startRecordingCalled, "startRecording should be called")
        XCTAssertFalse(viewModel.isRecording, "isRecording should be false")
        XCTAssertTrue(viewModel.showErrorAlert, "Error alert should be shown")
        XCTAssertEqual(viewModel.errorMessage, "Failed to set up audio engine", "Error message should be set")
    }
    
    @MainActor
    func testPauseRecording() async {
        // Set up recording state
        mockService.mockState = .recording
        await viewModel.startRecording()
        
        // Pause recording
        await viewModel.pauseRecording()
        
        XCTAssertTrue(mockService.pauseRecordingCalled, "pauseRecording should be called on the service")
        XCTAssertTrue(viewModel.isPaused, "isPaused should be true")
    }
    
    @MainActor
    func testPauseRecordingWithError() async {
        // Set up recording state and error
        mockService.mockState = .recording
        await viewModel.startRecording()
        mockService.shouldThrowError = true
        mockService.errorToThrow = .noRecordingInProgress
        
        // Pause recording
        await viewModel.pauseRecording()
        
        // Should show error
        XCTAssertTrue(mockService.pauseRecordingCalled, "pauseRecording should be called")
        XCTAssertFalse(viewModel.isPaused, "isPaused should be false")
        XCTAssertTrue(viewModel.showErrorAlert, "Error alert should be shown")
        XCTAssertEqual(viewModel.errorMessage, "No recording is in progress", "Error message should be set")
    }
    
    @MainActor
    func testResumeRecording() async {
        // Set up paused state
        mockService.mockState = .paused
        await viewModel.startRecording()
        await viewModel.pauseRecording()
        mockService.pauseRecordingCalled = false // Reset for testing
        
        // Resume recording
        await viewModel.resumeRecording()
        
        XCTAssertTrue(mockService.resumeRecordingCalled, "resumeRecording should be called on the service")
        XCTAssertFalse(viewModel.isPaused, "isPaused should be false")
    }
    
    @MainActor
    func testResumeRecordingWithError() async {
        // Set up paused state and error
        mockService.mockState = .paused
        await viewModel.startRecording()
        await viewModel.pauseRecording()
        mockService.shouldThrowError = true
        mockService.errorToThrow = .audioEngineSetupFailed
        
        // Resume recording
        await viewModel.resumeRecording()
        
        // Should show error
        XCTAssertTrue(mockService.resumeRecordingCalled, "resumeRecording should be called")
        XCTAssertTrue(viewModel.isPaused, "isPaused should still be true")
        XCTAssertTrue(viewModel.showErrorAlert, "Error alert should be shown")
        XCTAssertEqual(viewModel.errorMessage, "Failed to set up audio engine", "Error message should be set")
    }
    
    @MainActor
    func testStopRecording() async {
        // Set up recording state
        mockService.mockState = .recording
        mockService.mockRecordingURL = URL(string: "file:///test/recording.m4a")
        mockService.mockDuration = 120.5
        mockService.mockFileSize = 1024 * 1024
        await viewModel.startRecording()
        
        // Stop recording
        await viewModel.stopRecording()
        
        XCTAssertTrue(mockService.stopRecordingCalled, "stopRecording should be called on the service")
        XCTAssertFalse(viewModel.isRecording, "isRecording should be false")
        XCTAssertFalse(viewModel.isPaused, "isPaused should be false")
        XCTAssertTrue(viewModel.hasRecordingSaved, "hasRecordingSaved should be true")
        XCTAssertNotNil(viewModel.journalEntry, "journalEntry should be created")
        
        // Verify journal entry
        let entry = viewModel.journalEntry
        XCTAssertNotNil(entry?.audioRecording, "Audio recording should be created")
        XCTAssertEqual(entry?.audioRecording?.filePath, "file:///test/recording.m4a", "File path should be set")
        XCTAssertEqual(entry?.audioRecording?.duration, 120.5, "Duration should be set")
        XCTAssertEqual(entry?.audioRecording?.fileSize, 1024 * 1024, "File size should be set")
    }
    
    @MainActor
    func testStopRecordingWithError() async {
        // Set up recording state and error
        mockService.mockState = .recording
        await viewModel.startRecording()
        mockService.shouldThrowError = true
        mockService.errorToThrow = .audioEngineSetupFailed
        
        // Stop recording
        await viewModel.stopRecording()
        
        // Should show error
        XCTAssertTrue(mockService.stopRecordingCalled, "stopRecording should be called")
        XCTAssertFalse(viewModel.isRecording, "isRecording should be false")
        XCTAssertFalse(viewModel.isPaused, "isPaused should be false")
        XCTAssertFalse(viewModel.hasRecordingSaved, "hasRecordingSaved should be false")
        XCTAssertNil(viewModel.journalEntry, "journalEntry should be nil")
        XCTAssertTrue(viewModel.showErrorAlert, "Error alert should be shown")
        XCTAssertEqual(viewModel.errorMessage, "Failed to set up audio engine", "Error message should be set")
    }
    
    @MainActor
    func testCancelRecording() async {
        // Set up recording state
        mockService.mockState = .recording
        mockService.mockRecordingURL = URL(string: "file:///test/recording.m4a")
        await viewModel.startRecording()
        
        // Cancel recording
        await viewModel.cancelRecording()
        
        XCTAssertTrue(mockService.stopRecordingCalled, "stopRecording should be called on the service")
        XCTAssertTrue(mockService.deleteRecordingCalled, "deleteRecording should be called on the service")
        XCTAssertFalse(viewModel.isRecording, "isRecording should be false")
        XCTAssertFalse(viewModel.isPaused, "isPaused should be false")
        XCTAssertFalse(viewModel.hasRecordingSaved, "hasRecordingSaved should be false")
        XCTAssertNil(viewModel.journalEntry, "journalEntry should be nil")
    }
    
    @MainActor
    func testCancelRecordingWithError() async {
        // Set up recording state and error
        mockService.mockState = .recording
        await viewModel.startRecording()
        mockService.shouldThrowError = true
        mockService.errorToThrow = .audioEngineSetupFailed
        
        // Cancel recording
        await viewModel.cancelRecording()
        
        // Should show error
        XCTAssertTrue(mockService.stopRecordingCalled, "stopRecording should be called")
        XCTAssertFalse(mockService.deleteRecordingCalled, "deleteRecording should not be called when stop fails")
        XCTAssertFalse(viewModel.isRecording, "isRecording should be false")
        XCTAssertFalse(viewModel.isPaused, "isPaused should be false")
        XCTAssertTrue(viewModel.showErrorAlert, "Error alert should be shown")
        XCTAssertEqual(viewModel.errorMessage, "Failed to set up audio engine", "Error message should be set")
    }
    
    @MainActor
    func testReset() async {
        // Set up some state
        mockService.mockState = .recording
        await viewModel.startRecording()
        mockService.mockAudioLevel = 0.5
        mockService.mockDuration = 60.0
        viewModel.errorMessage = "Test error"
        viewModel.showErrorAlert = true
        
        // Reset
        viewModel.reset()
        
        // Verify all state is reset
        XCTAssertFalse(viewModel.isRecording, "isRecording should be false")
        XCTAssertFalse(viewModel.isPaused, "isPaused should be false")
        XCTAssertEqual(viewModel.audioLevel, 0.0, "audioLevel should be reset to 0")
        XCTAssertEqual(viewModel.duration, 0.0, "duration should be reset to 0")
        XCTAssertEqual(viewModel.formattedDuration, "00:00", "formattedDuration should be reset")
        XCTAssertNil(viewModel.errorMessage, "errorMessage should be nil")
        XCTAssertFalse(viewModel.showErrorAlert, "showErrorAlert should be false")
        XCTAssertFalse(viewModel.hasRecordingSaved, "hasRecordingSaved should be false")
        XCTAssertNil(viewModel.journalEntry, "journalEntry should be nil")
    }
    
    // MARK: - UI Property Tests
    
    @MainActor
    func testAudioLevelBinding() {  
        // Set up expectations
        let expectation = XCTestExpectation(description: "Audio level should be updated")
        
        // Subscribe to audioLevel changes
        viewModel.$audioLevel
            .dropFirst() // Skip initial value
            .sink { level in
                XCTAssertEqual(level, 0.75, "Audio level should be updated to 0.75")
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Change audio level in service
        mockService.simulateAudioLevelChange(to: 0.75)
        
        // Wait for expectation
        wait(for: [expectation], timeout: 1.0)
    }
    
    @MainActor
    func testDurationBinding() {
        // Set up expectations
        let expectation = XCTestExpectation(description: "Duration should be updated")
        
        // Subscribe to duration changes
        viewModel.$duration
            .dropFirst() // Skip initial value
            .sink { duration in
                XCTAssertEqual(duration, 120.5, "Duration should be updated to 120.5")
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Change duration in service
        mockService.simulateDurationChange(to: 120.5)
        
        // Wait for expectation
        wait(for: [expectation], timeout: 1.0)
    }
    
    @MainActor
    func testFormattedDuration() {
        // Set duration
        mockService.mockDuration = 65.5 // 1 minute, 5.5 seconds
        mockService.simulateDurationChange(to: 65.5)
        
        // Wait a bit for the binding to update
        let expectation = XCTestExpectation(description: "Formatted duration should be updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(self.viewModel.formattedDuration, "01:05", "Formatted duration should be correct")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    @MainActor
    func testVisualizationLevel() {
        // Set audio level
        mockService.mockAudioLevel = 0.75
        mockService.simulateAudioLevelChange(to: 0.75)
        
        // Wait a bit for the binding to update
        let expectation = XCTestExpectation(description: "Visualization level should be updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(self.viewModel.visualizationLevel, 0.75, "Visualization level should match audio level")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Error Handling Tests
    
    @MainActor
    func testErrorHandling() async {
        // Set up error
        mockService.shouldThrowError = true
        mockService.errorToThrow = .audioSessionSetupFailed
        
        // Trigger error
        await viewModel.pauseRecording()
        
        // Verify error handling
        XCTAssertEqual(viewModel.errorMessage, "Failed to set up audio session", "Error message should be set")
        XCTAssertTrue(viewModel.showErrorAlert, "Error alert should be shown")
    }
    
    @MainActor
    func testErrorResetting() {
        // Set up error
        viewModel.errorMessage = "Test error"
        viewModel.showErrorAlert = true
        
        // Reset error by dismissing alert
        viewModel.showErrorAlert = false
        
        // Error message should still be present
        XCTAssertEqual(viewModel.errorMessage, "Test error", "Error message should remain after dismissing alert")
        
        // Reset view model
        viewModel.reset()
        
        // Error should be cleared
        XCTAssertNil(viewModel.errorMessage, "Error message should be nil after reset")
        XCTAssertFalse(viewModel.showErrorAlert, "Error alert should be hidden after reset")
    }
    
    // MARK: - Binding Tests
    
    @MainActor
    func testHasRecordingSavedBinding() async {
        // Set up recording state and URL to simulate a successful recording
        mockService.mockState = .recording
        mockService.mockRecordingURL = URL(string: "file:///test/recording.m4a")
        
        // Start and stop recording to trigger hasRecordingSaved = true
        await viewModel.startRecording()
        await viewModel.stopRecording()
        
        // Verify hasRecordingSaved is true
        XCTAssertTrue(viewModel.hasRecordingSaved, "hasRecordingSaved should be true after stopping recording")
        
        // Get binding
        let binding = viewModel.hasRecordingSavedBinding
        
        // Check binding value
        XCTAssertTrue(binding.wrappedValue, "Binding value should be true")
        
        // Set binding to false (simulating sheet dismissal)
        binding.wrappedValue = false
        
        // Check that hasRecordingSaved was updated
        XCTAssertFalse(viewModel.hasRecordingSaved, "hasRecordingSaved should be false after setting binding")
        
        // Try to set binding to true (should not work)
        binding.wrappedValue = true
        
        // Check that hasRecordingSaved was not updated
        XCTAssertFalse(viewModel.hasRecordingSaved, "hasRecordingSaved should still be false after trying to set binding to true")
    }
}
