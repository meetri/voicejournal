//
//  MigrationUtility.swift
//  voicejournal
//
//  Created on 4/27/25.
//

import Foundation
import CoreData

/// Utility for migrating data between app versions
struct MigrationUtility {
    
    // MARK: - Properties
    
    /// Enable detailed logging for debugging
    static let enableLogging = true
    
    // MARK: - Public Methods
    
    /// Migrate audio file paths from absolute to relative paths
    /// - Parameter context: The managed object context to use for the migration
    /// - Returns: The number of recordings migrated
    static func migrateAudioFilePaths(in context: NSManagedObjectContext) -> Int {
        print("DEBUG: MigrationUtility - Starting migration of audio file paths")
        
        // Create a fetch request for all AudioRecording entities
        let fetchRequest: NSFetchRequest<AudioRecording> = AudioRecording.fetchRequest()
        
        do {
            // Fetch all audio recordings
            let recordings = try context.fetch(fetchRequest)
            print("DEBUG: MigrationUtility - Found \(recordings.count) audio recordings in database")
            
            var migratedCount = 0
            var alreadyRelativeCount = 0
            var missingFileCount = 0
            
            // Iterate through each recording
            for (index, recording) in recordings.enumerated() {
                guard let filePath = recording.filePath else {
                    print("DEBUG: MigrationUtility - Recording #\(index) has nil filePath, skipping")
                    continue
                }
                
                print("DEBUG: MigrationUtility - Processing recording #\(index) with path: \(filePath)")
                
                if filePath.contains("/") {
                    // This is an absolute path, convert it to a relative path
                    let relativePath = FilePathUtility.toRelativePath(from: filePath)
                    
                    print("DEBUG: MigrationUtility - Path appears to be absolute, converting to relative: \(filePath) -> \(relativePath)")
                    
                    // Check if the file exists at the absolute path
                    let fileExistsAtOldPath = FileManager.default.fileExists(atPath: filePath)
                    print("DEBUG: MigrationUtility - File exists at old absolute path: \(fileExistsAtOldPath ? "YES" : "NO")")
                    
                    if fileExistsAtOldPath {
                        // File exists at the old absolute path, update to relative path
                        recording.filePath = relativePath
                        migratedCount += 1
                        print("DEBUG: MigrationUtility - Migrated file path: \(filePath) -> \(relativePath)")
                        
                        // Copy the file to the recordings directory if it's not already there
                        let newAbsolutePath = FilePathUtility.toAbsolutePath(from: relativePath)
                        if !FileManager.default.fileExists(atPath: newAbsolutePath.path) {
                            do {
                                try FileManager.default.copyItem(atPath: filePath, toPath: newAbsolutePath.path)
                                print("DEBUG: MigrationUtility - Copied file to new location: \(newAbsolutePath.path)")
                            } catch {
                                print("ERROR: MigrationUtility - Failed to copy file: \(error.localizedDescription)")
                            }
                        }
                    } else {
                        // File doesn't exist at the old absolute path
                        // Check if it exists in the recordings directory with the filename
                        let newAbsolutePath = FilePathUtility.toAbsolutePath(from: relativePath)
                        let fileExistsAtNewPath = FileManager.default.fileExists(atPath: newAbsolutePath.path)
                        
                        print("DEBUG: MigrationUtility - File exists at new path: \(fileExistsAtNewPath ? "YES" : "NO")")
                        
                        if fileExistsAtNewPath {
                            // File exists at the new location, update to relative path
                            recording.filePath = relativePath
                            migratedCount += 1
                            print("DEBUG: MigrationUtility - Migrated file path (file already in new location): \(filePath) -> \(relativePath)")
                        } else {
                            // File doesn't exist at either location
                            missingFileCount += 1
                            print("WARNING: MigrationUtility - Audio file not found at either location: \(filePath) or \(newAbsolutePath.path)")
                        }
                    }
                } else {
                    // This is already a relative path
                    alreadyRelativeCount += 1
                    print("DEBUG: MigrationUtility - Path is already relative: \(filePath)")
                    
                    // Check if the file exists at the expected location
                    let absolutePath = FilePathUtility.toAbsolutePath(from: filePath)
                    let fileExists = FileManager.default.fileExists(atPath: absolutePath.path)
                    print("DEBUG: MigrationUtility - File exists at expected location: \(fileExists ? "YES" : "NO")")
                }
            }
            
            // Save the context if any recordings were migrated
            if migratedCount > 0 {
                try context.save()
                print("DEBUG: MigrationUtility - Successfully migrated \(migratedCount) audio file paths")
            }
            
            print("DEBUG: MigrationUtility - Migration summary:")
            print("DEBUG: MigrationUtility - Total recordings: \(recordings.count)")
            print("DEBUG: MigrationUtility - Migrated: \(migratedCount)")
            print("DEBUG: MigrationUtility - Already relative: \(alreadyRelativeCount)")
            print("DEBUG: MigrationUtility - Missing files: \(missingFileCount)")
            
            return migratedCount
        } catch {
            print("ERROR: MigrationUtility - Failed to migrate audio file paths: \(error.localizedDescription)")
            return 0
        }
    }
}
