//
//  JournalEntry+Extensions.swift
//  voicejournal
//
//  Created on 4/27/25.
//

import Foundation
import CoreData

extension JournalEntry {
    // Convenience initializer for creating a new journal entry
    static func create(in context: NSManagedObjectContext) -> JournalEntry {
        let entry = JournalEntry(context: context)
        entry.createdAt = Date()
        entry.modifiedAt = Date()
        entry.isLocked = false
        return entry
    }
    
    // Save changes to the journal entry
    func save() throws {
        modifiedAt = Date()
        try managedObjectContext?.save()
    }
    
    // Create a new audio recording for this journal entry
    func createAudioRecording(filePath: String) -> AudioRecording {
        let recording = AudioRecording(context: managedObjectContext!)
        recording.filePath = filePath
        recording.recordedAt = Date()
        recording.journalEntry = self
        self.audioRecording = recording
        return recording
    }
    
    // Create a new transcription for this journal entry
    func createTranscription(text: String) -> Transcription {
        let transcription = Transcription(context: managedObjectContext!)
        transcription.text = text
        transcription.createdAt = Date()
        transcription.modifiedAt = Date()
        transcription.journalEntry = self
        self.transcription = transcription
        return transcription
    }
    
    // Add a tag to this journal entry
    func addTag(_ tagName: String, color: String? = nil) -> Tag {
        // Check if tag already exists
        let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", tagName)
        
        var tag: Tag
        
        if let existingTag = try? managedObjectContext?.fetch(fetchRequest).first {
            tag = existingTag
        } else {
            // Create new tag
            tag = Tag(context: managedObjectContext!)
            tag.name = tagName
            tag.color = color ?? generateRandomColor()
            tag.createdAt = Date()
        }
        
        // Add relationship
        self.addToTags(tag)
        
        return tag
    }
    
    // Remove a tag from this journal entry
    func removeTag(_ tag: Tag) {
        self.removeFromTags(tag)
    }
    
    // Generate a random color for tags
    private func generateRandomColor() -> String {
        let colors = ["#FF5733", "#33FF57", "#3357FF", "#F3FF33", "#FF33F3", "#33FFF3", "#FF8033", "#8033FF"]
        return colors.randomElement() ?? "#FF5733"
    }
    
    // Lock the journal entry
    func lock() {
        self.isLocked = true
        try? save()
    }
    
    // Unlock the journal entry
    func unlock() {
        self.isLocked = false
        try? save()
    }
}

// MARK: - Fetch Requests

extension JournalEntry {
    // Fetch all journal entries
    static func fetchAll(in context: NSManagedObjectContext) -> [JournalEntry] {
        let request: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \JournalEntry.createdAt, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching journal entries: \(error)")
            return []
        }
    }
    
    // Fetch journal entries with a specific tag
    static func fetch(withTag tagName: String, in context: NSManagedObjectContext) -> [JournalEntry] {
        let request: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        request.predicate = NSPredicate(format: "ANY tags.name == %@", tagName)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \JournalEntry.createdAt, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching journal entries with tag: \(error)")
            return []
        }
    }
    
    // Fetch journal entries created on a specific date
    static func fetch(onDate date: Date, in context: NSManagedObjectContext) -> [JournalEntry] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let request: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        request.predicate = NSPredicate(format: "createdAt >= %@ AND createdAt < %@", startOfDay as NSDate, endOfDay as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \JournalEntry.createdAt, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching journal entries by date: \(error)")
            return []
        }
    }
    
    // Search journal entries by title or transcription text
    static func search(query: String, in context: NSManagedObjectContext) -> [JournalEntry] {
        let request: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        request.predicate = NSPredicate(format: "title CONTAINS[cd] %@ OR transcription.text CONTAINS[cd] %@", query, query)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \JournalEntry.createdAt, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error searching journal entries: \(error)")
            return []
        }
    }
}
