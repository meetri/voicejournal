//
//  EncryptedTagsAccessManager.swift
//  voicejournal
//
//  Created on 5/4/25.
//

import Foundation
import CoreData
import CryptoKit
import Combine

/// A service that manages global access to encrypted tags.
/// This class maintains a set of tags that have been granted access 
/// and provides methods to grant and revoke access.
class EncryptedTagsAccessManager: ObservableObject {
    // MARK: - Published Properties
    
    /// Set of tag IDs that have been granted global access
    @Published private(set) var grantedTagIDs: Set<String> = []
    
    /// Encryption keys for the granted tags, keyed by tag ID
    private var encryptionKeys: [String: SymmetricKey] = [:]
    
    // MARK: - Singleton Instance
    
    /// Shared instance of the encrypted tags access manager
    static let shared = EncryptedTagsAccessManager()
    
    // MARK: - Initialization
    
    private init() {
        // Private initializer to enforce singleton pattern
    }
    
    // MARK: - Public Methods
    
    /// Grant global access to a tag with the given PIN
    /// - Parameters:
    ///   - tag: The encrypted tag to grant access to
    ///   - pin: The PIN for the tag
    /// - Returns: True if access was granted, false otherwise
    func grantAccess(to tag: Tag, with pin: String) -> Bool {
        guard tag.isEncrypted, tag.verifyPin(pin) else {
            return false
        }
        
        // Get the tag's unique identifier
        guard let tagID = tag.encryptionKeyIdentifier else {
            return false
        }
        
        // Get the tag's encryption key
        guard let key = tag.getEncryptionKey(with: pin) else {
            return false
        }
        
        // Store the encryption key
        encryptionKeys[tagID] = key
        
        // Add the tag ID to the set of granted tags
        grantedTagIDs.insert(tagID)
        
        // Notify observers of the change
        objectWillChange.send()
        
        return true
    }
    
    /// Revoke global access to a tag
    /// - Parameter tag: The encrypted tag to revoke access from
    func revokeAccess(from tag: Tag) {
        guard let tagID = tag.encryptionKeyIdentifier else {
            return
        }
        
        // Remove the encryption key
        encryptionKeys.removeValue(forKey: tagID)
        
        // Remove the tag ID from the set of granted tags
        grantedTagIDs.remove(tagID)
        
        // Notify observers of the change
        objectWillChange.send()
    }
    
    /// Check if a tag has been granted global access
    /// - Parameter tag: The encrypted tag to check
    /// - Returns: True if the tag has been granted global access, false otherwise
    func hasAccess(to tag: Tag) -> Bool {
        guard let tagID = tag.encryptionKeyIdentifier else {
            return false
        }
        
        return grantedTagIDs.contains(tagID)
    }
    
    /// Get the encryption key for a tag that has been granted global access
    /// - Parameter tag: The encrypted tag to get the key for
    /// - Returns: The encryption key if access has been granted, nil otherwise
    func getEncryptionKey(for tag: Tag) -> SymmetricKey? {
        guard let tagID = tag.encryptionKeyIdentifier else {
            return nil
        }
        
        return encryptionKeys[tagID]
    }
    
    /// Clear all granted access (used when app is locked or closed)
    func clearAllAccess() {
        encryptionKeys.removeAll()
        grantedTagIDs.removeAll()
        objectWillChange.send()
    }
}

// MARK: - Tag Extension for Convenience Access

extension Tag {
    /// Check if this tag has been granted global access
    var hasGlobalAccess: Bool {
        return EncryptedTagsAccessManager.shared.hasAccess(to: self)
    }
    
    /// Get the encryption key for this tag using global access
    var globalAccessKey: SymmetricKey? {
        return EncryptedTagsAccessManager.shared.getEncryptionKey(for: self)
    }
}

// MARK: - JournalEntry Extension for Convenience Access

extension JournalEntry {
    /// Check if this entry's encrypted tag has been granted global access
    var hasGlobalAccess: Bool {
        guard let encryptedTag = self.encryptedTag else {
            return false
        }
        
        return encryptedTag.hasGlobalAccess
    }
    
