//
//  PlayerManagerTests.swift
//  voicejournalTests
//
//  Created on 4/27/25.
//

import XCTest
import CoreData
@testable import voicejournal

@MainActor
final class PlayerManagerTests: XCTestCase {
    
    var playerManager: PlayerManager!
    var context: NSManagedObjectContext!
    var testEntry: JournalEntry!
    
    override func setUpWithError() throws {
        // Use in-memory Core Data stack for testing
        context = PersistenceController.preview.container.viewContext
        
        // Create a test journal entry with audio recording
        testEntry = JournalEntry.create(in: context)
        testEntry.title = "Test Journal Entry"
        testEntry.createdAt = Date()
        
        // Create a test audio recording
        let recording = testEntry.createAudioRecording(filePath: "/path/to/test_audio.m4a")
        recording.duration = 60.0
        recording.fileSize = 1024 * 1024 // 1 MB
        
        // Create a test transcription
        let transcription = testEntry.createTranscription(text: "This is a test transcription.")
        
        // Save the context
        try context.save()
        
        // Get the shared player manager
        playerManager = PlayerManager.shared
    }
    
    override func tearDownWithError() throws {
        // Stop playback and reset player manager
        playerManager.stopPlayback()
        
        // Delete test entry
        if let entry = testEntry {
            context.delete(entry)
            try context.save()
        }
        
        playerManager = nil
        testEntry = nil
        context = nil
    }
    
    // MARK: - Tests
    
    func testInitialState() {
        XCTAssertFalse(playerManager.isPlayerActive)
        XCTAssertFalse(playerManager.isPlayerExpanded)
        XCTAssertNil(playerManager.currentJournalEntry)
    }
    
    func testPlayAudio() async {
        // Play audio from test entry
        await playerManager.playAudio(from: testEntry)
        
        // Verify state
        XCTAssertTrue(playerManager.isPlayerActive)
        XCTAssertEqual(playerManager.currentJournalEntry?.id, testEntry.id)
        
        // Verify playback view model state
        XCTAssertTrue(playerManager.playbackViewModel.isAudioLoaded)
    }
    
    func testStopPlayback() async {
        // Play audio from test entry
        await playerManager.playAudio(from: testEntry)
        
        // Verify state
        XCTAssertTrue(playerManager.isPlayerActive)
        
        // Stop playback
        playerManager.stopPlayback()
        
        // Verify state
        XCTAssertFalse(playerManager.isPlayerActive)
        XCTAssertNil(playerManager.currentJournalEntry)
        XCTAssertFalse(playerManager.isPlayerExpanded)
    }
    
    func testTogglePlayPause() async {
        // Play audio from test entry
        await playerManager.playAudio(from: testEntry)
        
        // Verify state
        XCTAssertTrue(playerManager.playbackViewModel.isPlaying)
        
        // Toggle to pause
        playerManager.togglePlayPause()
        
        // Verify state
        XCTAssertFalse(playerManager.playbackViewModel.isPlaying)
        XCTAssertTrue(playerManager.playbackViewModel.isPaused)
        
        // Toggle to play
        playerManager.togglePlayPause()
        
        // Verify state
        XCTAssertTrue(playerManager.playbackViewModel.isPlaying)
        XCTAssertFalse(playerManager.playbackViewModel.isPaused)
    }
    
    func testExpandCollapsePlayer() {
        // Expand player
        playerManager.expandPlayer()
        
        // Verify state
        XCTAssertTrue(playerManager.isPlayerExpanded)
        
        // Collapse player
        playerManager.collapsePlayer()
        
        // Verify state
        XCTAssertFalse(playerManager.isPlayerExpanded)
    }
    
    func testPlaybackStatePublisher() async {
        // Initially inactive
        XCTAssertFalse(playerManager.isPlayerActive)
        
        // Play audio
        await playerManager.playAudio(from: testEntry)
        
        // Should be active
        XCTAssertTrue(playerManager.isPlayerActive)
        
        // Pause
        playerManager.playbackViewModel.pause()
        
        // Should still be active when paused
        XCTAssertTrue(playerManager.isPlayerActive)
        
        // Stop
        playerManager.stopPlayback()
        
        // Should be inactive
        XCTAssertFalse(playerManager.isPlayerActive)
    }
}
