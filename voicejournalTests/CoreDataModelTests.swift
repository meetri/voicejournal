//
//  CoreDataModelTests.swift
//  voicejournalTests
//
//  Created on 4/27/25.
//

import XCTest
import CoreData
@testable import voicejournal

final class CoreDataModelTests: XCTestCase {
    var container: NSPersistentContainer!
    var context: NSManagedObjectContext!
    
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
    }
    
    override func tearDownWithError() throws {
        context = nil
        container = nil
    }
    
    // Test creating a journal entry
    func testCreateJournalEntry() throws {
        // Create a journal entry
        let entry = JournalEntry.create(in: context)
        entry.title = "Test Journal Entry"
        
        // Save the context
        try context.save()
        
        // Fetch the entry
        let fetchRequest: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "title == %@", "Test Journal Entry")
        
        let results = try context.fetch(fetchRequest)
        XCTAssertEqual(results.count, 1, "Should have one journal entry")
        XCTAssertEqual(results.first?.title, "Test Journal Entry", "Title should match")
        XCTAssertNotNil(results.first?.createdAt, "Created date should be set")
        XCTAssertNotNil(results.first?.modifiedAt, "Modified date should be set")
        XCTAssertFalse(results.first?.isLocked ?? true, "Entry should not be locked by default")
    }
    
    // Test creating an audio recording for a journal entry
    func testCreateAudioRecording() throws {
        // Create a journal entry
        let entry = JournalEntry.create(in: context)
        entry.title = "Entry with Audio"
        
        // Create an audio recording
        let recording = entry.createAudioRecording(filePath: "test/path/audio.m4a")
        recording.duration = 120.5
        recording.fileSize = 1024 * 1024 // 1MB
        
        // Save the context
        try context.save()
        
        // Fetch the entry with its recording
        let fetchRequest: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "title == %@", "Entry with Audio")
        fetchRequest.relationshipKeyPathsForPrefetching = ["audioRecording"]
        
        let results = try context.fetch(fetchRequest)
        XCTAssertEqual(results.count, 1, "Should have one journal entry")
        
        let fetchedEntry = results.first!
        XCTAssertNotNil(fetchedEntry.audioRecording, "Audio recording should be associated")
        XCTAssertEqual(fetchedEntry.audioRecording?.filePath, "test/path/audio.m4a", "File path should match")
        XCTAssertEqual(fetchedEntry.audioRecording?.duration, 120.5, "Duration should match")
        XCTAssertEqual(fetchedEntry.audioRecording?.fileSize, 1024 * 1024, "File size should match")
        XCTAssertNotNil(fetchedEntry.audioRecording?.recordedAt, "Recorded date should be set")
    }
    
    // Test creating a transcription for a journal entry
    func testCreateTranscription() throws {
        // Create a journal entry
        let entry = JournalEntry.create(in: context)
        entry.title = "Entry with Transcription"
        
        // Create a transcription
        let transcription = entry.createTranscription(text: "This is a test transcription.")
        
        // Save the context
        try context.save()
        
        // Fetch the entry with its transcription
        let fetchRequest: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "title == %@", "Entry with Transcription")
        fetchRequest.relationshipKeyPathsForPrefetching = ["transcription"]
        
        let results = try context.fetch(fetchRequest)
        XCTAssertEqual(results.count, 1, "Should have one journal entry")
        
        let fetchedEntry = results.first!
        XCTAssertNotNil(fetchedEntry.transcription, "Transcription should be associated")
        XCTAssertEqual(fetchedEntry.transcription?.text, "This is a test transcription.", "Transcription text should match")
        XCTAssertNotNil(fetchedEntry.transcription?.createdAt, "Created date should be set")
        XCTAssertNotNil(fetchedEntry.transcription?.modifiedAt, "Modified date should be set")
    }
    
    // Test adding tags to a journal entry
    func testAddTags() throws {
        // Create a journal entry
        let entry = JournalEntry.create(in: context)
        entry.title = "Entry with Tags"
        
        // Add tags
        let tag1 = entry.addTag("work")
        let tag2 = entry.addTag("important")
        
        // Save the context
        try context.save()
        
        // Fetch the entry with its tags
        let fetchRequest: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "title == %@", "Entry with Tags")
        
        let results = try context.fetch(fetchRequest)
        XCTAssertEqual(results.count, 1, "Should have one journal entry")
        
        let fetchedEntry = results.first!
        let tags = fetchedEntry.tags?.allObjects as? [Tag] ?? []
        XCTAssertEqual(tags.count, 2, "Should have two tags")
        
        let tagNames = tags.compactMap { $0.name }
        XCTAssertTrue(tagNames.contains("work"), "Should have 'work' tag")
        XCTAssertTrue(tagNames.contains("important"), "Should have 'important' tag")
    }
    
    // Test fetching entries by tag
    func testFetchByTag() throws {
        // Create multiple entries with different tags
        let entry1 = JournalEntry.create(in: context)
        entry1.title = "Work Entry"
        entry1.addTag("work")
        
        let entry2 = JournalEntry.create(in: context)
        entry2.title = "Personal Entry"
        entry2.addTag("personal")
        
        let entry3 = JournalEntry.create(in: context)
        entry3.title = "Important Work Entry"
        entry3.addTag("work")
        entry3.addTag("important")
        
        // Save the context
        try context.save()
        
        // Fetch entries with "work" tag
        let workEntries = JournalEntry.fetch(withTag: "work", in: context)
        XCTAssertEqual(workEntries.count, 2, "Should have two entries with 'work' tag")
        
        // Fetch entries with "personal" tag
        let personalEntries = JournalEntry.fetch(withTag: "personal", in: context)
        XCTAssertEqual(personalEntries.count, 1, "Should have one entry with 'personal' tag")
        
        // Fetch entries with "important" tag
        let importantEntries = JournalEntry.fetch(withTag: "important", in: context)
        XCTAssertEqual(importantEntries.count, 1, "Should have one entry with 'important' tag")
    }
    
    // Test locking and unlocking entries
    func testLockUnlockEntry() throws {
        // Create a journal entry
        let entry = JournalEntry.create(in: context)
        entry.title = "Sensitive Entry"
        
        // Initially not locked
        XCTAssertFalse(entry.isLocked, "Entry should not be locked by default")
        
        // Lock the entry
        entry.lock()
        XCTAssertTrue(entry.isLocked, "Entry should be locked after calling lock()")
        
        // Unlock the entry
        entry.unlock()
        XCTAssertFalse(entry.isLocked, "Entry should be unlocked after calling unlock()")
    }
    
    // Test searching entries
    func testSearchEntries() throws {
        // Create entries with different content
        let entry1 = JournalEntry.create(in: context)
        entry1.title = "Meeting with John"
        entry1.createTranscription(text: "We discussed the project timeline.")
        
        let entry2 = JournalEntry.create(in: context)
        entry2.title = "Grocery List"
        entry2.createTranscription(text: "Milk, eggs, bread")
        
        let entry3 = JournalEntry.create(in: context)
        entry3.title = "Project Ideas"
        entry3.createTranscription(text: "New timeline for the project launch")
        
        // Save the context
        try context.save()
        
        // Search for "project"
        let projectResults = JournalEntry.search(query: "project", in: context)
        XCTAssertEqual(projectResults.count, 2, "Should find two entries containing 'project'")
        
        // Search for "milk"
        let milkResults = JournalEntry.search(query: "milk", in: context)
        XCTAssertEqual(milkResults.count, 1, "Should find one entry containing 'milk'")
        
        // Search for "meeting"
        let meetingResults = JournalEntry.search(query: "meeting", in: context)
        XCTAssertEqual(meetingResults.count, 1, "Should find one entry containing 'meeting'")
    }
}
