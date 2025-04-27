//
//  AudioPlaybackViewModelTests.swift
//  voicejournalTests
//
//  Created on 4/27/25.
//

import XCTest
import Combine
@testable import voicejournal

@MainActor
final class AudioPlaybackViewModelTests: XCTestCase {
    
    var viewModel: AudioPlaybackViewModel!
    var playbackService: AudioPlaybackService!
    var cancellables: Set<AnyCancellable>!
    var testAudioURL: URL!
    
    override func setUpWithError() throws {
        playbackService = AudioPlaybackService()
        viewModel = AudioPlaybackViewModel(playbackService: playbackService)
        cancellables = Set<AnyCancellable>()
        
        // Create a temporary directory for test files
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AudioPlaybackViewModelTests", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: tempDirectory, 
                                               withIntermediateDirectories: true)
        
        // Create a test audio file path
        testAudioURL = tempDirectory.appendingPathComponent("test_audio.m4a")
        
        // Create a simple test audio file if it doesn't exist
        if !FileManager.default.fileExists(atPath: testAudioURL.path) {
            createTestAudioFile()
        }
    }
    
    override func tearDownWithError() throws {
        viewModel = nil
        playbackService = nil
        cancellables = nil
        
        // Clean up test files
        try? FileManager.default.removeItem(at: testAudioURL)
    }
    
    // MARK: - Tests
    
    func testInitialState() {
        XCTAssertFalse(viewModel.isPlaying)
        XCTAssertFalse(viewModel.isPaused)
        XCTAssertEqual(viewModel.currentTime, 0.0)
        XCTAssertEqual(viewModel.duration, 0.0)
        XCTAssertEqual(viewModel.formattedCurrentTime, "00:00")
        XCTAssertEqual(viewModel.formattedDuration, "00:00")
        XCTAssertEqual(viewModel.audioLevel, 0.0)
        XCTAssertEqual(viewModel.progress, 0.0)
        XCTAssertEqual(viewModel.rate, 1.0)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.showErrorAlert)
        XCTAssertFalse(viewModel.isAudioLoaded)
    }
    
    func testLoadAudio() async {
        // Skip test if file doesn't exist
        guard FileManager.default.fileExists(atPath: testAudioURL.path) else {
            XCTFail("Test audio file does not exist")
            return
        }
        
        // Load audio file
        await viewModel.loadAudio(from: testAudioURL)
        
        // Verify state
        XCTAssertTrue(viewModel.isAudioLoaded)
        XCTAssertFalse(viewModel.isPlaying)
        XCTAssertFalse(viewModel.isPaused)
        XCTAssertGreaterThan(viewModel.duration, 0.0)
    }
    
    func testLoadAudioWithInvalidFile() async {
        // Create an invalid file URL
        let invalidURL = URL(fileURLWithPath: "/invalid/path/file.m4a")
        
        // Attempt to load invalid file
        await viewModel.loadAudio(from: invalidURL)
        
        // Verify error state
        XCTAssertFalse(viewModel.isAudioLoaded)
        XCTAssertTrue(viewModel.showErrorAlert)
        XCTAssertNotNil(viewModel.errorMessage)
    }
    
    func testPlayAndPause() async {
        // Skip test if file doesn't exist
        guard FileManager.default.fileExists(atPath: testAudioURL.path) else {
            XCTFail("Test audio file does not exist")
            return
        }
        
        // Load audio file
        await viewModel.loadAudio(from: testAudioURL)
        
        // Play
        viewModel.play()
        XCTAssertTrue(viewModel.isPlaying)
        XCTAssertFalse(viewModel.isPaused)
        
        // Pause
        viewModel.pause()
        XCTAssertFalse(viewModel.isPlaying)
        XCTAssertTrue(viewModel.isPaused)
        
        // Resume
        viewModel.play()
        XCTAssertTrue(viewModel.isPlaying)
        XCTAssertFalse(viewModel.isPaused)
        
        // Stop
        viewModel.stop()
        XCTAssertFalse(viewModel.isPlaying)
        XCTAssertFalse(viewModel.isPaused)
        XCTAssertEqual(viewModel.currentTime, 0.0)
    }
    
    func testTogglePlayPause() async {
        // Skip test if file doesn't exist
        guard FileManager.default.fileExists(atPath: testAudioURL.path) else {
            XCTFail("Test audio file does not exist")
            return
        }
        
        // Load audio file
        await viewModel.loadAudio(from: testAudioURL)
        
        // Toggle play (should start playing)
        viewModel.togglePlayPause()
        XCTAssertTrue(viewModel.isPlaying)
        XCTAssertFalse(viewModel.isPaused)
        
        // Toggle again (should pause)
        viewModel.togglePlayPause()
        XCTAssertFalse(viewModel.isPlaying)
        XCTAssertTrue(viewModel.isPaused)
    }
    
    func testSeek() async {
        // Skip test if file doesn't exist
        guard FileManager.default.fileExists(atPath: testAudioURL.path) else {
            XCTFail("Test audio file does not exist")
            return
        }
        
        // Load audio file
        await viewModel.loadAudio(from: testAudioURL)
        
        // Set up expectation for progress change
        let expectation = XCTestExpectation(description: "Progress changed")
        
        viewModel.$currentTime
            .dropFirst() // Skip initial value
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Seek to middle
        viewModel.seekToProgress(0.5)
        
        // Wait for progress to update
        await fulfillment(of: [expectation], timeout: 1.0)
        
        // Verify position
        XCTAssertEqual(viewModel.progress, 0.5, accuracy: 0.1)
    }
    
    func testSkipForwardAndBackward() async {
        // Skip test if file doesn't exist
        guard FileManager.default.fileExists(atPath: testAudioURL.path) else {
            XCTFail("Test audio file does not exist")
            return
        }
        
        // Load audio file with known duration
        await viewModel.loadAudio(from: testAudioURL)
        
        // Manually set current time to middle
        let middleTime = viewModel.duration / 2
        viewModel.seek(to: middleTime)
        
        // Skip forward
        viewModel.skipForward(seconds: 5)
        XCTAssertEqual(viewModel.currentTime, middleTime + 5, accuracy: 0.1)
        
        // Skip backward
        viewModel.skipBackward(seconds: 10)
        XCTAssertEqual(viewModel.currentTime, middleTime - 5, accuracy: 0.1)
        
        // Skip backward beyond start should clamp to 0
        viewModel.seek(to: 5)
        viewModel.skipBackward(seconds: 10)
        XCTAssertEqual(viewModel.currentTime, 0, accuracy: 0.1)
    }
    
    func testPlaybackRate() async {
        // Skip test if file doesn't exist
        guard FileManager.default.fileExists(atPath: testAudioURL.path) else {
            XCTFail("Test audio file does not exist")
            return
        }
        
        // Load audio file
        await viewModel.loadAudio(from: testAudioURL)
        
        // Test initial rate
        XCTAssertEqual(viewModel.rate, 1.0)
        XCTAssertEqual(viewModel.rateString, "1.0x")
        
        // Test setting rate to 0.5
        viewModel.setRate(0.5)
        XCTAssertEqual(viewModel.rate, 0.5)
        XCTAssertEqual(viewModel.rateString, "0.5x")
        
        // Test setting rate to 2.0
        viewModel.setRate(2.0)
        XCTAssertEqual(viewModel.rate, 2.0)
        XCTAssertEqual(viewModel.rateString, "2.0x")
        
        // Test next rate cycling
        XCTAssertEqual(viewModel.nextRate, 0.5)
        viewModel.setRate(viewModel.nextRate)
        XCTAssertEqual(viewModel.rate, 0.5)
        
        XCTAssertEqual(viewModel.nextRate, 1.0)
        viewModel.setRate(viewModel.nextRate)
        XCTAssertEqual(viewModel.rate, 1.0)
        
        XCTAssertEqual(viewModel.nextRate, 1.5)
        viewModel.setRate(viewModel.nextRate)
        XCTAssertEqual(viewModel.rate, 1.5)
    }
    
    func testReset() async {
        // Skip test if file doesn't exist
        guard FileManager.default.fileExists(atPath: testAudioURL.path) else {
            XCTFail("Test audio file does not exist")
            return
        }
        
        // Load audio file
        await viewModel.loadAudio(from: testAudioURL)
        
        // Play
        viewModel.play()
        
        // Reset
        viewModel.reset()
        
        // Verify state
        XCTAssertFalse(viewModel.isPlaying)
        XCTAssertFalse(viewModel.isPaused)
        XCTAssertEqual(viewModel.currentTime, 0.0)
        XCTAssertEqual(viewModel.duration, 0.0)
        XCTAssertEqual(viewModel.formattedCurrentTime, "00:00")
        XCTAssertEqual(viewModel.formattedDuration, "00:00")
        XCTAssertEqual(viewModel.audioLevel, 0.0)
        XCTAssertEqual(viewModel.progress, 0.0)
        XCTAssertEqual(viewModel.rate, 1.0)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.showErrorAlert)
        XCTAssertFalse(viewModel.isAudioLoaded)
    }
    
    func testErrorHandling() {
        // Attempt to play without loading audio
        viewModel.play()
        
        // Verify error state
        XCTAssertTrue(viewModel.showErrorAlert)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isPlaying)
    }
    
    func testVisualizationLevel() {
        // Set audio level
        playbackService.setAudioLevelForTesting(0.75)
        
        // Verify visualization level
        XCTAssertEqual(viewModel.visualizationLevel, 0.75)
    }
    
    func testIsPlaybackInProgress() async {
        // Skip test if file doesn't exist
        guard FileManager.default.fileExists(atPath: testAudioURL.path) else {
            XCTFail("Test audio file does not exist")
            return
        }
        
        // Load audio file
        await viewModel.loadAudio(from: testAudioURL)
        
        // Initially not in progress
        XCTAssertFalse(viewModel.isPlaybackInProgress)
        
        // Play
        viewModel.play()
        XCTAssertTrue(viewModel.isPlaybackInProgress)
        
        // Pause
        viewModel.pause()
        XCTAssertTrue(viewModel.isPlaybackInProgress)
        
        // Stop
        viewModel.stop()
        XCTAssertFalse(viewModel.isPlaybackInProgress)
    }
    
    // MARK: - Helper Methods
    
    private func createTestAudioFile() {
        // This is a simplified method to create a test audio file
        // In a real test, you might want to use a pre-recorded test file
        
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            let audioRecorder = try AVAudioRecorder(url: testAudioURL, settings: settings)
            audioRecorder.prepareToRecord()
            audioRecorder.record(forDuration: 2.0)  // Record 2 seconds of silence
            
            // Wait for recording to finish
            Thread.sleep(forTimeInterval: 2.5)
            
            if FileManager.default.fileExists(atPath: testAudioURL.path) {
                print("Test audio file created successfully")
            } else {
                print("Failed to create test audio file")
            }
        } catch {
            print("Error creating test audio file: \(error.localizedDescription)")
        }
    }
}
