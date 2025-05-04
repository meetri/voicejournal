//
//  JournalEntry+Extensions.swift
//  voicejournal
//
//  Created on 4/27/25.
//

import Foundation
import CoreData
import CryptoKit

extension JournalEntry {
    // MARK: - Creation and Basic Operations
    
    /// Convenience initializer for creating a new journal entry
    static func create(in context: NSManagedObjectContext) -> JournalEntry {
        let entry = JournalEntry(context: context)
        entry.createdAt = Date()
        entry.modifiedAt = Date()
        entry.isLocked = false
        return entry
    }
    
    // MARK: - Transient Properties
    
    // Property to track if encrypted content is currently decrypted (not persisted)
    private static var decryptedEntries = Set<NSManagedObjectID>()
    
    /// Returns true if the content is currently decrypted and accessible
    var isDecrypted: Bool {
        guard self.hasEncryptedContent else { return false }
        return JournalEntry.decryptedEntries.contains(self.objectID)
    }
    
    /// Mark this entry as decrypted
    func markAsDecrypted() {
        JournalEntry.decryptedEntries.insert(self.objectID)
    }
    
    /// Mark this entry as encrypted (clears decrypted status)
    func markAsEncrypted() {
        JournalEntry.decryptedEntries.remove(self.objectID)
    }
    
    /// Clear all decrypted entries (for app lock or session end)
    static func clearAllDecryptedEntries() {
        JournalEntry.decryptedEntries.removeAll()
    }
    
    /// Save changes to the journal entry
    func save() throws {
        modifiedAt = Date()
        try managedObjectContext?.save()
    }
    
    // MARK: - Related Entity Creation
    
    /// Create a new audio recording for this journal entry
    func createAudioRecording(filePath: String) -> AudioRecording {
        let recording = AudioRecording(context: managedObjectContext!)
        recording.filePath = filePath
        recording.recordedAt = Date()
        recording.journalEntry = self
        self.audioRecording = recording
        return recording
    }
    
    /// Create a new transcription for this journal entry
    func createTranscription(text: String) -> Transcription {
        let transcription = Transcription(context: managedObjectContext!)
        transcription.text = text
        transcription.createdAt = Date()
        transcription.modifiedAt = Date()
        transcription.journalEntry = self
        self.transcription = transcription
        return transcription
    }
    
    // MARK: - Tag Management
    
