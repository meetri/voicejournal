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
        guard let encryptedTag = self.encryptedTag,
              let key = encryptedTag.globalAccessKey else {
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
                // // Error occurred
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
}