//
//  AudioRecordingServiceTests.swift
//  voicejournalTests
//
//  Created on 4/27/25.
//

import XCTest
import AVFoundation
import Combine
@testable import voicejournal

// MARK: - Mocks

/// Mock AVAudioApplication for testing
class MockAVAudioApplication {
    @available(iOS, deprecated: 17.0, message: "Use AVAudioApplication.recordPermission instead")
    var recordPermission: AVAudioSession.RecordPermission = .undetermined
    var permissionGranted = true
    
    func requestRecordPermission(_ response: @escaping (Bool) -> Void) {
        response(permissionGranted)
    }
}

/// Mock AVAudioSession for testing
class MockAVAudioSession {
    var isActive: Bool = false
    var category: AVAudioSession.Category?
    var mode: AVAudioSession.Mode?
    var options: AVAudioSession.CategoryOptions?
    var permissionGranted = true
    var error: Error?
    
    func requestRecordPermission(_ response: @escaping (Bool) -> Void) {
        response(permissionGranted)
    }
    
    func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws {
        if let error = error {
            throw error
        }
        isActive = active
    }
    
    func setCategory(_ category: AVAudioSession.Category, mode: AVAudioSession.Mode, options: AVAudioSession.CategoryOptions) throws {
        if let error = error {
            throw error
        }
        self.category = category
        self.mode = mode
        self.options = options
    }
}

/// Mock AVAudioEngine for testing
class MockAVAudioEngine {
    var isRunning = false
    var isPrepared = false
    var error: Error?
    var inputNode = MockAVAudioInputNode()
    
    func prepare() {
        isPrepared = true
    }
    
    func start() throws {
        if let error = error {
            throw error
        }
        isRunning = true
    }
    
    func pause() {
        isRunning = false
    }
    
    func stop() {
        isRunning = false
        isPrepared = false
    }
}

/// Mock AVAudioInputNode for testing
class MockAVAudioInputNode {
    var tapInstalled = false
    var tapRemoved = false
    var outputFormat = MockAVAudioFormat()
    var lastBuffer: AVAudioPCMBuffer?
    var lastTime: AVAudioTime?
    var tapBlock: ((AVAudioPCMBuffer, AVAudioTime) -> Void)?
    
    func installTap(onBus bus: AVAudioNodeBus, bufferSize: AVAudioFrameCount, format: AVAudioFormat?, block: @escaping (AVAudioPCMBuffer, AVAudioTime) -> Void) {
        tapInstalled = true
        tapBlock = block
    }
    
    func removeTap(onBus bus: AVAudioNodeBus) {
        tapRemoved = true
    }
    
    func simulateAudioData(level: Float) {
        guard let tapBlock = tapBlock else { return }
        
        // Create a mock buffer with the specified level
        let buffer = createMockBuffer(withLevel: level)
        let time = AVAudioTime(sampleTime: 0, atRate: 44100)
        
        lastBuffer = buffer
        lastTime = time
        
        tapBlock(buffer, time)
    }
    
    private func createMockBuffer(withLevel level: Float) -> AVAudioPCMBuffer {
        // Create a mock PCM buffer with the specified level
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        buffer.frameLength = 1024
        
        // Fill buffer with values that will result in the desired level
        if let channelData = buffer.floatChannelData {
            for channel in 0..<Int(format.channelCount) {
                for frame in 0..<Int(buffer.frameLength) {
                    channelData[channel][frame] = level
                }
            }
        }
        
        return buffer
    }
}

/// Mock AVAudioFormat for testing
class MockAVAudioFormat: AVAudioFormat {
    override var sampleRate: Double {
        return 44100
    }
    
    override var channelCount: AVAudioChannelCount {
        return 2
    }
}

/// Mock AVAudioFile for testing
class MockAVAudioFile {
    var url: URL
    var writeCount = 0
    var error: Error?
    
    init(url: URL) {
        self.url = url
    }
    
    func write(from buffer: AVAudioPCMBuffer) throws {
        if let error = error {
            throw error
        }
        writeCount += 1
    }
}

