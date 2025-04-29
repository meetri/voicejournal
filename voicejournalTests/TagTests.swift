//
//  TagTests.swift
//  voicejournalTests
//
//  Created on 4/29/25.
//

import XCTest
import CoreData
@testable import voicejournal

class TagTests: XCTestCase {
    
    // MARK: - Test Environment
    
    var context: NSManagedObjectContext!
    
    override func setUpWithError() throws {
        // Set up an in-memory Core Data stack for testing
        let persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
    }
    
    override func tearDownWithError() throws {
        // Clean up the context after each test
        try? context.save()
        context = nil
    }
    
    // MARK: - Tag Creation Tests
    
    func testCreateTag() throws {
        // Test creating a new tag
        let tag = Tag.findOrCreate(name: "TestTag", colorHex: "#FF5733", in: context)
        
        XCTAssertNotNil(tag)
        XCTAssertEqual(tag.name, "TestTag")
        XCTAssertEqual(tag.color, "#FF5733")
        XCTAssertNotNil(tag.createdAt)
    }
    
    func testFindExistingTag() throws {
        // Create a tag first
        let tag1 = Tag.findOrCreate(name: "ExistingTag", colorHex: "#FF5733", in: context)
        try context.save()
        
        // Try to find the same tag
        let tag2 = Tag.findOrCreate(name: "ExistingTag", in: context)
        
        // Should return the existing tag, not create a new one
        XCTAssertEqual(tag1, tag2)
        XCTAssertEqual(tag1.color, tag2.color)
    }
    
    func testCaseInsensitiveTagFinding() throws {
        // Create a tag with specific casing
        let tag1 = Tag.findOrCreate(name: "MixedCase", colorHex: "#FF5733", in: context)
        try context.save()
        
        // Try to find the same tag with different casing
        let tag2 = Tag.findOrCreate(name: "mixedcase", in: context)
        
        // Should return the existing tag, not create a new one
        XCTAssertEqual(tag1, tag2)
        XCTAssertEqual(tag1.name, "MixedCase") // Original casing should be preserved
    }
    
    func testTagNameTrimming() throws {
        // Create a tag with whitespace
        let tag = Tag.findOrCreate(name: "  SpacedTag  ", in: context)
        
        // Name should be trimmed
        XCTAssertEqual(tag.name, "SpacedTag")
    }
    
    // MARK: - Tag Fetching Tests
    
    func testFetchAllTags() throws {
        // Create multiple tags
        let _ = Tag.findOrCreate(name: "Tag1", in: context)
        let _ = Tag.findOrCreate(name: "Tag2", in: context)
        let _ = Tag.findOrCreate(name: "Tag3", in: context)
        try context.save()
        
        // Fetch all tags
        let tags = Tag.fetchAll(in: context)
        
        // Should return all 3 tags
        XCTAssertEqual(tags.count, 3)
    }
    
    func testFetchMatchingTags() throws {
        // Create tags with different names
        let _ = Tag.findOrCreate(name: "Work", in: context)
        let _ = Tag.findOrCreate(name: "Workout", in: context)
        let _ = Tag.findOrCreate(name: "Personal", in: context)
        try context.save()
        
        // Fetch tags matching "work"
        let matchingTags = Tag.fetch(matching: "work", in: context)
        
        // Should return 2 tags (Work and Workout)
        XCTAssertEqual(matchingTags.count, 2)
    }
    
    // MARK: - Tag Deletion Tests
    
    func testDeleteTag() throws {
        // Create a tag
        let tag = Tag.findOrCreate(name: "DeleteMe", in: context)
        try context.save()
        
        // Delete the tag
        tag.delete(in: context)
        try context.save()
        
        // Verify tag is deleted
        let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", "DeleteMe")
        let results = try context.fetch(fetchRequest)
        
        XCTAssertEqual(results.count, 0)
    }
    
    // MARK: - Tag Suggestion Tests
    
    func testSuggestTagsEmpty() throws {
        // Test with empty text
        let suggestions = Tag.suggestTags(for: "", existingTags: [], context: context)
        
        // Should return empty array
        XCTAssertTrue(suggestions.isEmpty)
    }
    
    func testSuggestExistingTags() throws {
        // Create some tags
        let workTag = Tag.findOrCreate(name: "Work", in: context)
        let healthTag = Tag.findOrCreate(name: "Health", in: context)
        let existingTags = [workTag, healthTag]
        
        // Text containing one of the tag names
        let text = "I had a busy day at work today with many meetings."
        
        // Get suggestions
        let suggestions = Tag.suggestTags(for: text, existingTags: existingTags, context: context)
        
        // Should suggest "Work" tag
        XCTAssertTrue(suggestions.contains("Work"))
        XCTAssertFalse(suggestions.contains("Health"))
    }
    
    func testSuggestFrequentWords() throws {
        // Text with repeated words
        let text = "Meeting meeting meeting with the team about project project deadlines."
        
        // Get suggestions
        let suggestions = Tag.suggestTags(for: text, existingTags: [], context: context)
        
        // Should suggest capitalized frequent words
        XCTAssertTrue(suggestions.contains("Meeting"))
        XCTAssertTrue(suggestions.contains("Project"))
    }
    
    func testSuggestCategories() throws {
        // Text with category keywords
        let text = "Had a doctor appointment today about my health concerns."
        
        // Get suggestions
        let suggestions = Tag.suggestTags(for: text, existingTags: [], context: context)
        
        // Should suggest "Health" category
        XCTAssertTrue(suggestions.contains("Health"))
    }
    
    func testSuggestTagsFiltersShortWords() throws {
        // Text with short words
        let text = "A lot of an the to in on at by."
        
        // Get suggestions
        let suggestions = Tag.suggestTags(for: text, existingTags: [], context: context)
        
        // Should filter out short words and stop words
        XCTAssertTrue(suggestions.isEmpty)
    }
    
    func testSuggestTagsLimitsResults() throws {
        // Create many tags that would match
        for i in 1...20 {
            let _ = Tag.findOrCreate(name: "Tag\(i)", in: context)
        }
        let existingTags = Tag.fetchAll(in: context)
        
        // Text that would match all tags
        var text = ""
        for i in 1...20 {
            text += "tag\(i) "
        }
        
        // Get suggestions
        let suggestions = Tag.suggestTags(for: text, existingTags: existingTags, context: context)
        
        // Should limit suggestions (the exact number depends on implementation)
        XCTAssertLessThanOrEqual(suggestions.count, 8) // We set limit to 8 in the implementation
    }
    
    // MARK: - Color Tests
    
    func testSwiftUIColor() throws {
        // Create a tag with a color
        let tag = Tag.findOrCreate(name: "ColorTag", colorHex: "#FF5733", in: context)
        
        // Test that swiftUIColor property returns a Color
        let color = tag.swiftUIColor
        XCTAssertNotNil(color)
    }
    
    func testDefaultColor() throws {
        // Create a tag without specifying a color
        let tag = Tag.findOrCreate(name: "DefaultColorTag", in: context)
        
        // Should have a default color
        XCTAssertNotNil(tag.color)
        
        // swiftUIColor should not be nil
        XCTAssertNotNil(tag.swiftUIColor)
    }
    
    // MARK: - Icon Tests
    
    func testTagWithIcon() throws {
        // Create a tag
        let tag = Tag.findOrCreate(name: "IconTag", in: context)
        
        // Set an icon name
        tag.iconName = "star.fill"
        try context.save()
        
        // Verify icon name is saved
        XCTAssertEqual(tag.iconName, "star.fill")
    }
}
