//
//  AudioRecording+Extensions.swift
//  voicejournal
//
//  Created on 4/27/25.
//

import Foundation
import CoreData

extension AudioRecording {
    // MARK: - Encryption Properties
    
    // Temporary path for decrypted file (not persisted)
    private static var decryptedPaths = [String: String]()
    
    var tempDecryptedPath: String? {
        get {
            guard let filePath = self.filePath else { return nil }
            return AudioRecording.decryptedPaths[filePath]
        }
        set {
            guard let filePath = self.filePath else { 
                print("⚠️ [AudioRecording] Cannot set tempDecryptedPath - filePath is nil")
                return 
            }
            if let newValue = newValue {
                print("🔐 [AudioRecording] Setting tempDecryptedPath for '\(filePath)' to '\(newValue)'")
                AudioRecording.decryptedPaths[filePath] = newValue
                // Exclude temporary decrypted file from iCloud backup
                excludeFromBackup(at: newValue)
            } else {
                print("🔐 [AudioRecording] Clearing tempDecryptedPath for '\(filePath)'")
                AudioRecording.decryptedPaths.removeValue(forKey: filePath)
            }
        }
    }
    
    // Clear all temporary decrypted files
    static func clearAllTempDecryptedFiles() {
        // Remove all temporary decrypted files
        for path in decryptedPaths.values {
            do {
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: path) {
                    try fileManager.removeItem(atPath: path)
                }
            } catch {
                // Error occurred
            }
        }
        
        // Clear the temporary paths dictionary
        decryptedPaths.removeAll()
    }
    
    // MARK: - iCloud Backup Management
    
    /// Exclude a file from iCloud backup
    /// - Parameter path: The file path to exclude from backup
    private func excludeFromBackup(at path: String) {
        var url = URL(fileURLWithPath: path)
        do {
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try url.setResourceValues(resourceValues)
        } catch {
            // Error setting backup exclusion: \(error)
        }
    }
    
    // Get the effective file path (either encrypted or decrypted if available)
    var effectiveFilePath: String? {
        if let tempPath = tempDecryptedPath {
            return tempPath
        }
        return filePath
    }
    
    /// Check if the audio file exists on disk
    var fileExists: Bool {
        guard let path = filePath else { return false }
        let absoluteURL = FilePathUtility.toAbsolutePath(from: path)
        return FileManager.default.fileExists(atPath: absoluteURL.path)
    }
    
    /// Check if the audio file is missing (useful after restore)
    var isMissingFile: Bool {
        return filePath != nil && !fileExists
    }
    
    // MARK: - File Management
    
    /// Deletes the audio file from disk
    func deleteAudioFile() {
        // Delete encrypted file if exists
        if let filePath = self.filePath {
            do {
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: filePath) {
                    try fileManager.removeItem(atPath: filePath)
                    // Successfully deleted audio file
                }
            } catch {
                // Error occurred
            }
        }
        
        // Delete original file if exists and is different
        if let originalPath = self.originalFilePath, originalPath != self.filePath {
            do {
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: originalPath) {
                    try fileManager.removeItem(atPath: originalPath)
                    // Successfully deleted original audio file
                }
            } catch {
                // Error occurred
            }
        }
        
        // Delete temporary decrypted file if exists
        if let tempPath = self.tempDecryptedPath {
            do {
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: tempPath) {
                    try fileManager.removeItem(atPath: tempPath)
                    // Successfully deleted temporary decrypted file
                }
                self.tempDecryptedPath = nil
            } catch {
                // Error occurred
            }
        }
    }
    
    // MARK: - Bookmark Management
    
    /// Create a new bookmark at the specified timestamp
    /// - Parameters:
    ///   - timestamp: The position in seconds where the bookmark is placed
    ///   - label: Optional description for the bookmark
    ///   - color: Optional color for the bookmark (hex string)
    /// - Returns: The newly created bookmark
    func createBookmark(at timestamp: TimeInterval, label: String? = nil, color: String? = nil) -> Bookmark {
        guard let context = managedObjectContext else {
            fatalError("Managed object context is nil")
        }
        
        let bookmark = Bookmark.create(
            at: timestamp,
            label: label,
            color: color,
            for: self,
            in: context
        )
        
        // Save the context
        do {
            try context.save()
        } catch {
            // Error occurred
        }
        
        return bookmark
    }
    
    /// Delete a bookmark
    /// - Parameter bookmark: The bookmark to delete
    func deleteBookmark(_ bookmark: Bookmark) {
        guard let context = managedObjectContext else { return }
        
        context.delete(bookmark)
        
        // Save the context
        do {
            try context.save()
        } catch {
            // Error occurred
        }
    }
    
    /// Get all bookmarks for this recording, sorted by timestamp
    var allBookmarks: [Bookmark] {
        guard let context = managedObjectContext else { return [] }
        return Bookmark.fetchAll(for: self, in: context)
    }
    
    /// Find the nearest bookmark to a given timestamp
    /// - Parameter timestamp: The timestamp to search near
    /// - Returns: The nearest bookmark, or nil if no bookmarks exist
    func nearestBookmark(to timestamp: TimeInterval) -> Bookmark? {
        let bookmarks = allBookmarks
        guard !bookmarks.isEmpty else { return nil }
        
        // Find the bookmark with the smallest absolute difference in timestamp
        return bookmarks.min(by: { abs($0.timestamp - timestamp) < abs($1.timestamp - timestamp) })
    }
    
    /// Find the next bookmark after a given timestamp
    /// - Parameter timestamp: The current timestamp
    /// - Returns: The next bookmark, or nil if no bookmarks exist after the timestamp
    func nextBookmark(after timestamp: TimeInterval) -> Bookmark? {
        let bookmarks = allBookmarks
        
        // Filter bookmarks that are after the current timestamp
        let futureBookmarks = bookmarks.filter { $0.timestamp > timestamp }
        
        // Return the bookmark with the smallest timestamp (closest next one)
        return futureBookmarks.min(by: { $0.timestamp < $1.timestamp })
    }
    
    /// Find the previous bookmark before a given timestamp
    /// - Parameter timestamp: The current timestamp
    /// - Returns: The previous bookmark, or nil if no bookmarks exist before the timestamp
    func previousBookmark(before timestamp: TimeInterval) -> Bookmark? {
        let bookmarks = allBookmarks
        
        // Filter bookmarks that are before the current timestamp
        let pastBookmarks = bookmarks.filter { $0.timestamp < timestamp }
        
        // Return the bookmark with the largest timestamp (closest previous one)
        return pastBookmarks.max(by: { $0.timestamp < $1.timestamp })
    }
}