/// Test implementation of AudioRecordingService that uses mocks
@MainActor
class TestableAudioRecordingService: AudioRecordingService {
    // Public properties for testing
    var mockAudioApplication = MockAVAudioApplication()
    var mockAudioSession = MockAVAudioSession()
    var mockAudioEngine = MockAVAudioEngine()
    var mockAudioFile: MockAVAudioFile?
    
    // Public properties to track internal state
    var enginePrepared = false
    var engineStarted = false
    var engineStopped = false
    var tapInstalled = false
    var tapRemoved = false
    
    // Override methods to use our mocks
    override func requestPermission() async -> Bool {
        return mockAudioApplication.permissionGranted
    }
    
    override func checkPermission() async -> RecordingPermission {
        // Convert the deprecated AVAudioSession.RecordPermission to our custom RecordingPermission
        switch mockAudioApplication.recordPermission {
        case .granted:
            return .granted
        case .denied:
            return .denied
        case .undetermined:
            return .undetermined
        @unknown default:
            return .undetermined
        }
    }
    
    // Override startRecording to use our mocks
    override func startRecording() async throws {
        // Check if already recording
        guard state != .recording else {
            throw AudioRecordingError.recordingInProgress
        }
        
        // Check permission
        let permission = await checkPermission()
        guard permission == .granted else {
            throw AudioRecordingError.permissionDenied
        }
        
        // Set up audio session
        do {
            try mockAudioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try mockAudioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw AudioRecordingError.audioSessionSetupFailed
        }
        
        // Set up audio engine
        mockAudioEngine.prepare()
        enginePrepared = true
        
        do {
            try mockAudioEngine.start()
            engineStarted = true
        } catch {
            throw AudioRecordingError.audioEngineSetupFailed
        }
        
        // Create recording file
        let filename = "recording_\(Date().timeIntervalSince1970).m4a"
        let fileURL = recordingsDirectory.appendingPathComponent(filename)
        
        // Set recording URL using the testing method
        self.setRecordingURLForTesting(fileURL)
        
        // Install tap
        tapInstalled = true
        mockAudioEngine.inputNode.tapInstalled = true
        
        // Update state using the testing method
        setStateForTesting(.recording)
    }
    
    // Override pauseRecording to use our mocks
    override func pauseRecording() async throws {
        guard state == .recording else {
            throw AudioRecordingError.noRecordingInProgress
        }
        
        // Pause engine
        mockAudioEngine.pause()
        
        // Update state using the testing method
        setStateForTesting(.paused)
    }
    
    // Override resumeRecording to use our mocks
    override func resumeRecording() async throws {
        guard state == .paused else {
            throw AudioRecordingError.noRecordingInProgress
        }
        
        // Start engine
        do {
            try mockAudioEngine.start()
        } catch {
            throw AudioRecordingError.audioEngineSetupFailed
        }
        
        // Update state using the testing method
        setStateForTesting(.recording)
    }
    
    // Override stopRecording to use our mocks
    override func stopRecording() async throws -> URL? {
        guard state == .recording || state == .paused else {
            throw AudioRecordingError.noRecordingInProgress
        }
        
        // Stop engine
        mockAudioEngine.stop()
        engineStopped = true
        
        // Remove tap
        mockAudioEngine.inputNode.tapRemoved = true
        tapRemoved = true
        
        // Get URL
        let url = recordingURL
        
        // Update state using the testing method
        setStateForTesting(.stopped)
        
        return url
    }
    
    // Helper method to simulate audio input
    func simulateAudioInput(level: Float) {
        mockAudioEngine.inputNode.simulateAudioData(level: level)
        
        // Update audio level using the testing method
        setAudioLevelForTesting(level)
    }
    
    // Helper method to set duration directly for testing
    func setDuration(_ newDuration: TimeInterval) {
        setDurationForTesting(newDuration)
    }
}

// MARK: - Tests

@MainActor
final class AudioRecordingServiceTests: XCTestCase {
    var recordingService: TestableAudioRecordingService!
    var tempDirectory: URL!
    
