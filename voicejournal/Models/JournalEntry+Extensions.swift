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
        entry.isBaseEncrypted = true // All entries are base encrypted by default
        return entry
    }
    
    // MARK: - Transient Properties
    
    // Property to track if encrypted content is currently decrypted (not persisted)
    private static var decryptedEntries = Set<NSManagedObjectID>()
    private static var baseDecryptedEntries = Set<NSManagedObjectID>()
    
    /// Returns true if the tag-encrypted content is currently decrypted and accessible
    var isDecrypted: Bool {
        guard self.hasEncryptedContent else { return false }
        return JournalEntry.decryptedEntries.contains(self.objectID)
    }
    
    /// Returns true if the base-encrypted content is currently decrypted and accessible
    var isBaseDecrypted: Bool {
        guard self.isBaseEncrypted else { return true } // If not base encrypted, consider it "decrypted"
        return JournalEntry.baseDecryptedEntries.contains(self.objectID)
    }
    
    /// Mark this entry as tag-decrypted
    func markAsDecrypted() {
        JournalEntry.decryptedEntries.insert(self.objectID)
    }
    
    /// Mark this entry as base-decrypted
    func markAsBaseDecrypted() {
        JournalEntry.baseDecryptedEntries.insert(self.objectID)
    }
    
    /// Mark this entry as tag-encrypted (clears decrypted status)
    func markAsEncrypted() {
        JournalEntry.decryptedEntries.remove(self.objectID)
    }
    
    /// Mark this entry as base-encrypted (clears base-decrypted status)
    func markAsBaseEncrypted() {
        JournalEntry.baseDecryptedEntries.remove(self.objectID)
    }
    
    /// Clear all decrypted entries (for app lock or session end)
    static func clearAllDecryptedEntries() {
        JournalEntry.decryptedEntries.removeAll()
        JournalEntry.baseDecryptedEntries.removeAll()
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
        
        // Auto-encrypt if base encryption is enabled
        if self.isBaseEncrypted {
            _ = applyBaseEncryption()
        }
        
        return recording
    }
    
    /// Create a new transcription for this journal entry
    func createTranscription(text: String) -> Transcription {
        let transcription = Transcription(context: managedObjectContext!)
        // Set raw text as the initial text and also save it separately
        transcription.text = text
        transcription.rawText = text
        transcription.enhancedText = nil // No enhanced text initially
        transcription.createdAt = Date()
        transcription.modifiedAt = Date()
        transcription.journalEntry = self
        self.transcription = transcription
        
        // Auto-encrypt if base encryption is enabled
        if self.isBaseEncrypted {
            _ = applyBaseEncryption()
        }
        
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
    
    /// Check if this entry has tag-encrypted content
    var hasEncryptedContent: Bool {
        return self.encryptedTag != nil
    }
    
    /// Check if this entry has any form of encryption (base or tag)
    var hasAnyEncryption: Bool {
        return self.isBaseEncrypted || self.hasEncryptedContent
    }
    
    /// Check if this entry needs both base-level and tag-level decryption
    var needsDualDecryption: Bool {
        return self.isBaseEncrypted && self.hasEncryptedContent
    }
    
    /// Apply an encrypted tag to this entry with PIN (deprecated - use applyEncryptedTagWithPin instead)
    /// This method is kept for backward compatibility but should not be used directly.
    @available(*, deprecated, message: "Use applyEncryptedTagWithPin instead")
    func applyEncryptedTag(_ tag: Tag) -> Bool {
        // Warning: Using deprecated applyEncryptedTag method without PIN
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
            // PIN verification failed for encrypted tag
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
            
            print("🔐 [JournalEntry] Starting audio encryption...")
            do {
                // Create a directory for encrypted files if it doesn't exist
                let fileManager = FileManager.default
                let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let encryptedDirectory = documentsDirectory.appendingPathComponent("EncryptedFiles", isDirectory: true)
                
                if !fileManager.fileExists(atPath: encryptedDirectory.path) {
                    try fileManager.createDirectory(at: encryptedDirectory, withIntermediateDirectories: true)
                }
                
                // Convert relative path to absolute path
                let absoluteURL = FilePathUtility.toAbsolutePath(from: filePath)
                let fileName = absoluteURL.lastPathComponent
                let encryptedFilePath = encryptedDirectory.appendingPathComponent("\(fileName).encrypted").path
                
                print("🔐 [JournalEntry] Reading audio file from: \(absoluteURL.path)")
                // Read the audio file data
                let audioData = try Data(contentsOf: absoluteURL)
                print("🔐 [JournalEntry] Audio data size: \(audioData.count) bytes")
                
                // Encrypt the data
                if let encryptedData = EncryptionManager.encrypt(audioData, using: key) {
                    print("🔐 [JournalEntry] Audio encrypted successfully, writing to: \(encryptedFilePath)")
                    // Write encrypted data to the encrypted file path
                    try encryptedData.write(to: URL(fileURLWithPath: encryptedFilePath))
                    
                    // Store original path in a separate attribute for later
                    audioRecording.originalFilePath = filePath
                    
                    // Update file path to point to encrypted file
                    audioRecording.filePath = encryptedFilePath
                    audioRecording.isEncrypted = true
                    print("✅ [JournalEntry] Audio encryption completed successfully")
                } else {
                    encryptionSuccess = false
                    print("❌ [JournalEntry] Failed to encrypt audio data")
                }
            } catch {
                // Error occurred
                encryptionSuccess = false
                print("❌ [JournalEntry] Audio encryption error: \(error)")
            }
        } else {
            print("⚠️ [JournalEntry] No audio recording to encrypt")
        }
        
        // Encrypt the transcription if it exists
        if let transcription = self.transcription {
            print("🔐 [JournalEntry] Starting transcription encryption...")
            
            // Encrypt main text
            if let text = transcription.text {
                print("🔐 [JournalEntry] Encrypting main text (\(text.count) characters)")
                if let encryptedData = EncryptionManager.encrypt(text, using: key) {
                    transcription.encryptedText = encryptedData
                    transcription.text = nil
                    print("✅ [JournalEntry] Main text encrypted successfully")
                } else {
                    encryptionSuccess = false
                    print("❌ [JournalEntry] Failed to encrypt main text")
                }
            } else {
                print("⚠️ [JournalEntry] No main text to encrypt")
            }
            
            // Encrypt raw text
            if let rawText = transcription.rawText {
                print("🔐 [JournalEntry] Encrypting raw text (\(rawText.count) characters)")
                if let encryptedData = EncryptionManager.encrypt(rawText, using: key) {
                    transcription.encryptedRawText = encryptedData
                    transcription.rawText = nil
                    print("✅ [JournalEntry] Raw text encrypted successfully")
                } else {
                    encryptionSuccess = false
                    print("❌ [JournalEntry] Failed to encrypt raw text")
                }
            } else {
                print("⚠️ [JournalEntry] No raw text to encrypt")
            }
            
            // Encrypt enhanced text
            if let enhancedText = transcription.enhancedText {
                print("🔐 [JournalEntry] Encrypting enhanced text (\(enhancedText.count) characters)")
                if let encryptedData = EncryptionManager.encrypt(enhancedText, using: key) {
                    transcription.encryptedEnhancedText = encryptedData
                    transcription.enhancedText = nil
                    print("✅ [JournalEntry] Enhanced text encrypted successfully")
                } else {
                    encryptionSuccess = false
                    print("❌ [JournalEntry] Failed to encrypt enhanced text")
                }
            } else {
                print("⚠️ [JournalEntry] No enhanced text to encrypt")
            }
            
            // Encrypt AI analysis
            if let aiAnalysis = transcription.aiAnalysis {
                print("🔐 [JournalEntry] Encrypting AI analysis (\(aiAnalysis.count) characters)")
                if let encryptedData = EncryptionManager.encrypt(aiAnalysis, using: key) {
                    transcription.encryptedAIAnalysis = encryptedData
                    transcription.aiAnalysis = nil
                    print("✅ [JournalEntry] AI analysis encrypted successfully")
                } else {
                    encryptionSuccess = false
                    print("❌ [JournalEntry] Failed to encrypt AI analysis")
                }
            } else {
                print("⚠️ [JournalEntry] No AI analysis to encrypt")
            }
            
            transcription.modifiedAt = Date()
            print("🔐 [JournalEntry] Transcription encryption completed. Success: \(encryptionSuccess)")
        } else {
            print("⚠️ [JournalEntry] No transcription to encrypt")
        }
        
        // Mark as encrypted
        markAsEncrypted()
        
        self.modifiedAt = Date()
        try? self.managedObjectContext?.save()
        
        print("🔐 [JournalEntry] Overall encryption result: \(encryptionSuccess)")
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
                // Error occurred
                decryptionSuccess = false
            }
        }
        
        // Decrypt the transcription if it exists and is encrypted
        if let transcription = self.transcription {
            print("🔓 [JournalEntry] Starting transcription decryption...")
            
            // Decrypt main text
            if let encryptedData = transcription.encryptedText,
               transcription.text == nil {
                print("🔓 [JournalEntry] Decrypting main text (\(encryptedData.count) bytes)")
                if let decryptedText = EncryptionManager.decryptToString(encryptedData, using: key) {
                    transcription.text = decryptedText
                    print("✅ [JournalEntry] Main text decrypted successfully (\(decryptedText.count) characters)")
                } else {
                    decryptionSuccess = false
                    print("❌ [JournalEntry] Failed to decrypt main text")
                }
            } else {
                print("⚠️ [JournalEntry] No encrypted main text or already decrypted")
            }
            
            // Decrypt raw text
            if let encryptedData = transcription.encryptedRawText,
               transcription.rawText == nil {
                print("🔓 [JournalEntry] Decrypting raw text (\(encryptedData.count) bytes)")
                if let decryptedText = EncryptionManager.decryptToString(encryptedData, using: key) {
                    transcription.rawText = decryptedText
                    print("✅ [JournalEntry] Raw text decrypted successfully (\(decryptedText.count) characters)")
                } else {
                    decryptionSuccess = false
                    print("❌ [JournalEntry] Failed to decrypt raw text")
                }
            } else {
                print("⚠️ [JournalEntry] No encrypted raw text or already decrypted")
            }
            
            // Decrypt enhanced text
            if let encryptedData = transcription.encryptedEnhancedText,
               transcription.enhancedText == nil {
                print("🔓 [JournalEntry] Decrypting enhanced text (\(encryptedData.count) bytes)")
                if let decryptedText = EncryptionManager.decryptToString(encryptedData, using: key) {
                    transcription.enhancedText = decryptedText
                    print("✅ [JournalEntry] Enhanced text decrypted successfully (\(decryptedText.count) characters)")
                } else {
                    decryptionSuccess = false
                    print("❌ [JournalEntry] Failed to decrypt enhanced text")
                }
            } else {
                print("⚠️ [JournalEntry] No encrypted enhanced text or already decrypted. Enhanced text exists: \(transcription.enhancedText != nil)")
            }
            
            // Decrypt AI analysis
            if let encryptedData = transcription.encryptedAIAnalysis,
               transcription.aiAnalysis == nil {
                print("🔓 [JournalEntry] Decrypting AI analysis (\(encryptedData.count) bytes)")
                if let decryptedText = EncryptionManager.decryptToString(encryptedData, using: key) {
                    transcription.aiAnalysis = decryptedText
                    print("✅ [JournalEntry] AI analysis decrypted successfully (\(decryptedText.count) characters)")
                } else {
                    decryptionSuccess = false
                    print("❌ [JournalEntry] Failed to decrypt AI analysis")
                }
            } else {
                print("⚠️ [JournalEntry] No encrypted AI analysis or already decrypted. AI analysis exists: \(transcription.aiAnalysis != nil)")
            }
            
            print("🔓 [JournalEntry] Transcription decryption completed. Success: \(decryptionSuccess)")
        } else {
            print("⚠️ [JournalEntry] No transcription to decrypt")
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
    
    // MARK: - Base Encryption
    
    /// Apply base encryption to this entry
    func applyBaseEncryption() -> Bool {
        guard !self.isBaseEncrypted else { return true } // Already base encrypted
        
        let key = EncryptionManager.getEncryptionKey()
        guard let rootKey = key else { return false }
        
        var encryptionSuccess = true
        
        // Encrypt the audio recording if it exists
        if let audioRecording = self.audioRecording,
           let filePath = audioRecording.filePath,
           !audioRecording.isEncrypted { // Don't double-encrypt
            
            do {
                // Create a directory for base encrypted files if it doesn't exist
                let fileManager = FileManager.default
                let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let baseEncryptedDirectory = documentsDirectory.appendingPathComponent("BaseEncrypted", isDirectory: true)
                
                if !fileManager.fileExists(atPath: baseEncryptedDirectory.path) {
                    try fileManager.createDirectory(at: baseEncryptedDirectory, withIntermediateDirectories: true)
                }
                
                // Construct encrypted file path
                let originalURL = URL(fileURLWithPath: filePath)
                let fileName = originalURL.lastPathComponent
                let encryptedFilePath = baseEncryptedDirectory.appendingPathComponent("\(fileName).baseenc").path
                
                // Read the audio file data
                let audioData = try Data(contentsOf: originalURL)
                
                // Encrypt the data
                if let encryptedData = EncryptionManager.encrypt(audioData, using: rootKey) {
                    // Write encrypted data to the encrypted file path
                    try encryptedData.write(to: URL(fileURLWithPath: encryptedFilePath))
                    
                    // Store original path and encrypted path
                    if audioRecording.originalFilePath == nil {
                        audioRecording.originalFilePath = filePath
                    }
                    self.baseEncryptedAudioPath = encryptedFilePath
                    
                    // Update file path to point to encrypted file
                    audioRecording.filePath = encryptedFilePath
                } else {
                    encryptionSuccess = false
                }
            } catch {
                // Error occurred
                encryptionSuccess = false
            }
        }
        
        // Encrypt the transcription if it exists
        if let transcription = self.transcription {
            // Encrypt main text
            if let text = transcription.text,
               transcription.encryptedText == nil {
                if let encryptedData = EncryptionManager.encrypt(text, using: rootKey) {
                    transcription.encryptedText = encryptedData
                    transcription.text = nil
                } else {
                    encryptionSuccess = false
                }
            }
            
            // Encrypt raw text for base encryption
            if let rawText = transcription.rawText,
               transcription.encryptedRawText == nil {
                if let encryptedData = EncryptionManager.encrypt(rawText, using: rootKey) {
                    transcription.encryptedRawText = encryptedData
                    transcription.rawText = nil
                } else {
                    encryptionSuccess = false
                }
            }
            
            // Encrypt enhanced text for base encryption
            if let enhancedText = transcription.enhancedText,
               transcription.encryptedEnhancedText == nil {
                if let encryptedData = EncryptionManager.encrypt(enhancedText, using: rootKey) {
                    transcription.encryptedEnhancedText = encryptedData
                    transcription.enhancedText = nil
                } else {
                    encryptionSuccess = false
                }
            }
            
            // Encrypt AI analysis for base encryption
            if let aiAnalysis = transcription.aiAnalysis,
               transcription.encryptedAIAnalysis == nil {
                if let encryptedData = EncryptionManager.encrypt(aiAnalysis, using: rootKey) {
                    transcription.encryptedAIAnalysis = encryptedData
                    transcription.aiAnalysis = nil
                } else {
                    encryptionSuccess = false
                }
            }
            
            transcription.modifiedAt = Date()
        }
        
        // Mark as base encrypted
        if encryptionSuccess {
            self.isBaseEncrypted = true
            markAsBaseEncrypted()
        }
        
        self.modifiedAt = Date()
        try? self.managedObjectContext?.save()
        
        return encryptionSuccess
    }
    
    /// Decrypt base-encrypted content with app's root key
    func decryptBaseContent() -> Bool {
        guard self.isBaseEncrypted else { return true } // Not base encrypted
        
        let key = EncryptionManager.getEncryptionKey()
        guard let rootKey = key else { return false }
        
        var decryptionSuccess = true
        
        // Decrypt the audio recording if it exists and encrypted path is stored
        if let audioRecording = self.audioRecording,
           let encryptedFilePath = self.baseEncryptedAudioPath {
            
            do {
                // Read the encrypted file
                let encryptedData = try Data(contentsOf: URL(fileURLWithPath: encryptedFilePath))
                
                // Create a directory for temporary decrypted files
                let fileManager = FileManager.default
                let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let tempDirectory = documentsDirectory.appendingPathComponent("BaseTempDecrypted", isDirectory: true)
                
                if !fileManager.fileExists(atPath: tempDirectory.path) {
                    try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
                }
                
                // Generate a unique temporary file path
                let tempFilePath = tempDirectory.appendingPathComponent(UUID().uuidString + ".m4a").path
                
                // Decrypt the data
                if let decryptedData = EncryptionManager.decrypt(encryptedData, using: rootKey) {
                    // Write decrypted data to temporary file
                    try decryptedData.write(to: URL(fileURLWithPath: tempFilePath))
                    
                    // Store temporary path in memory (not persisted)
                    audioRecording.tempDecryptedPath = tempFilePath
                } else {
                    decryptionSuccess = false
                }
            } catch {
                // Error occurred
                decryptionSuccess = false
            }
        }
        
        // Decrypt the transcription if it exists and is encrypted
        if let transcription = self.transcription {
            // Decrypt main text
            if let encryptedData = transcription.encryptedText,
               transcription.text == nil {
                if let decryptedText = EncryptionManager.decryptToString(encryptedData, using: rootKey) {
                    transcription.text = decryptedText
                } else {
                    decryptionSuccess = false
                }
            }
            
            // Decrypt raw text
            if let encryptedData = transcription.encryptedRawText,
               transcription.rawText == nil {
                if let decryptedText = EncryptionManager.decryptToString(encryptedData, using: rootKey) {
                    transcription.rawText = decryptedText
                } else {
                    decryptionSuccess = false
                }
            }
            
            // Decrypt enhanced text
            if let encryptedData = transcription.encryptedEnhancedText,
               transcription.enhancedText == nil {
                if let decryptedText = EncryptionManager.decryptToString(encryptedData, using: rootKey) {
                    transcription.enhancedText = decryptedText
                } else {
                    decryptionSuccess = false
                }
            }
            
            // Decrypt AI analysis
            if let encryptedData = transcription.encryptedAIAnalysis,
               transcription.aiAnalysis == nil {
                if let decryptedText = EncryptionManager.decryptToString(encryptedData, using: rootKey) {
                    transcription.aiAnalysis = decryptedText
                } else {
                    decryptionSuccess = false
                }
            }
        }
        
        if decryptionSuccess {
            // Mark as base decrypted for access control
            markAsBaseDecrypted()
        }
        
        return decryptionSuccess
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
            // Error occurred
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
            // Error occurred
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
            // Error occurred
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
            // Error occurred
            return []
        }
    }
    
    // Fetch journal entries with tag-based encrypted content
    static func fetchEncrypted(in context: NSManagedObjectContext) -> [JournalEntry] {
        let request: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        request.predicate = NSPredicate(format: "encryptedTag != nil")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \JournalEntry.createdAt, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            // Error occurred
            return []
        }
    }
    
    // Fetch journal entries with base encryption
    static func fetchBaseEncrypted(in context: NSManagedObjectContext) -> [JournalEntry] {
        let request: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        request.predicate = NSPredicate(format: "isBaseEncrypted == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \JournalEntry.createdAt, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            // Error occurred
            return []
        }
    }
    
    // Fetch journal entries with any type of encryption (base or tag)
    static func fetchAnyEncrypted(in context: NSManagedObjectContext) -> [JournalEntry] {
        let request: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        request.predicate = NSPredicate(format: "encryptedTag != nil OR isBaseEncrypted == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \JournalEntry.createdAt, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            // Error occurred
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
            // Error occurred
            return []
        }
    }
}