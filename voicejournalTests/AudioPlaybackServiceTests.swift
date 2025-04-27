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
    
    func testReset() async throws {
        // Skip test if file doesn't exist
        guard FileManager.default.fileExists(atPath: testAudioURL.path) else {
            XCTFail("Test audio file does not exist")
            return
        }
        
        // Load audio file
        try await playbackService.loadAudio(from: testAudioURL)
        
        // Play
        try playbackService.play()
        
        // Reset
        playbackService.reset()
        
        // Verify state
        XCTAssertEqual(playbackService.state, .ready)
        XCTAssertEqual(playbackService.currentTime, 0.0)
        XCTAssertEqual(playbackService.duration, 0.0)
        XCTAssertEqual(playbackService.audioLevel, 0.0)
        XCTAssertEqual(playbackService.rate, 1.0)
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