    @MainActor
    override func setUpWithError() throws {
        // Create a temporary directory for test recordings
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // Initialize the recording service
        recordingService = TestableAudioRecordingService()
    }
    
    @MainActor
    override func tearDownWithError() throws {
        // Clean up temporary directory
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try FileManager.default.removeItem(at: tempDirectory)
        }
        
        recordingService = nil
    }
    
    // MARK: - Permission Tests
    
    @MainActor
    func testRequestPermission() async {
        // Test permission granted
        recordingService.mockAudioApplication.permissionGranted = true
        let granted = await recordingService.requestPermission()
        XCTAssertTrue(granted, "Permission should be granted")
        
        // Test permission denied
        recordingService.mockAudioApplication.permissionGranted = false
        let denied = await recordingService.requestPermission()
        XCTAssertFalse(denied, "Permission should be denied")
    }
    
    @MainActor
    func testCheckPermission() async {
        // Test undetermined permission
        recordingService.mockAudioApplication.recordPermission = .undetermined
        let undetermined = await recordingService.checkPermission()
        XCTAssertEqual(undetermined, .undetermined, "Permission should be undetermined")
        
        // Test denied permission
        recordingService.mockAudioApplication.recordPermission = .denied
        let denied = await recordingService.checkPermission()
        XCTAssertEqual(denied, .denied, "Permission should be denied")
        
        // Test granted permission
        recordingService.mockAudioApplication.recordPermission = .granted
        let granted = await recordingService.checkPermission()
        XCTAssertEqual(granted, .granted, "Permission should be granted")
    }
    
    // MARK: - Recording Lifecycle Tests
    
    @MainActor
    func testStartRecording() async throws {
        // Set up permission
        recordingService.mockAudioApplication.recordPermission = .granted
        
        // Start recording
        try await recordingService.startRecording()
        
        // Verify audio session setup
        XCTAssertEqual(recordingService.mockAudioSession.category, .playAndRecord, "Audio session category should be playAndRecord")
        XCTAssertEqual(recordingService.mockAudioSession.mode, .default, "Audio session mode should be default")
        XCTAssertEqual(recordingService.mockAudioSession.options, [.defaultToSpeaker, .allowBluetooth], "Audio session options should be set correctly")
        XCTAssertTrue(recordingService.mockAudioSession.isActive, "Audio session should be active")
        
        // Verify audio engine setup
        XCTAssertTrue(recordingService.mockAudioEngine.isPrepared, "Audio engine should be prepared")
        XCTAssertTrue(recordingService.mockAudioEngine.isRunning, "Audio engine should be running")
        XCTAssertTrue(recordingService.mockAudioEngine.inputNode.tapInstalled, "Input node tap should be installed")
        
        // Verify recording state
        XCTAssertEqual(recordingService.state, .recording, "Recording state should be .recording")
        XCTAssertNotNil(recordingService.recordingURL, "Recording URL should be set")
    }
    
    @MainActor
    func testInitialAudioLevelOnStartRecording() async throws {
        // Set up permission
        recordingService.mockAudioApplication.recordPermission = .granted
        
        // Set initial audio level to 0
        recordingService.setAudioLevelForTesting(0.0)
        XCTAssertEqual(recordingService.audioLevel, 0.0, "Initial audio level should be 0")
        
        // Start recording
        try await recordingService.startRecording()
        
        // Verify that audio level is initialized to a minimum value
        XCTAssertGreaterThanOrEqual(recordingService.audioLevel, 0.05, "Audio level should be initialized to at least 0.05")
    }
    
    @MainActor
    func testStartRecordingWithPermissionDenied() async {
        // Set up denied permission
        recordingService.mockAudioApplication.recordPermission = .denied
        
        // Attempt to start recording
        do {
            try await recordingService.startRecording()
            XCTFail("Starting recording should fail with permission denied")
        } catch let error as AudioRecordingError {
            XCTAssertEqual(error, AudioRecordingError.permissionDenied, "Error should be permissionDenied")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    @MainActor
    func testStartRecordingWithAudioSessionError() async {
        // Set up permission
        recordingService.mockAudioApplication.recordPermission = .granted
        
        // Set up audio session error
        let testError = NSError(domain: "test", code: 1, userInfo: nil)
        recordingService.mockAudioSession.error = testError
        
        // Attempt to start recording
        do {
            try await recordingService.startRecording()
            XCTFail("Starting recording should fail with audio session error")
        } catch let error as AudioRecordingError {
            XCTAssertEqual(error, AudioRecordingError.audioSessionSetupFailed, "Error should be audioSessionSetupFailed")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    @MainActor
    func testStartRecordingWithAudioEngineError() async {
        // Set up permission
        recordingService.mockAudioApplication.recordPermission = .granted
        
        // Set up audio engine error
        let testError = NSError(domain: "test", code: 1, userInfo: nil)
        recordingService.mockAudioEngine.error = testError
        
        // Attempt to start recording
        do {
            try await recordingService.startRecording()
            XCTFail("Starting recording should fail with audio engine error")
        } catch let error as AudioRecordingError {
            XCTAssertEqual(error, AudioRecordingError.audioEngineSetupFailed, "Error should be audioEngineSetupFailed")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    @MainActor
    func testPauseRecording() async throws {
        // Start recording first
        recordingService.mockAudioApplication.recordPermission = .granted
        try await recordingService.startRecording()
        
        // Pause recording
        try await recordingService.pauseRecording()
        
        // Verify audio engine state
        XCTAssertFalse(recordingService.mockAudioEngine.isRunning, "Audio engine should be paused")
        
        // Verify recording state
        XCTAssertEqual(recordingService.state, .paused, "Recording state should be .paused")
    }
    
    @MainActor
    func testPauseRecordingWithoutStarting() async {
        // Attempt to pause without starting
        do {
            try await recordingService.pauseRecording()
            XCTFail("Pausing recording should fail when not recording")
        } catch let error as AudioRecordingError {
            XCTAssertEqual(error, AudioRecordingError.noRecordingInProgress, "Error should be noRecordingInProgress")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    @MainActor
    func testResumeRecording() async throws {
        // Start and pause recording first
        recordingService.mockAudioApplication.recordPermission = .granted
        try await recordingService.startRecording()
        try await recordingService.pauseRecording()
        
        // Resume recording
        try await recordingService.resumeRecording()
        
        // Verify audio engine state
        XCTAssertTrue(recordingService.mockAudioEngine.isRunning, "Audio engine should be running")
        
        // Verify recording state
        XCTAssertEqual(recordingService.state, .recording, "Recording state should be .recording")
    }
    
    @MainActor
    func testResumeRecordingWithoutPausing() async {
        // Attempt to resume without pausing
        do {
            try await recordingService.resumeRecording()
            XCTFail("Resuming recording should fail when not paused")
        } catch let error as AudioRecordingError {
            XCTAssertEqual(error, AudioRecordingError.noRecordingInProgress, "Error should be noRecordingInProgress")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    @MainActor
    func testStopRecording() async throws {
        // Start recording first
        recordingService.mockAudioApplication.recordPermission = .granted
        try await recordingService.startRecording()
        
        // Store the URL for later verification
        let recordingURL = recordingService.recordingURL
        
        // Stop recording
        let returnedURL = try await recordingService.stopRecording()
        
        // Verify audio engine state
        XCTAssertFalse(recordingService.mockAudioEngine.isRunning, "Audio engine should be stopped")
        XCTAssertTrue(recordingService.mockAudioEngine.inputNode.tapRemoved, "Input node tap should be removed")
        
        // Verify recording state
        XCTAssertEqual(recordingService.state, .stopped, "Recording state should be .stopped")
        XCTAssertEqual(returnedURL, recordingURL, "Returned URL should match the recording URL")
    }
    
    @MainActor
    func testStopRecordingFromPausedState() async throws {
        // Start and pause recording first
        recordingService.mockAudioApplication.recordPermission = .granted
        try await recordingService.startRecording()
        try await recordingService.pauseRecording()
        
        // Store the URL for later verification
        let recordingURL = recordingService.recordingURL
        
        // Stop recording
        let returnedURL = try await recordingService.stopRecording()
        
        // Verify audio engine state
        XCTAssertFalse(recordingService.mockAudioEngine.isRunning, "Audio engine should be stopped")
        
        // Verify recording state
        XCTAssertEqual(recordingService.state, .stopped, "Recording state should be .stopped")
        XCTAssertEqual(returnedURL, recordingURL, "Returned URL should match the recording URL")
    }
    
    @MainActor
    func testStopRecordingWithoutStarting() async {
        // Attempt to stop without starting
        do {
            _ = try await recordingService.stopRecording()
            XCTFail("Stopping recording should fail when not recording")
        } catch let error as AudioRecordingError {
            XCTAssertEqual(error, AudioRecordingError.noRecordingInProgress, "Error should be noRecordingInProgress")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Audio Level Tests
    
    @MainActor
    func testAudioLevelCalculation() async throws {
        // Start recording
        recordingService.mockAudioApplication.recordPermission = .granted
        try await recordingService.startRecording()
        
        // Initial audio level should be 0
        XCTAssertEqual(recordingService.audioLevel, 0.0, "Initial audio level should be 0")
        
        // Simulate audio input with low level
        await recordingService.simulateAudioInput(level: 0.1)
        
        // Audio level should be updated
        XCTAssertEqual(recordingService.audioLevel, 0.1, "Audio level should be updated after input")
        
        // Simulate audio input with high level
        await recordingService.simulateAudioInput(level: 0.8)
        
        // Audio level should be higher
        XCTAssertEqual(recordingService.audioLevel, 0.8, "Audio level should be higher with stronger input")
    }
    
    // MARK: - File Management Tests
    
    @MainActor
    func testDeleteRecording() async throws {
        // Start and stop recording to create a file
        recordingService.mockAudioApplication.recordPermission = .granted
        try await recordingService.startRecording()
        let recordingURL = recordingService.recordingURL!
        _ = try await recordingService.stopRecording()
        
        // Create a dummy file at the recording URL
        FileManager.default.createFile(atPath: recordingURL.path, contents: Data("test".utf8))
        
        // Verify file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: recordingURL.path), "Recording file should exist")
        
        // Delete the recording
        await recordingService.deleteRecording()
        
        // Verify file is deleted
        XCTAssertFalse(FileManager.default.fileExists(atPath: recordingURL.path), "Recording file should be deleted")
        XCTAssertNil(recordingService.recordingURL, "Recording URL should be nil after deletion")
    }
    
    // MARK: - Utility Tests
    
    @MainActor
    func testFormattedDuration() async {
        // Set duration
        recordingService.setDuration(65.5) // 1 minute, 5.5 seconds
        
        // Check formatted duration
        XCTAssertEqual(recordingService.formattedDuration, "01:05", "Formatted duration should be correct")
        
        // Set different duration
        recordingService.setDuration(3725.0) // 1 hour, 2 minutes, 5 seconds
        
        // Check formatted duration (should still be MM:SS format)
        XCTAssertEqual(recordingService.formattedDuration, "62:05", "Formatted duration should be correct")
    }
    
    @MainActor
    func testFileSize() async throws {
        // Start recording
        recordingService.mockAudioApplication.recordPermission = .granted
        try await recordingService.startRecording()
        let recordingURL = recordingService.recordingURL!
        
        // Create a dummy file with known size
        let testData = Data(repeating: 0, count: 1024 * 1024) // 1MB
        try testData.write(to: recordingURL)
        
        // Check file size
        XCTAssertEqual(recordingService.fileSize, 1024 * 1024, "File size should be correct")
        
        // Check formatted file size
        XCTAssertEqual(recordingService.formattedFileSize, "1 MB", "Formatted file size should be correct")
    }
}
