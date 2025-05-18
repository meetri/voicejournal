//
//  BackupRecoveryManager.swift
//  voicejournal
//
//  Created on 4/27/25.
//

import Foundation
import CoreData

class BackupRecoveryManager {
    static let shared = BackupRecoveryManager()
    
    private init() {}
    
    /// Check if the app has been restored from iCloud backup
    func checkForRestore() -> Bool {
        let hasBeenChecked = UserDefaults.standard.bool(forKey: "hasCheckedForRestore")
        
        if !hasBeenChecked {
            // Mark that we've checked
            UserDefaults.standard.set(true, forKey: "hasCheckedForRestore")
            
            // Check if there are any missing audio files
            let missingFiles = findMissingAudioFiles()
            
            if !missingFiles.isEmpty {
                // Save the missing files for later handling
                UserDefaults.standard.set(missingFiles.count, forKey: "missingAudioFilesCount")
                return true
            }
        }
        
        return false
    }
    
    /// Find all audio recordings with missing files
    func findMissingAudioFiles() -> [AudioRecording] {
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<AudioRecording> = AudioRecording.fetchRequest()
        
        do {
            let recordings = try context.fetch(fetchRequest)
            return recordings.filter { $0.isMissingFile }
        } catch {
            return []
        }
    }
    
    /// Handle missing audio files after restore
    func handleMissingFiles(completion: @escaping (Bool) -> Void) {
        let missingFiles = findMissingAudioFiles()
        
        if missingFiles.isEmpty {
            completion(true)
            return
        }
        
        // For each missing file, we can:
        // 1. Mark entries as having missing audio
        // 2. Show a notification to the user
        // 3. Attempt to recover from iCloud Drive if available
        
        let context = PersistenceController.shared.container.viewContext
        
        for recording in missingFiles {
            // Mark the recording as having a missing file
            recording.originalFilePath = recording.filePath
            recording.filePath = nil
            
            // Log the missing file for analytics
            logMissingFile(recording)
        }
        
        do {
            try context.save()
            UserDefaults.standard.set(0, forKey: "missingAudioFilesCount")
            completion(true)
        } catch {
            completion(false)
        }
    }
    
    /// Create a recovery report for missing files
    func createRecoveryReport() -> String {
        let missingFiles = findMissingAudioFiles()
        
        var report = "Backup Recovery Report\n"
        report += "=====================\n\n"
        report += "Missing Audio Files: \(missingFiles.count)\n\n"
        
        for (index, recording) in missingFiles.enumerated() {
            report += "\(index + 1). Recording from \(recording.recordedAt?.formatted() ?? "Unknown")\n"
            report += "   Duration: \(recording.duration) seconds\n"
            report += "   File Size: \(BackupSettings.formatFileSize(recording.fileSize))\n"
            if let entry = recording.journalEntry {
                report += "   Entry: \(entry.title ?? "Untitled")\n"
            }
            report += "\n"
        }
        
        return report
    }
    
    private func logMissingFile(_ recording: AudioRecording) {
        // Log missing file for debugging/analytics
        let info = [
            "recordedAt": recording.recordedAt?.description ?? "unknown",
            "duration": String(recording.duration),
            "fileSize": String(recording.fileSize),
            "filePath": recording.filePath ?? "none"
        ]
        // Log the info (could be sent to analytics service)
        _ = info
    }
}