    /// Add a tag to this journal entry
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
            tag.isEncrypted = false
        }
        
        // Add relationship
        self.addToTags(tag)
        
        return tag
    }
    
    /// Remove a tag from this journal entry
    func removeTag(_ tag: Tag) {
        // If it's the encrypted tag, use proper removal method
        if let encryptedTag = self.encryptedTag, encryptedTag == tag {
            self.removeEncryptedTag()
        }
        
        self.removeFromTags(tag)
    }
    
    /// Generate a random color for tags
    private func generateRandomColor() -> String {
        let colors = ["#FF5733", "#33FF57", "#3357FF", "#F3FF33", "#FF33F3", "#33FFF3", "#FF8033", "#8033FF"]
        return colors.randomElement() ?? "#FF5733"
    }
    
    // MARK: - Encryption & Security
    
    /// Check if this entry has encrypted content
    var hasEncryptedContent: Bool {
        return self.encryptedTag != nil
    }
    
    /// Apply an encrypted tag to this entry with PIN (deprecated - use applyEncryptedTagWithPin instead)
    /// This method is kept for backward compatibility but should not be used directly.
    @available(*, deprecated, message: "Use applyEncryptedTagWithPin instead")
    func applyEncryptedTag(_ tag: Tag) -> Bool {
        print("Warning: Using deprecated applyEncryptedTag method without PIN. Content will not be encrypted.")
        guard tag.isEncrypted else { return false }
        
        // Add the tag to the regular tags collection if not already there
        if !self.tags!.contains(tag) {
            self.addToTags(tag)
        }
        
        // Set as the encrypted tag (this automatically updates the inverse relationship)
        self.encryptedTag = tag
        
        // Manually add to the tag's encryptedEntries set to ensure the relationship
        // is properly established in both directions
        tag.addToEncryptedEntries(self)
        
        self.modifiedAt = Date()
        
        try? self.managedObjectContext?.save()
        return true
    }
    
    /// Apply an encrypted tag to this entry with PIN and immediately encrypt the content
    func applyEncryptedTagWithPin(_ tag: Tag, pin: String) -> Bool {
        guard tag.isEncrypted else { return false }
        
        // Verify the PIN first
        guard tag.verifyPin(pin) else {
            print("PIN verification failed for encrypted tag")
            return false
        }
        
        // Add the tag to the regular tags collection if not already there
        if !self.tags!.contains(tag) {
            self.addToTags(tag)
        }
        
        // Set as the encrypted tag (this automatically updates the inverse relationship)
        self.encryptedTag = tag
        
        // Manually add to the tag's encryptedEntries set to ensure the relationship
        // is properly established in both directions
        tag.addToEncryptedEntries(self)
        
        self.modifiedAt = Date()
        
        // Save the relationship changes
        try? self.managedObjectContext?.save()
        
        // Now encrypt the content using the provided PIN
        return encryptContent(withPin: pin)
    }
    
    /// Remove the encrypted tag from this entry
    func removeEncryptedTag() {
        // Store reference to current encrypted tag before removing it
        if let currentTag = self.encryptedTag {
            // Remove this entry from the tag's encryptedEntries
            currentTag.removeFromEncryptedEntries(self)
            
            // Now clear the reference
            self.encryptedTag = nil
        }
        
        self.modifiedAt = Date()
        
        try? self.managedObjectContext?.save()
    }
    
    /// Encrypt this entry's content with the encrypted tag's key
    func encryptContent(withPin pin: String) -> Bool {
        guard let encryptedTag = self.encryptedTag,
              let key = encryptedTag.getEncryptionKey(with: pin) else {
            return false
        }
        
        var encryptionSuccess = true
        
        // Encrypt the audio recording if it exists
        if let audioRecording = self.audioRecording,
           let filePath = audioRecording.filePath {
            
            do {
                // Create a directory for encrypted files if it doesn't exist
                let fileManager = FileManager.default
                let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let encryptedDirectory = documentsDirectory.appendingPathComponent("EncryptedFiles", isDirectory: true)
                
                if !fileManager.fileExists(atPath: encryptedDirectory.path) {
                    try fileManager.createDirectory(at: encryptedDirectory, withIntermediateDirectories: true)
                }
                
                // Construct encrypted file path
                let originalURL = URL(fileURLWithPath: filePath)
                let fileName = originalURL.lastPathComponent
                let encryptedFilePath = encryptedDirectory.appendingPathComponent("\(fileName).encrypted").path
                
                // Read the audio file data
                let audioData = try Data(contentsOf: originalURL)
                
                // Encrypt the data
                if let encryptedData = EncryptionManager.encrypt(audioData, using: key) {
                    // Write encrypted data to the encrypted file path
                    try encryptedData.write(to: URL(fileURLWithPath: encryptedFilePath))
                    
                    // Store original path in a separate attribute for later
                    audioRecording.originalFilePath = filePath
                    
                    // Update file path to point to encrypted file
                    audioRecording.filePath = encryptedFilePath
                    audioRecording.isEncrypted = true
                } else {
                    encryptionSuccess = false
                }
            } catch {
                print("Error encrypting audio file: \(error)")
                encryptionSuccess = false
            }
        }
        
        // Encrypt the transcription if it exists
        if let transcription = self.transcription,
           let text = transcription.text {
            
            if let encryptedData = EncryptionManager.encrypt(text, using: key) {
                // Store encrypted data and clear plaintext
                transcription.encryptedText = encryptedData
                transcription.text = nil
                transcription.modifiedAt = Date()
            } else {
                encryptionSuccess = false
            }
        }
        
        // Mark as encrypted
        markAsEncrypted()
        
        self.modifiedAt = Date()
        try? self.managedObjectContext?.save()
        
        return encryptionSuccess
    }
    
    /// Decrypt this entry's content with the encrypted tag's key
    func decryptContent(withPin pin: String) -> Bool {
        guard let encryptedTag = self.encryptedTag,
              let key = encryptedTag.getEncryptionKey(with: pin) else {
            return false
        }
        
        var decryptionSuccess = true
        
        // Decrypt the audio recording if it exists and is encrypted
        if let audioRecording = self.audioRecording,
           let encryptedFilePath = audioRecording.filePath,
           audioRecording.isEncrypted == true {
            
            do {
                // Read the encrypted file
                let encryptedData = try Data(contentsOf: URL(fileURLWithPath: encryptedFilePath))
                
                // Create a directory for temporary decrypted files
                let fileManager = FileManager.default
                let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let tempDirectory = documentsDirectory.appendingPathComponent("TempDecrypted", isDirectory: true)
                
                if !fileManager.fileExists(atPath: tempDirectory.path) {
                    try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
                }
                
                // Generate a unique temporary file path
                let tempFilePath = tempDirectory.appendingPathComponent(UUID().uuidString + ".m4a").path
                
                // Decrypt the data
                if let decryptedData = EncryptionManager.decrypt(encryptedData, using: key) {
                    // Write decrypted data to temporary file
                    try decryptedData.write(to: URL(fileURLWithPath: tempFilePath))
                    
                    // Store temporary path in memory (not persisted)
                    audioRecording.tempDecryptedPath = tempFilePath
                } else {
                    decryptionSuccess = false
                }
            } catch {
                print("Error decrypting audio file: \(error)")
                decryptionSuccess = false
            }
        }
        
        // Decrypt the transcription if it exists and is encrypted
        if let transcription = self.transcription,
           let encryptedData = transcription.encryptedText,
           transcription.text == nil {
            
            if let decryptedText = EncryptionManager.decryptToString(encryptedData, using: key) {
                // Store decrypted text temporarily (in memory)
                transcription.text = decryptedText
            } else {
                decryptionSuccess = false
            }
        }
        
        if decryptionSuccess {
            // Mark as decrypted for access control
            markAsDecrypted()
        }
        
        return decryptionSuccess
    }
    
    /// Lock the journal entry
    func lock() {
        self.isLocked = true
        try? save()
    }
    
    /// Unlock the journal entry
    func unlock() {
        self.isLocked = false
        try? save()
    }
}

// MARK: - Additional Property Extensions

// Note: 'encryptedText' property is defined in the Core Data model
// and will be generated automatically in Transcription+CoreDataProperties.swift
// extension Transcription {
//     /// Property to store encrypted text data
//     @NSManaged var encryptedText: Data?
// }

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
    
    // Fetch journal entries with encrypted content
    static func fetchEncrypted(in context: NSManagedObjectContext) -> [JournalEntry] {
        let request: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        request.predicate = NSPredicate(format: "encryptedTag != nil")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \JournalEntry.createdAt, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching encrypted journal entries: \(error)")
            return []
        }
    }
    
    // Fetch journal entries with a specific encrypted tag
    static func fetch(withEncryptedTag tag: Tag, in context: NSManagedObjectContext) -> [JournalEntry] {
        let request: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        request.predicate = NSPredicate(format: "encryptedTag == %@", tag)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \JournalEntry.createdAt, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching journal entries with encrypted tag: \(error)")
            return []
        }
    }
}