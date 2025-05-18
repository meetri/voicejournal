//
//  BackupRecoveryManager.swift
//  voicejournal
//
//  Created on 4/27/25.
//

import Foundation
import CoreData
import Combine

class BackupRecoveryManager: ObservableObject {
    static let shared = BackupRecoveryManager()
    
    // Progress tracking
    @Published var restoreProgress: Double = 0.0
    @Published var restoreStatus: String = ""
    @Published var isRestoring: Bool = false
    
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
            // Log the missing file for analytics
            logMissingFile(recording)
            
            // Note: We could potentially set a flag here to indicate missing file
            // But the existing code uses isMissingFile computed property
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
    
    /// Restore journal entries from iCloud backup
    func restoreFromBackup(completion: @escaping (Result<Int, Error>) -> Void) {
        guard !isRestoring else {
            completion(.failure(BackupError.alreadyRestoring))
            return
        }
        
        isRestoring = true
        restoreProgress = 0.0
        restoreStatus = "Checking iCloud availability..."
        
        Task {
            do {
                // Check if iCloud is available
                guard FileManager.default.ubiquityIdentityToken != nil else {
                    DispatchQueue.main.async {
                        self.isRestoring = false
                        completion(.failure(BackupError.iCloudNotAvailable))
                    }
                    return
                }
                
                // Get iCloud container
                guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
                    DispatchQueue.main.async {
                        self.isRestoring = false
                        completion(.failure(BackupError.containerNotFound))
                    }
                    return
                }
                
                let backupDir = containerURL.appendingPathComponent("backup", isDirectory: true)
                
                // Check if backup directory exists
                guard FileManager.default.fileExists(atPath: backupDir.path) else {
                    DispatchQueue.main.async {
                        self.isRestoring = false
                        completion(.failure(BackupError.noBackupFound))
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    self.restoreStatus = "Loading backup data..."
                    self.restoreProgress = 0.1
                }
                
                // Get all backup files
                let files = try FileManager.default.contentsOfDirectory(at: backupDir,
                                                                       includingPropertiesForKeys: nil)
                let jsonFiles = files.filter { $0.pathExtension == "json" && $0.lastPathComponent != "backup_metadata.json" }
                
                guard !jsonFiles.isEmpty else {
                    DispatchQueue.main.async {
                        self.isRestoring = false
                        completion(.failure(BackupError.noBackupFiles))
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    self.restoreStatus = "Processing \(jsonFiles.count) entries..."
                    self.restoreProgress = 0.2
                }
                
                let context = PersistenceController.shared.container.viewContext
                
                // Clear existing data
                try clearExistingData(context: context)
                
                DispatchQueue.main.async {
                    self.restoreStatus = "Restoring journal entries..."
                    self.restoreProgress = 0.3
                }
                
                // Restore each backup file
                var restoredCount = 0
                let progressIncrement = 0.5 / Double(jsonFiles.count)
                
                for (index, file) in jsonFiles.enumerated() {
                    try autoreleasepool {
                        let data = try Data(contentsOf: file)
                        if let backupData = try? JSONDecoder().decode(JournalEntryBackup.self, from: data) {
                            try restoreEntry(from: backupData, context: context)
                            restoredCount += 1
                            
                            DispatchQueue.main.async {
                                self.restoreProgress = 0.3 + (Double(index + 1) * progressIncrement)
                                self.restoreStatus = "Restored \(restoredCount) of \(jsonFiles.count) entries..."
                            }
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    self.restoreStatus = "Saving restored data..."
                    self.restoreProgress = 0.8
                }
                
                // Save the context
                try context.save()
                
                // Check for missing audio files
                let missingFiles = findMissingAudioFiles()
                if !missingFiles.isEmpty {
                    UserDefaults.standard.set(missingFiles.count, forKey: "missingAudioFilesCount")
                }
                
                DispatchQueue.main.async {
                    self.restoreStatus = "Restore complete!"
                    self.restoreProgress = 1.0
                    self.isRestoring = false
                    completion(.success(restoredCount))
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.isRestoring = false
                    self.restoreStatus = "Restore failed"
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func clearExistingData(context: NSManagedObjectContext) throws {
        // Delete all journal entries (which cascades to recordings, transcriptions, etc.)
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "JournalEntry")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        try context.execute(deleteRequest)
        
        // Delete all tags
        let tagFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Tag")
        let tagDeleteRequest = NSBatchDeleteRequest(fetchRequest: tagFetchRequest)
        try context.execute(tagDeleteRequest)
        
        // Reset Core Data context to ensure clean state
        context.reset()
    }
    
    private func restoreEntry(from backup: JournalEntryBackup, context: NSManagedObjectContext) throws {
        let entry = JournalEntry(context: context)
        // Core Data entities use auto-generated IDs, we can't set them directly
        entry.createdAt = backup.createdAt
        entry.modifiedAt = backup.updatedAt
        entry.title = backup.title
        // No notes field in the model, might be stored in transcription or other field
        
        // Restore audio recording
        if let recordingData = backup.audioRecording {
            let recording = AudioRecording(context: context)
            recording.filePath = recordingData.filePath
            recording.duration = recordingData.duration
            recording.fileSize = recordingData.fileSize
            recording.recordedAt = recordingData.recordedAt
            recording.isEncrypted = recordingData.isEncrypted
            recording.journalEntry = entry
            
            // Check if audio file exists
            if let path = recording.filePath,
               !FileManager.default.fileExists(atPath: FilePathUtility.toAbsolutePath(from: path).path) {
                // Audio file is missing - we'll handle this in findMissingAudioFiles
                // For now, just keep the path as is
            }
        }
        
        // Restore transcription
        if let transcriptionData = backup.transcription {
            let transcription = Transcription(context: context)
            transcription.text = transcriptionData.text
            transcription.journalEntry = entry
        }
        
        // Restore tags
        for tagData in backup.tags {
            // First check if tag already exists by name
            let tagRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
            tagRequest.predicate = NSPredicate(format: "name == %@", tagData.name)
            
            let existingTags = try context.fetch(tagRequest)
            let tag: Tag
            
            if let existingTag = existingTags.first {
                tag = existingTag
            } else {
                tag = Tag(context: context)
                tag.name = tagData.name
                tag.color = tagData.color
                tag.isEncrypted = tagData.isEncrypted
                tag.createdAt = Date()
            }
            
            // Associate tag with entry
            tag.addToEntries(entry)
        }
        
        // Note: Bookmarks aren't directly part of JournalEntry in the model
        // They might be stored differently or not exist in this schema
    }
}

// MARK: - Backup Data Structures

struct JournalEntryBackup: Codable {
    let createdAt: Date
    let updatedAt: Date
    let title: String?
    let tags: [TagBackup]
    let audioRecording: AudioRecordingBackup?
    let transcription: TranscriptionBackup?
}

struct TagBackup: Codable {
    let name: String
    let color: String
    let isEncrypted: Bool
}

struct AudioRecordingBackup: Codable {
    let filePath: String?
    let duration: Double
    let fileSize: Int64
    let recordedAt: Date
    let isEncrypted: Bool
}

struct TranscriptionBackup: Codable {
    let text: String
}

// MARK: - Errors

enum BackupError: LocalizedError {
    case alreadyRestoring
    case iCloudNotAvailable
    case containerNotFound
    case noBackupFound
    case noBackupFiles
    
    var errorDescription: String? {
        switch self {
        case .alreadyRestoring:
            return "A restore is already in progress"
        case .iCloudNotAvailable:
            return "iCloud is not available. Please sign in to iCloud in Settings."
        case .containerNotFound:
            return "Could not access iCloud container"
        case .noBackupFound:
            return "No backup found in iCloud"
        case .noBackupFiles:
            return "No backup files found"
        }
    }
}