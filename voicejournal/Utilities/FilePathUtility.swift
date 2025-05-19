//
//  FilePathUtility.swift
//  voicejournal
//
//  Created on 4/27/25.
//

import Foundation

/// Utility for handling file paths in a way that's resilient to app rebuilds
struct FilePathUtility {
    
    // MARK: - Properties
    
    /// The recordings directory within the app's documents directory
    static var recordingsDirectory: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let recordingsDir = paths[0].appendingPathComponent("Recordings", isDirectory: true)
        return recordingsDir
    }
    
    // MARK: - Public Methods
    
    /// Convert an absolute file path to a relative path (relative to the recordings directory)
    /// - Parameter absolutePath: The absolute file path
    /// - Returns: A relative path that can be stored in Core Data
    static func toRelativePath(from absolutePath: String) -> String {
        let url = URL(fileURLWithPath: absolutePath)
        let filename = url.lastPathComponent
        return filename
    }
    
    /// Convert a relative file path to an absolute path
    /// - Parameter relativePath: The relative file path (filename or relative path with subdirectories)
    /// - Returns: An absolute path that can be used to access the file
    static func toAbsolutePath(from relativePath: String) -> URL {
        print("🔧 [FilePathUtility] Converting path: \(relativePath)")
        
        // Check if it's already an absolute path
        // Absolute paths will start with "/" or contain the app's container path markers
        if relativePath.hasPrefix("/") || 
           relativePath.contains("/var/mobile/") || 
           relativePath.contains("/Users/") ||
           relativePath.contains("/private/var/") {
            print("  - Detected as absolute path")
            return URL(fileURLWithPath: relativePath)
        }
        
        // For relative paths, we need to determine the base directory
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // If it's just a filename (no directory separators), put it in the recordings directory
        if !relativePath.contains("/") {
            let result = recordingsDirectory.appendingPathComponent(relativePath)
            print("  - Simple filename, using recordings dir: \(result.path)")
            return result
        }
        
        // If it has subdirectories (like "EncryptedFiles/filename" or "BaseEncrypted/filename")
        // Use documents directory as base since encrypted files are stored there
        let result = documentsDir.appendingPathComponent(relativePath)
        print("  - Relative path with subdirs, using documents dir: \(result.path)")
        return result
    }
    
    /// Create the recordings directory if it doesn't exist
    static func createRecordingsDirectoryIfNeeded() {
        let directoryPath = recordingsDirectory.path
        
        if FileManager.default.fileExists(atPath: directoryPath) {
            return
        }
        
        do {
            try FileManager.default.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)
        } catch {
            // Error handling without debug logs
        }
    }
    
    /// Check if a file exists at the given path
    /// - Parameter path: The path to check (can be relative or absolute)
    /// - Returns: True if the file exists, false otherwise
    static func fileExists(at path: String) -> Bool {
        // Use the same logic as toAbsolutePath to determine the full path
        let absoluteURL = toAbsolutePath(from: path)
        let exists = FileManager.default.fileExists(atPath: absoluteURL.path)
        return exists
    }
    
    // MARK: - iCloud Backup Management
    
    /// Exclude recordings directory from iCloud backup if needed
    static func configureBackupSettings(backupAudioFiles: Bool) {
        do {
            var url = recordingsDirectory
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = !backupAudioFiles
            try url.setResourceValues(resourceValues)
        } catch {
            // Error setting backup configuration
        }
    }
    
    /// Get backup status for recordings directory
    static func getBackupStatus() -> Bool {
        do {
            let resourceValues = try recordingsDirectory.resourceValues(forKeys: [.isExcludedFromBackupKey])
            return !(resourceValues.isExcludedFromBackup ?? false)
        } catch {
            return true // Default to backing up if we can't determine status
        }
    }
}
