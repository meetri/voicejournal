//
//  RemoteControlManagerTests.swift
//  voicejournalTests
//
//  Created on 4/27/25.
//

import XCTest
import MediaPlayer
@testable import voicejournal

@MainActor
final class RemoteControlManagerTests: XCTestCase {
    
    var playbackService: AudioPlaybackService!
    var testAudioURL: URL!
    
    override func setUpWithError() throws {
        playbackService = AudioPlaybackService()
        
        // Create a temporary directory for test files
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RemoteControlManagerTests", isDirectory: true)
        
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
        
        // Clear remote controls
        RemoteControlManager.shared.clearRemoteControls()
        
        // Clean up test files
        try? FileManager.default.removeItem(at: testAudioURL)
    }
    
    // MARK: - Tests
    
    func testSetupRemoteControls() async throws {
        // Skip test if file doesn't exist
        guard FileManager.default.fileExists(atPath: testAudioURL.path) else {
            XCTFail("Test audio file does not exist")
            return
        }
        
        // Load audio file
        try await playbackService.loadAudio(from: testAudioURL)
        
        // Set up remote controls
        RemoteControlManager.shared.setupRemoteControls(
            for: playbackService,
            title: "Test Audio",
            artwork: nil
        )
        
        // Verify that the now playing info center has been updated
        let nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo
        XCTAssertNotNil(nowPlayingInfo, "Now playing info should not be nil")
        XCTAssertEqual(nowPlayingInfo?[MPMediaItemPropertyTitle] as? String, "Test Audio")
        XCTAssertEqual(nowPlayingInfo?[MPMediaItemPropertyPlaybackDuration] as? TimeInterval, playbackService.duration)
        XCTAssertEqual(nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? TimeInterval, playbackService.currentTime)
        XCTAssertEqual(nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] as? Float, playbackService.rate)
    }
    
    func testClearRemoteControls() async throws {
        // Skip test if file doesn't exist
        guard FileManager.default.fileExists(atPath: testAudioURL.path) else {
            XCTFail("Test audio file does not exist")
            return
        }
        
        // Load audio file
        try await playbackService.loadAudio(from: testAudioURL)
        
        // Set up remote controls
        RemoteControlManager.shared.setupRemoteControls(
            for: playbackService,
            title: "Test Audio",
            artwork: nil
        )
        
        // Verify that the now playing info center has been updated
        XCTAssertNotNil(MPNowPlayingInfoCenter.default().nowPlayingInfo)
        
        // Clear remote controls
        RemoteControlManager.shared.clearRemoteControls()
        
        // Verify that the now playing info center has been cleared
        XCTAssertNil(MPNowPlayingInfoCenter.default().nowPlayingInfo)
    }
    
    func testUpdateNowPlayingInfo() async throws {
        // Skip test if file doesn't exist
        guard FileManager.default.fileExists(atPath: testAudioURL.path) else {
            XCTFail("Test audio file does not exist")
            return
        }
        
        // Load audio file
        try await playbackService.loadAudio(from: testAudioURL)
        
        // Set up remote controls
        RemoteControlManager.shared.setupRemoteControls(
            for: playbackService,
            title: "Test Audio",
            artwork: nil
        )
        
        // Update now playing info
        RemoteControlManager.shared.updateNowPlayingInfo(
            title: "Updated Title",
            duration: 120.0,
            currentTime: 60.0,
            rate: 1.5
        )
        
        // Verify that the now playing info center has been updated
        let nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo
        XCTAssertNotNil(nowPlayingInfo, "Now playing info should not be nil")
        XCTAssertEqual(nowPlayingInfo?[MPMediaItemPropertyTitle] as? String, "Updated Title")
        XCTAssertEqual(nowPlayingInfo?[MPMediaItemPropertyPlaybackDuration] as? TimeInterval, 120.0)
        XCTAssertEqual(nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? TimeInterval, 60.0)
        XCTAssertEqual(nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] as? Float, 1.5)
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
