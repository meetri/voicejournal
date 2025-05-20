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
    // Add a simple caching mechanism
    private static var pathCache: [String: URL] = [:]
    
    static func toAbsolutePath(from relativePath: String) -> URL {
        // Check cache first
        if let cachedURL = pathCache[relativePath] {
            print("🔍 [FilePathUtility] Using CACHED result for: \(relativePath)")
            return cachedURL
        }
        
        // If not cached, print full conversion log
        print("🔧 [FilePathUtility] Converting path: \(relativePath)")
        
        // Add stack trace for debugging purposes
        print("📋 [FilePathUtility] Stack trace: \(Thread.callStackSymbols[0...4].joined(separator: "\n   "))")
        
        // Check if it's already an absolute path
        // Absolute paths will start with "/" or contain the app's container path markers
        if relativePath.hasPrefix("/") || 
           relativePath.contains("/var/mobile/") || 
           relativePath.contains("/Users/") ||
           relativePath.contains("/private/var/") {
            print("  - Detected as absolute path")
            let url = URL(fileURLWithPath: relativePath)
            pathCache[relativePath] = url
            return url
        }
        
        // For relative paths, we need to determine the base directory
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // If it's just a filename (no directory separators), put it in the recordings directory
        if !relativePath.contains("/") {
            let result = recordingsDirectory.appendingPathComponent(relativePath)
            print("  - Simple filename, using recordings dir: \(result.path)")
            pathCache[relativePath] = result
            return result
        }
        
        // If it has subdirectories (like "EncryptedFiles/filename" or "BaseEncrypted/filename")
        // Use documents directory as base since encrypted files are stored there
        let result = documentsDir.appendingPathComponent(relativePath)
        print("  - Relative path with subdirs, using documents dir: \(result.path)")
        pathCache[relativePath] = result
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
    
    // Cache for file existence checks
    private static var existenceCache: [String: Bool] = [:]
    
    /// Check if a file exists at the given path
    /// - Parameter path: The path to check (can be relative or absolute)
    /// - Returns: True if the file exists, false otherwise
    static func fileExists(at path: String) -> Bool {
        // Check cache first
        if let cachedResult = existenceCache[path] {
            print("🔍 [FilePathUtility] Using CACHED existence check for: \(path) = \(cachedResult)")
            return cachedResult
        }
        
        // Use the same logic as toAbsolutePath to determine the full path
        let absoluteURL = toAbsolutePath(from: path)
        let exists = FileManager.default.fileExists(atPath: absoluteURL.path)
        
        // Cache the result
        existenceCache[path] = exists
        
        return exists
    }
    
    /// Clear all caches
    static func clearCaches() {
        print("🧹 [FilePathUtility] Clearing all path and existence caches")
        pathCache.removeAll()
        existenceCache.removeAll()
    }
    
    /// Find an audio file by its filename in known locations
    /// - Parameter filename: The filename (or lastPathComponent) to find
    /// - Returns: The URL of the found file, or nil if not found
    static func findAudioFile(with filename: String) throws -> URL? {
        print("🔍 [FilePathUtility.findAudioFile] Searching for audio file: \(filename)")
        
        // Check if it's a full path already
        let originalPath = URL(fileURLWithPath: filename)
        if FileManager.default.fileExists(atPath: originalPath.path) {
            print("✅ [FilePathUtility.findAudioFile] Found at original path")
            return originalPath
        }
        
        // List of places to check
        var searchLocations: [URL] = []
        
        // 1. App Documents directory
        if let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            searchLocations.append(docsDir)
            
            // Also check Recordings subdirectory
            let recordingsDir = docsDir.appendingPathComponent("Recordings")
            searchLocations.append(recordingsDir)
        }
        
        // 2. App Library directory
        if let libDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first {
            searchLocations.append(libDir)
        }
        
        // 3. App Support directory
        if let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            searchLocations.append(appSupportDir)
        }
        
        // 4. Caches directory
        if let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            searchLocations.append(cachesDir)
        }
        
        // 5. Temporary directory
        let tempDir = FileManager.default.temporaryDirectory
        searchLocations.append(tempDir)
        
        // Just get the filename part if it's a path
        let justFilename = URL(fileURLWithPath: filename).lastPathComponent
        
        // Search each location
        for location in searchLocations {
            let potentialPath = location.appendingPathComponent(justFilename)
            print("  - Checking: \(potentialPath.path)")
            
            if FileManager.default.fileExists(atPath: potentialPath.path) {
                print("✅ [FilePathUtility.findAudioFile] Found at: \(potentialPath.path)")
                return potentialPath
            }
        }
        
        // Last resort - look for the file with the same name but different path in Recordings dir
        do {
            let docsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let recordingsDir = docsUrl.appendingPathComponent("Recordings")
            
            if FileManager.default.fileExists(atPath: recordingsDir.path) {
                let files = try FileManager.default.contentsOfDirectory(at: recordingsDir, includingPropertiesForKeys: nil)
                for file in files {
                    if file.lastPathComponent == justFilename {
                        print("✅ [FilePathUtility.findAudioFile] Found matching filename in Recordings directory")
                        return file
                    }
                }
            }
        } catch {
            print("❌ [FilePathUtility.findAudioFile] Error listing Recordings directory: \(error)")
        }
        
        print("❌ [FilePathUtility.findAudioFile] File not found in any location")
        return nil
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
