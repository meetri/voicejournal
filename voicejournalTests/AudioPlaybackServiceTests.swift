//
//  AudioPlaybackServiceTests.swift
//  voicejournalTests
//
//  Created on 4/27/25.
//

import XCTest
import AVFoundation
@testable import voicejournal

@MainActor
final class AudioPlaybackServiceTests: XCTestCase {
    
    var playbackService: AudioPlaybackService!
    var testAudioURL: URL!
    
    override func setUpWithError() throws {
        playbackService = AudioPlaybackService()
        
        // Create a temporary directory for test files
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AudioPlaybackServiceTests", isDirectory: true)
        
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
        playbackService.reset()
        playbackService = nil
        
        // Clean up test files
        try? FileManager.default.removeItem(at: testAudioURL)
    }
    
    // MARK: - Tests
    
    func testInitialState() {
        XCTAssertEqual(playbackService.state, .ready)
        XCTAssertEqual(playbackService.currentTime, 0.0)
        XCTAssertEqual(playbackService.duration, 0.0)
        XCTAssertEqual(playbackService.audioLevel, 0.0)
        XCTAssertEqual(playbackService.rate, 1.0)
        XCTAssertNil(playbackService.audioFileURL)
    }
    
    func testLoadAudio() async throws {
        // Skip test if file doesn't exist
        guard FileManager.default.fileExists(atPath: testAudioURL.path) else {
            XCTFail("Test audio file does not exist")
            return
        }
        
        // Load audio file
        try await playbackService.loadAudio(from: testAudioURL)
        
        // Verify state
        XCTAssertEqual(playbackService.state, .ready)
        XCTAssertGreaterThan(playbackService.duration, 0.0)
        XCTAssertEqual(playbackService.audioFileURL, testAudioURL)
    }
    
    func testLoadAudioWithInvalidFile() async {
        // Create an invalid file URL
        let invalidURL = URL(fileURLWithPath: "/invalid/path/file.m4a")
        
        // Attempt to load invalid file
        do {
            try await playbackService.loadAudio(from: invalidURL)
            XCTFail("Loading invalid file should throw an error")
        } catch {
            // Verify error
            XCTAssertTrue(error is AudioPlaybackError)
            if let playbackError = error as? AudioPlaybackError {
                XCTAssertEqual(playbackError, AudioPlaybackError.fileNotFound)
            }
        }
    }
    
    func testPlayWithoutLoadingAudio() {
        // Attempt to play without loading audio
        do {
            try playbackService.play()
            XCTFail("Playing without loading audio should throw an error")
        } catch {
            // Verify error
            XCTAssertTrue(error is AudioPlaybackError)
            if let playbackError = error as? AudioPlaybackError {
                XCTAssertEqual(playbackError, AudioPlaybackError.noPlaybackInProgress)
            }
        }
    }
    
    func testPlayAndPause() async throws {
        // Skip test if file doesn't exist
        guard FileManager.default.fileExists(atPath: testAudioURL.path) else {
            XCTFail("Test audio file does not exist")
            return
        }
        
        // Load audio file
        try await playbackService.loadAudio(from: testAudioURL)
        
        // Play
        try playbackService.play()
        XCTAssertEqual(playbackService.state, .playing)
        
        // Pause
        try playbackService.pause()
        XCTAssertEqual(playbackService.state, .paused)
        
        // Resume
        try playbackService.play()
        XCTAssertEqual(playbackService.state, .playing)
        
        // Stop
        try playbackService.stop()
        XCTAssertEqual(playbackService.state, .stopped)
        XCTAssertEqual(playbackService.currentTime, 0.0)
    }
    
    func testSeek() async throws {
        // Skip test if file doesn't exist
        guard FileManager.default.fileExists(atPath: testAudioURL.path) else {
            XCTFail("Test audio file does not exist")
            return
        }
        
        // Load audio file
        try await playbackService.loadAudio(from: testAudioURL)
        
        // Seek to middle
        let seekTime = playbackService.duration / 2
        try playbackService.seek(to: seekTime)
        
        // Verify position
        XCTAssertEqual(playbackService.currentTime, seekTime, accuracy: 0.1)
        
        // Seek beyond duration should clamp to duration
        try playbackService.seek(to: playbackService.duration + 10)
        XCTAssertEqual(playbackService.currentTime, playbackService.duration, accuracy: 0.1)
        
        // Seek to negative should clamp to 0
        try playbackService.seek(to: -10)
        XCTAssertEqual(playbackService.currentTime, 0.0, accuracy: 0.1)
    }
    
    func testPlaybackRate() async throws {
        // Skip test if file doesn't exist
        guard FileManager.default.fileExists(atPath: testAudioURL.path) else {
            XCTFail("Test audio file does not exist")
            return
        }
        
        // Load audio file
        try await playbackService.loadAudio(from: testAudioURL)
        
        // Set rate to 0.5
        try playbackService.setRate(0.5)
        XCTAssertEqual(playbackService.rate, 0.5)
        
        // Set rate to 2.0
        try playbackService.setRate(2.0)
        XCTAssertEqual(playbackService.rate, 2.0)
        
        // Set rate beyond limits should clamp
        try playbackService.setRate(3.0)
        XCTAssertEqual(playbackService.rate, 2.0)
        
        try playbackService.setRate(0.1)
        XCTAssertEqual(playbackService.rate, 0.5)
    }
    
