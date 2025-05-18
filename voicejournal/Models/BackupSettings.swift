//
//  BackupSettings.swift
//  voicejournal
//
//  Created on 4/27/25.
//

import Foundation

class BackupSettings: ObservableObject {
    @Published var isICloudBackupEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isICloudBackupEnabled, forKey: "isICloudBackupEnabled")
        }
    }
    
    @Published var backupAudioFiles: Bool {
        didSet {
            UserDefaults.standard.set(backupAudioFiles, forKey: "backupAudioFiles")
            // Configure the recordings directory backup settings
            FilePathUtility.configureBackupSettings(backupAudioFiles: backupAudioFiles)
        }
    }
    
    @Published var showLargeBackupWarning: Bool {
        didSet {
            UserDefaults.standard.set(showLargeBackupWarning, forKey: "showLargeBackupWarning")
        }
    }
    
    @Published var warningSizeThresholdMB: Double {
        didSet {
            UserDefaults.standard.set(warningSizeThresholdMB, forKey: "warningSizeThresholdMB")
        }
    }
    
    init() {
        // Load settings from UserDefaults
        self.isICloudBackupEnabled = UserDefaults.standard.bool(forKey: "isICloudBackupEnabled")
        self.backupAudioFiles = UserDefaults.standard.bool(forKey: "backupAudioFiles")
        self.showLargeBackupWarning = UserDefaults.standard.bool(forKey: "showLargeBackupWarning")
        
        // Default to 100MB warning threshold
        let savedThreshold = UserDefaults.standard.double(forKey: "warningSizeThresholdMB")
        self.warningSizeThresholdMB = savedThreshold > 0 ? savedThreshold : 100.0
    }
    
    /// Calculate total size of all audio files
    func calculateTotalAudioSize() -> Int64 {
        let fetchRequest = AudioRecording.fetchRequest()
        do {
            let context = PersistenceController.shared.container.viewContext
            let recordings = try context.fetch(fetchRequest)
            
            var totalSize: Int64 = 0
            for recording in recordings {
                totalSize += recording.fileSize
            }
            return totalSize
        } catch {
            return 0
        }
    }
    
    /// Format file size for display
    static func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}