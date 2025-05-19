//
//  PathMigrationUtility.swift
//  voicejournal
//
//  Created on 5/19/25.
//

import Foundation
import CoreData

/// Utility to migrate absolute paths to relative paths in the database
class PathMigrationUtility {
    
    /// Perform migration to fix paths containing app container IDs
    /// This migrates absolute paths to relative paths that will survive app reinstalls
    static func migratePathsIfNeeded(context: NSManagedObjectContext) {
        
        // Fetch all audio recordings
        let recordingFetchRequest: NSFetchRequest<AudioRecording> = AudioRecording.fetchRequest()
        
        do {
            let recordings = try context.fetch(recordingFetchRequest)
            var migratedCount = 0
            
            for recording in recordings {
                var needsSave = false
                
                // Check and migrate main file path
                if let filePath = recording.filePath,
                   filePath.contains("/Containers/") {
                    // This is an absolute path with container ID
                    let fileName = URL(fileURLWithPath: filePath).lastPathComponent
                    
                    // Determine the proper relative path based on the file name
                    let relativePath: String
                    if fileName.hasSuffix(".encrypted") {
                        relativePath = "EncryptedFiles/\(fileName)"
                    } else if fileName.hasSuffix(".baseenc") {
                        relativePath = "BaseEncrypted/\(fileName)"
                    } else {
                        relativePath = fileName
                    }
                    
                    recording.filePath = relativePath
                    needsSave = true
                    migratedCount += 1
                    print("🔧 Migrated audio path: \(filePath) -> \(relativePath)")
                }
                
                // Check and migrate original file path
                if let originalPath = recording.originalFilePath,
                   originalPath.contains("/Containers/") {
                    // Extract just the filename
                    let fileName = URL(fileURLWithPath: originalPath).lastPathComponent
                    recording.originalFilePath = fileName
                    needsSave = true
                    print("🔧 Migrated original path: \(originalPath) -> \(fileName)")
                }
                
                if needsSave {
                    // The entity will be saved when we save the context
                }
            }
            
            // Fetch all journal entries to check base encrypted paths
            let entryFetchRequest: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
            let entries = try context.fetch(entryFetchRequest)
            
            for entry in entries {
                var needsSave = false
                
                // Check and migrate base encrypted audio path
                if let baseEncryptedPath = entry.baseEncryptedAudioPath,
                   baseEncryptedPath.contains("/Containers/") {
                    // Extract just the relative path
                    let fileName = URL(fileURLWithPath: baseEncryptedPath).lastPathComponent
                    let relativePath = "BaseEncrypted/\(fileName)"
                    entry.baseEncryptedAudioPath = relativePath
                    needsSave = true
                    migratedCount += 1
                    print("🔧 Migrated base encrypted path: \(baseEncryptedPath) -> \(relativePath)")
                }
                
                if needsSave {
                    // The entity will be saved when we save the context
                }
            }
            
            // Save all changes if any migrations were performed
            if migratedCount > 0 {
                try context.save()
                print("✅ Successfully migrated \(migratedCount) paths to relative format")
            } else {
                print("✅ No path migration needed - all paths are already relative")
            }
            
        } catch {
            print("❌ Error during path migration: \(error)")
        }
    }
    
    /// Check if migration is needed (for diagnostic purposes)
    static func checkIfMigrationNeeded(context: NSManagedObjectContext) -> Bool {
        let recordingFetchRequest: NSFetchRequest<AudioRecording> = AudioRecording.fetchRequest()
        recordingFetchRequest.predicate = NSPredicate(format: "filePath CONTAINS[c] %@", "/Containers/")
        
        let entryFetchRequest: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        entryFetchRequest.predicate = NSPredicate(format: "baseEncryptedAudioPath CONTAINS[c] %@", "/Containers/")
        
        do {
            let recordingCount = try context.count(for: recordingFetchRequest)
            let entryCount = try context.count(for: entryFetchRequest)
            
            return recordingCount > 0 || entryCount > 0
        } catch {
            print("❌ Error checking migration need: \(error)")
            return false
        }
    }
}