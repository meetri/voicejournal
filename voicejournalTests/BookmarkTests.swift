//
//  BookmarkTests.swift
//  voicejournalTests
//
//  Created on 4/27/25.
//

import XCTest
import CoreData
@testable import voicejournal

class BookmarkTests: XCTestCase {
    
    var context: NSManagedObjectContext!
    
    override func setUpWithError() throws {
        // Set up an in-memory Core Data stack for testing
        let persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
    }
    
    override func tearDownWithError() throws {
        // Clean up the context after each test
        context = nil
    }
    
    // MARK: - Bookmark Creation Tests
    
    func testCreateBookmark() throws {
        // Create a journal entry and audio recording
        let entry = JournalEntry.create(in: context)
        let recording = entry.createAudioRecording(filePath: "test/path.m4a")
        
        // Create a bookmark
        let timestamp: TimeInterval = 30.5
        let label = "Test Bookmark"
        let color = "#FF5733"
        
        let bookmark = Bookmark.create(
            at: timestamp,
            label: label,
            color: color,
            for: recording,
            in: context
        )
        
        // Verify bookmark properties
        XCTAssertEqual(bookmark.timestamp, timestamp)
        XCTAssertEqual(bookmark.label, label)
        XCTAssertEqual(bookmark.color, color)
        XCTAssertEqual(bookmark.audioRecording, recording)
        XCTAssertNotNil(bookmark.createdAt)
        
        // Verify relationship
        XCTAssertTrue(recording.bookmarks?.contains(bookmark) ?? false)
    }
    
    func testCreateBookmarkWithDefaultColor() throws {
        // Create a journal entry and audio recording
        let entry = JournalEntry.create(in: context)
        let recording = entry.createAudioRecording(filePath: "test/path.m4a")
        
        // Create a bookmark with default color
        let bookmark = Bookmark.create(
            at: 45.0,
            label: "Test Bookmark",
            for: recording,
            in: context
        )
        
        // Verify bookmark has a color (from default colors)
        XCTAssertNotNil(bookmark.color)
        XCTAssertTrue(Bookmark.defaultColors.contains(bookmark.color!))
    }
    
    func testFormattedTimestamp() throws {
        // Create a journal entry and audio recording
        let entry = JournalEntry.create(in: context)
        let recording = entry.createAudioRecording(filePath: "test/path.m4a")
        
        // Create bookmarks with different timestamps
        let bookmark1 = Bookmark.create(at: 65.0, for: recording, in: context)
        let bookmark2 = Bookmark.create(at: 125.5, for: recording, in: context)
        
        // Verify formatted timestamps
        XCTAssertEqual(bookmark1.formattedTimestamp, "1:05")
        XCTAssertEqual(bookmark2.formattedTimestamp, "2:05")
    }
    
    // MARK: - AudioRecording Extension Tests
    
    func testAudioRecordingCreateBookmark() throws {
        // Create a journal entry and audio recording
        let entry = JournalEntry.create(in: context)
        let recording = entry.createAudioRecording(filePath: "test/path.m4a")
        
        // Create a bookmark using the AudioRecording extension method
        let bookmark = recording.createBookmark(at: 15.0, label: "Test")
        
        // Verify bookmark was created and added to the recording
        XCTAssertEqual(bookmark.timestamp, 15.0)
        XCTAssertEqual(bookmark.label, "Test")
        XCTAssertEqual(bookmark.audioRecording, recording)
        
        // Verify the bookmark is in the recording's bookmarks collection
        XCTAssertTrue(recording.allBookmarks.contains(bookmark))
    }
    
    func testAudioRecordingDeleteBookmark() throws {
        // Create a journal entry and audio recording
        let entry = JournalEntry.create(in: context)
        let recording = entry.createAudioRecording(filePath: "test/path.m4a")
        
        // Create bookmarks
        let bookmark1 = recording.createBookmark(at: 10.0, label: "Bookmark 1")
        let bookmark2 = recording.createBookmark(at: 20.0, label: "Bookmark 2")
        
        // Verify both bookmarks exist
        XCTAssertEqual(recording.allBookmarks.count, 2)
        
        // Delete one bookmark
        recording.deleteBookmark(bookmark1)
        
        // Verify only one bookmark remains
        XCTAssertEqual(recording.allBookmarks.count, 1)
        XCTAssertEqual(recording.allBookmarks.first, bookmark2)
    }
    
    func testFindNearestBookmark() throws {
        // Create a journal entry and audio recording
        let entry = JournalEntry.create(in: context)
        let recording = entry.createAudioRecording(filePath: "test/path.m4a")
        
        // Create bookmarks at different positions
        let bookmark1 = recording.createBookmark(at: 10.0, label: "Bookmark 1")
        let bookmark2 = recording.createBookmark(at: 30.0, label: "Bookmark 2")
        let bookmark3 = recording.createBookmark(at: 60.0, label: "Bookmark 3")
        
        // Test finding nearest bookmark
        XCTAssertEqual(recording.nearestBookmark(to: 12.0), bookmark1)
        XCTAssertEqual(recording.nearestBookmark(to: 25.0), bookmark2)
        XCTAssertEqual(recording.nearestBookmark(to: 45.0), bookmark3)
        XCTAssertEqual(recording.nearestBookmark(to: 70.0), bookmark3)
    }
    
    func testNextAndPreviousBookmark() throws {
        // Create a journal entry and audio recording
        let entry = JournalEntry.create(in: context)
        let recording = entry.createAudioRecording(filePath: "test/path.m4a")
        
        // Create bookmarks at different positions
        let bookmark1 = recording.createBookmark(at: 10.0, label: "Bookmark 1")
        let bookmark2 = recording.createBookmark(at: 30.0, label: "Bookmark 2")
        let bookmark3 = recording.createBookmark(at: 60.0, label: "Bookmark 3")
        
        // Test next bookmark
        XCTAssertEqual(recording.nextBookmark(after: 5.0), bookmark1)
        XCTAssertEqual(recording.nextBookmark(after: 15.0), bookmark2)
        XCTAssertEqual(recording.nextBookmark(after: 40.0), bookmark3)
        XCTAssertNil(recording.nextBookmark(after: 70.0))
        
        // Test previous bookmark
        XCTAssertNil(recording.previousBookmark(before: 5.0))
        XCTAssertEqual(recording.previousBookmark(before: 15.0), bookmark1)
        XCTAssertEqual(recording.previousBookmark(before: 40.0), bookmark2)
        XCTAssertEqual(recording.previousBookmark(before: 70.0), bookmark3)
    }
    
    // MARK: - Edge Cases
    
    func testEmptyBookmarks() throws {
        // Create a journal entry and audio recording
        let entry = JournalEntry.create(in: context)
        let recording = entry.createAudioRecording(filePath: "test/path.m4a")
        
        // Test with no bookmarks
        XCTAssertEqual(recording.allBookmarks.count, 0)
        XCTAssertNil(recording.nearestBookmark(to: 10.0))
        XCTAssertNil(recording.nextBookmark(after: 10.0))
        XCTAssertNil(recording.previousBookmark(before: 10.0))
    }
}
