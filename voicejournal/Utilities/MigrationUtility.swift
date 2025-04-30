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
    
    // MARK: - Public Methods
    
    /// Migrate audio file paths from absolute to relative paths
    /// - Parameter context: The managed object context to use for the migration
    /// - Returns: The number of recordings migrated
    static func migrateAudioFilePaths(in context: NSManagedObjectContext) -> Int {
        // Create a fetch request for all AudioRecording entities
        let fetchRequest: NSFetchRequest<AudioRecording> = AudioRecording.fetchRequest()
        
        do {
            // Fetch all audio recordings
            let recordings = try context.fetch(fetchRequest)
            
            var migratedCount = 0
            var alreadyRelativeCount = 0
            var missingFileCount = 0
            
            // Iterate through each recording
            for (index, recording) in recordings.enumerated() {
                guard let filePath = recording.filePath else {
                    continue
                }
                
                if filePath.contains("/") {
                    // This is an absolute path, convert it to a relative path
                    let relativePath = FilePathUtility.toRelativePath(from: filePath)
                    
                    // Check if the file exists at the absolute path
                    let fileExistsAtOldPath = FileManager.default.fileExists(atPath: filePath)
                    
                    if fileExistsAtOldPath {
                        // File exists at the old absolute path, update to relative path
                        recording.filePath = relativePath
                        migratedCount += 1
                        
                        // Copy the file to the recordings directory if it's not already there
                        let newAbsolutePath = FilePathUtility.toAbsolutePath(from: relativePath)
                        if !FileManager.default.fileExists(atPath: newAbsolutePath.path) {
                            do {
                                try FileManager.default.copyItem(atPath: filePath, toPath: newAbsolutePath.path)
                            } catch {
                                // Error handling without debug logs
                            }
                        }
                    } else {
                        // File doesn't exist at the old absolute path
                        // Check if it exists in the recordings directory with the filename
                        let newAbsolutePath = FilePathUtility.toAbsolutePath(from: relativePath)
                        let fileExistsAtNewPath = FileManager.default.fileExists(atPath: newAbsolutePath.path)
                        
                        if fileExistsAtNewPath {
                            // File exists at the new location, update to relative path
                            recording.filePath = relativePath
                            migratedCount += 1
                        } else {
                            // File doesn't exist at either location
                            missingFileCount += 1
                        }
                    }
                } else {
                    // This is already a relative path
                    alreadyRelativeCount += 1
                    
                    // Check if the file exists at the expected location
                    let absolutePath = FilePathUtility.toAbsolutePath(from: filePath)
                    let fileExists = FileManager.default.fileExists(atPath: absolutePath.path)
                }
            }
            
            // Save the context if any recordings were migrated
            if migratedCount > 0 {
                try context.save()
            }
            
            return migratedCount
        } catch {
            return 0
        }
    }
}