    func testPlaybackRatePersistence() async throws {
        // Skip test if file doesn't exist
        guard FileManager.default.fileExists(atPath: testAudioURL.path) else {
            XCTFail("Test audio file does not exist")
            return
        }
        
        // Load audio file
        try await playbackService.loadAudio(from: testAudioURL)
        
        // Set rate to 1.5x before playing
        try playbackService.setRate(1.5)
        XCTAssertEqual(playbackService.rate, 1.5)
        
        // Start playback
        try playbackService.play()
        XCTAssertEqual(playbackService.state, .playing)
        
        // Verify rate is maintained during playback
        XCTAssertEqual(playbackService.rate, 1.5)
        
        // Pause playback
        try playbackService.pause()
        XCTAssertEqual(playbackService.state, .paused)
        
        // Verify rate is maintained while paused
        XCTAssertEqual(playbackService.rate, 1.5)
        
        // Resume playback
        try playbackService.play()
        XCTAssertEqual(playbackService.state, .playing)
        
        // Verify rate is maintained after resuming
        XCTAssertEqual(playbackService.rate, 1.5)
        
        // Stop playback
        try playbackService.stop()
        XCTAssertEqual(playbackService.state, .stopped)
        
        // Verify rate is maintained after stopping
        XCTAssertEqual(playbackService.rate, 1.5)
        
        // Start playback again
        try playbackService.play()
        
        // Verify rate is still maintained when starting playback again
        XCTAssertEqual(playbackService.rate, 1.5)
    }
    
    func testEnableRateProperty() async throws {
        // Skip test if file doesn't exist
        guard FileManager.default.fileExists(atPath: testAudioURL.path) else {
            XCTFail("Test audio file does not exist")
            return
        }
        
        // Load audio file
        try await playbackService.loadAudio(from: testAudioURL)
        
        // Access the private audioPlayer property using reflection
        let mirror = Mirror(reflecting: playbackService)
        let audioPlayerProperty = mirror.children.first { $0.label == "audioPlayer" }
        
        // Verify that the audioPlayer property exists
        guard let audioPlayerWrapper = audioPlayerProperty?.value else {
            XCTFail("Could not access audioPlayer property")
            return
        }
        
        // Get the actual AVAudioPlayer instance
        let audioPlayerMirror = Mirror(reflecting: audioPlayerWrapper)
        guard let audioPlayer = audioPlayerMirror.children.first?.value as? AVAudioPlayer else {
            XCTFail("Could not access AVAudioPlayer instance")
            return
        }
        
        // Verify that enableRate is set to true
        XCTAssertTrue(audioPlayer.enableRate, "enableRate should be set to true")
        
        // Test changing rates
        try playbackService.setRate(2.0)
        try playbackService.play()
        
        // Verify the rate was applied to the player
        XCTAssertEqual(audioPlayer.rate, 2.0, "AVAudioPlayer rate should be 2.0")
    }
    
    func testReset() async throws {
        // Skip test if file doesn't exist
        guard FileManager.default.fileExists(atPath: testAudioURL.path) else {
            XCTFail("Test audio file does not exist")
            return
        }
        
        // Load audio file
        try await playbackService.loadAudio(from: testAudioURL)
        
        // Set a custom rate
        try playbackService.setRate(1.5)
        
        // Play
        try playbackService.play()
        
        // Reset
        playbackService.reset()
        
        // Verify state
        XCTAssertEqual(playbackService.state, .ready)
        XCTAssertEqual(playbackService.currentTime, 0.0)
        XCTAssertEqual(playbackService.duration, 0.0)
        XCTAssertEqual(playbackService.audioLevel, 0.0)
        // Rate should be maintained at 1.5 after reset
        XCTAssertEqual(playbackService.rate, 1.5)
        XCTAssertNil(playbackService.audioFileURL)
    }
    
    func testFormattedTime() {
        // Test formatted current time
        playbackService.setCurrentTimeForTesting(65.5)
        XCTAssertEqual(playbackService.formattedCurrentTime, "01:05")
        
        // Test formatted duration
        playbackService.setDurationForTesting(125.0)
        XCTAssertEqual(playbackService.formattedDuration, "02:05")
        
        // Test zero time
        playbackService.setCurrentTimeForTesting(0)
        XCTAssertEqual(playbackService.formattedCurrentTime, "00:00")
    }
    
    func testProgress() {
        // Set duration and current time
        playbackService.setDurationForTesting(100.0)
        playbackService.setCurrentTimeForTesting(25.0)
        
        // Verify progress
        XCTAssertEqual(playbackService.progress, 0.25)
        
        // Test with zero duration
        playbackService.setDurationForTesting(0.0)
        XCTAssertEqual(playbackService.progress, 0.0)
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