    /// Decrypt this entry's content using global access
    /// - Returns: True if decryption succeeded, false otherwise
    func decryptWithGlobalAccess() -> Bool {
        guard let encryptedTag = self.encryptedTag else {
            print("🔐 [JournalEntry.decryptWithGlobalAccess] No encrypted tag found")
            return false
        }
        
        print("🔐 [JournalEntry.decryptWithGlobalAccess] Attempting to decrypt entry with tag '\(encryptedTag.name ?? "Unknown")'")
        
        // First check if we have the key from the access manager (temporary access)
        var key: SymmetricKey? = EncryptedTagsAccessManager.shared.getEncryptionKey(for: encryptedTag)
        if key != nil {
            print("🔐 [JournalEntry.decryptWithGlobalAccess] Found key in EncryptedTagsAccessManager")
        }
        
        // Fallback to global access key if available
        if key == nil {
            key = encryptedTag.globalAccessKey
            if key != nil {
                print("🔐 [JournalEntry.decryptWithGlobalAccess] Found globalAccessKey on tag")
            }
        }
        
        guard let encryptionKey = key else {
            print("❌ [JournalEntry.decryptWithGlobalAccess] No encryption key available for tag '\(encryptedTag.name ?? "Unknown")'")
            print("  - Key in EncryptedTagsAccessManager: \(EncryptedTagsAccessManager.shared.getEncryptionKey(for: encryptedTag) != nil)")
            print("  - Global access key on tag: \(encryptedTag.globalAccessKey != nil)")
            print("  - Tag has global access: \(encryptedTag.hasGlobalAccess)")
            return false
        }
        
        print("✅ [JournalEntry.decryptWithGlobalAccess] Encryption key found")
        
        var decryptionSuccess = true
        
        // Decrypt the audio recording if it exists and is encrypted
        if let audioRecording = self.audioRecording,
           let encryptedFilePath = audioRecording.filePath,
           audioRecording.isEncrypted == true {
            
            print("🔐 [JournalEntry.decryptWithGlobalAccess] Starting audio decryption...")
            print("  - Encrypted file path: \(encryptedFilePath)")
            print("  - Is encrypted: \(audioRecording.isEncrypted)")
            
            do {
                // Convert relative path to absolute path
                let absoluteEncryptedURL = FilePathUtility.toAbsolutePath(from: encryptedFilePath)
                print("🔐 [JournalEntry.decryptWithGlobalAccess] Reading encrypted file from: \(absoluteEncryptedURL.path)")
                let encryptedData = try Data(contentsOf: absoluteEncryptedURL)
                print("  - Encrypted data size: \(encryptedData.count) bytes")
                
                // Create a directory for temporary decrypted files
                let fileManager = FileManager.default
                let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let tempDirectory = documentsDirectory.appendingPathComponent("TempDecrypted", isDirectory: true)
                
                if !fileManager.fileExists(atPath: tempDirectory.path) {
                    try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
                    print("  - Created temp directory: \(tempDirectory.path)")
                }
                
                // Generate a unique temporary file path
                let tempFilePath = tempDirectory.appendingPathComponent(UUID().uuidString + ".m4a").path
                print("  - Temp file path: \(tempFilePath)")
                
                // Decrypt the data
                if let decryptedData = EncryptionManager.decrypt(encryptedData, using: encryptionKey) {
                    // Write decrypted data to temporary file
                    try decryptedData.write(to: URL(fileURLWithPath: tempFilePath))
                    print("✅ [JournalEntry.decryptWithGlobalAccess] Audio decrypted and written to: \(tempFilePath)")
                    
                    // Store temporary path in memory (not persisted)
                    audioRecording.tempDecryptedPath = tempFilePath
                } else {
                    print("❌ [JournalEntry.decryptWithGlobalAccess] Failed to decrypt audio data")
                    decryptionSuccess = false
                }
            } catch {
                print("❌ [JournalEntry.decryptWithGlobalAccess] Error during audio decryption: \(error)")
                decryptionSuccess = false
            }
        } else {
            print("⚠️ [JournalEntry.decryptWithGlobalAccess] No audio to decrypt or not encrypted")
            if let audioRecording = self.audioRecording {
                print("  - Audio exists: true")
                print("  - File path: \(audioRecording.filePath ?? "nil")")
                print("  - Is encrypted: \(audioRecording.isEncrypted)")
            }
        }
        
        // Decrypt the transcription if it exists and is encrypted
        if let transcription = self.transcription {
            print("🔐 [JournalEntry.decryptWithGlobalAccess] Starting transcription decryption...")
            
            // Decrypt main text
            if let encryptedData = transcription.encryptedText,
               transcription.text == nil {
                if let decryptedText = EncryptionManager.decryptToString(encryptedData, using: encryptionKey) {
                    transcription.text = decryptedText
                    print("✅ [JournalEntry.decryptWithGlobalAccess] Main text decrypted successfully")
                } else {
                    decryptionSuccess = false
                    print("❌ [JournalEntry.decryptWithGlobalAccess] Failed to decrypt main text")
                }
            }
            
            // Decrypt enhanced text
            if let encryptedData = transcription.encryptedEnhancedText,
               transcription.enhancedText == nil {
                print("🔐 [JournalEntry.decryptWithGlobalAccess] Decrypting enhanced text (\(encryptedData.count) bytes)")
                if let decryptedText = EncryptionManager.decryptToString(encryptedData, using: encryptionKey) {
                    transcription.enhancedText = decryptedText
                    print("✅ [JournalEntry.decryptWithGlobalAccess] Enhanced text decrypted successfully (\(decryptedText.count) characters)")
                } else {
                    decryptionSuccess = false
                    print("❌ [JournalEntry.decryptWithGlobalAccess] Failed to decrypt enhanced text")
                }
            }
            
            // Decrypt AI analysis
            if let encryptedData = transcription.encryptedAIAnalysis,
               transcription.aiAnalysis == nil {
                if let decryptedText = EncryptionManager.decryptToString(encryptedData, using: encryptionKey) {
                    transcription.aiAnalysis = decryptedText
                    print("✅ [JournalEntry.decryptWithGlobalAccess] AI analysis decrypted successfully")
                } else {
                    decryptionSuccess = false
                    print("❌ [JournalEntry.decryptWithGlobalAccess] Failed to decrypt AI analysis")
                }
            }
        }
        
        if decryptionSuccess {
            // Mark as decrypted for access control
            markAsDecrypted()
        }
        
        return decryptionSuccess
    }
}