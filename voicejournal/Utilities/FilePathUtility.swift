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
    
    /// Enable detailed logging for debugging
    static let enableLogging = true
    
    /// The recordings directory within the app's documents directory
    static var recordingsDirectory: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let recordingsDir = paths[0].appendingPathComponent("Recordings", isDirectory: true)
        
        if enableLogging {
            print("DEBUG: FilePathUtility - Recordings directory: \(recordingsDir.path)")
        }
        
        return recordingsDir
    }
    
    // MARK: - Public Methods
    
    /// Convert an absolute file path to a relative path (relative to the recordings directory)
    /// - Parameter absolutePath: The absolute file path
    /// - Returns: A relative path that can be stored in Core Data
    static func toRelativePath(from absolutePath: String) -> String {
        let url = URL(fileURLWithPath: absolutePath)
        let filename = url.lastPathComponent
        
        if enableLogging {
            print("DEBUG: FilePathUtility - Converting absolute path to relative: \(absolutePath) -> \(filename)")
        }
        
        return filename
    }
    
    /// Convert a relative file path to an absolute path
    /// - Parameter relativePath: The relative file path (filename only)
    /// - Returns: An absolute path that can be used to access the file
    static func toAbsolutePath(from relativePath: String) -> URL {
        // If the path already contains directory components, assume it's already an absolute path
        // This is for backward compatibility with existing data
        if relativePath.contains("/") {
            if enableLogging {
                print("DEBUG: FilePathUtility - Path appears to be absolute already: \(relativePath)")
            }
            return URL(fileURLWithPath: relativePath)
        }
        
        // Otherwise, treat it as a filename and append it to the recordings directory
        let absoluteURL = recordingsDirectory.appendingPathComponent(relativePath)
        
        if enableLogging {
            print("DEBUG: FilePathUtility - Converting relative path to absolute: \(relativePath) -> \(absoluteURL.path)")
            
            // Check if the file exists at this path
            let exists = FileManager.default.fileExists(atPath: absoluteURL.path)
            print("DEBUG: FilePathUtility - File exists at path: \(exists ? "YES" : "NO")")
        }
        
        return absoluteURL
    }
    
    /// Create the recordings directory if it doesn't exist
    static func createRecordingsDirectoryIfNeeded() {
        let directoryPath = recordingsDirectory.path
        
        if FileManager.default.fileExists(atPath: directoryPath) {
            if enableLogging {
                print("DEBUG: FilePathUtility - Recordings directory already exists at: \(directoryPath)")
            }
            return
        }
        
        do {
            try FileManager.default.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)
            if enableLogging {
                print("DEBUG: FilePathUtility - Created recordings directory at: \(directoryPath)")
            }
        } catch {
            print("ERROR: FilePathUtility - Failed to create recordings directory: \(error.localizedDescription)")
        }
    }
    
    /// Check if a file exists at the given path
    /// - Parameter path: The path to check (can be relative or absolute)
    /// - Returns: True if the file exists, false otherwise
    static func fileExists(at path: String) -> Bool {
        let absolutePath: String
        
        if path.contains("/") {
            // Assume it's an absolute path
            absolutePath = path
        } else {
            // Assume it's a relative path (filename only)
            absolutePath = recordingsDirectory.appendingPathComponent(path).path
        }
        
        let exists = FileManager.default.fileExists(atPath: absolutePath)
        
        if enableLogging {
            print("DEBUG: FilePathUtility - Checking if file exists at: \(absolutePath) - \(exists ? "YES" : "NO")")
        }
        
        return exists
    }
}
