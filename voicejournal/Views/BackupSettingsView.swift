//
//  BackupSettingsView.swift
//  voicejournal
//
//  Created on 4/27/25.
//

import SwiftUI

// Backup metadata structure
struct BackupMetadata: Codable {
    let entryCount: Int
    let backupDate: Date
    let version: Int
}

struct BackupSettingsView: View {
    @StateObject private var settings = BackupSettings()
    @State private var totalAudioSize: Int64 = 0
    @FocusState private var isTextFieldFocused: Bool
    @State private var isCheckingBackup = false
    @State private var backupCheckResult: BackupCheckResult?
    @State private var showingBackupCheckResult = false
    @State private var showingRestoreConfirmation = false
    @State private var showingRestoreProgress = false
    @State private var restoreCompleted = false
    @State private var restoreError: Error?
    @State private var restoredCount = 0
    @StateObject private var recoveryManager = BackupRecoveryManager.shared
    
    enum BackupCheckResult {
        case found(Int, Date) // number of entries, backup date
        case notFound
        case error(String)
    }
    
    var body: some View {
        List {
            Section(header: Text("iCloud Backup")) {
                Toggle("Enable iCloud Backup", isOn: $settings.isICloudBackupEnabled)
                
                if settings.isICloudBackupEnabled {
                    Toggle("Include Audio Files", isOn: $settings.backupAudioFiles)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Audio Size")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(BackupSettings.formatFileSize(totalAudioSize))
                            .font(.headline)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Section(header: Text("Backup Warnings")) {
                Toggle("Warn for Large Backups", isOn: $settings.showLargeBackupWarning)
                
                if settings.showLargeBackupWarning {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Warning Threshold")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        HStack {
                            Slider(value: $settings.warningSizeThresholdMB, 
                                   in: 50...500, 
                                   step: 50)
                            Text("\(Int(settings.warningSizeThresholdMB)) MB")
                                .frame(width: 60)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Section(header: Text("Restore")) {
                Button(action: {
                    // Dismiss keyboard and unfocus any text fields
                    isTextFieldFocused = false
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    
                    // Small delay to ensure keyboard is fully dismissed
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        checkForBackupData()
                    }
                }) {
                    HStack {
                        Label("Check for Backup Data", systemImage: "arrow.down.circle")
                        Spacer()
                        if isCheckingBackup {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                }
                .disabled(isCheckingBackup)
                
                if let result = backupCheckResult {
                    switch result {
                    case .found(let count, let date):
                        VStack(alignment: .leading, spacing: 8) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Backup Found")
                                    .font(.headline)
                                    .foregroundColor(.green)
                                Text("\(count) entries from \(date, formatter: dateFormatter)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Button(action: {
                                showingRestoreConfirmation = true
                            }) {
                                Label("Restore Backup", systemImage: "arrow.down.circle.fill")
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    case .notFound:
                        Text("No backup data found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                    case .error(let message):
                        Text("Error: \(message)")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.vertical, 4)
                    }
                }
            }
            
            Section(footer: Text(backupInfoText)) {
                EmptyView()
            }
        }
        .navigationTitle("Backup Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            totalAudioSize = settings.calculateTotalAudioSize()
        }
        .onTapGesture {
            // Dismiss keyboard on tap anywhere in the list
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .alert("Restore Backup", isPresented: $showingRestoreConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Restore", role: .destructive) {
                performRestore()
            }
        } message: {
            Text("This will replace your current data with the backup. This action cannot be undone. Continue?")
        }
        .alert("Backup Check Complete", isPresented: $showingBackupCheckResult) {
            Button("OK") { }
        } message: {
            if let result = backupCheckResult {
                switch result {
                case .found(let count, let date):
                    Text("Found \(count) journal entries from \(date, formatter: dateFormatter). You can now restore this backup if desired.")
                case .notFound:
                    Text("No backup data was found in your iCloud account.")
                case .error(let message):
                    Text("Error: \(message)")
                }
            } else {
                Text("Backup check completed.")
            }
        }
        .sheet(isPresented: $showingRestoreProgress) {
            RestoreProgressView(
                recoveryManager: recoveryManager,
                isCompleted: $restoreCompleted,
                restoreError: $restoreError,
                restoredCount: $restoredCount,
                onDismiss: {
                    showingRestoreProgress = false
                    // Refresh the view if needed
                }
            )
        }
    }
    
    private var backupInfoText: String {
        if settings.isICloudBackupEnabled && settings.backupAudioFiles {
            return "Your journal entries and audio recordings will be backed up to iCloud. Large audio files may use significant iCloud storage."
        } else if settings.isICloudBackupEnabled {
            return "Your journal entries will be backed up to iCloud. Audio files will not be included in the backup."
        } else {
            return "iCloud backup is disabled. Your data will only be stored locally on this device."
        }
    }
    
    private func checkForBackupData() {
        isCheckingBackup = true
        backupCheckResult = nil
        
        Task {
            do {
                // Check if iCloud is available
                if FileManager.default.ubiquityIdentityToken == nil {
                    DispatchQueue.main.async {
                        self.backupCheckResult = .error("iCloud is not available. Please sign in to iCloud in Settings.")
                        self.isCheckingBackup = false
                    }
                    return
                }
                
                // Get iCloud container
                guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
                    DispatchQueue.main.async {
                        self.backupCheckResult = .error("Could not access iCloud container")
                        self.isCheckingBackup = false
                    }
                    return
                }
                
                let backupDir = containerURL.appendingPathComponent("backup", isDirectory: true)
                
                // Check if backup directory exists
                if !FileManager.default.fileExists(atPath: backupDir.path) {
                    DispatchQueue.main.async {
                        self.backupCheckResult = .notFound
                        self.isCheckingBackup = false
                    }
                    return
                }
                
                // Look for backup metadata file
                let metadataURL = backupDir.appendingPathComponent("backup_metadata.json")
                
                if FileManager.default.fileExists(atPath: metadataURL.path) {
                    let data = try Data(contentsOf: metadataURL)
                    if let metadata = try? JSONDecoder().decode(BackupMetadata.self, from: data) {
                        DispatchQueue.main.async {
                            self.backupCheckResult = .found(metadata.entryCount, metadata.backupDate)
                            self.isCheckingBackup = false
                            self.showingBackupCheckResult = true
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.backupCheckResult = .error("Could not read backup metadata")
                            self.isCheckingBackup = false
                        }
                    }
                } else {
                    // Try to count backup files as fallback
                    let files = try FileManager.default.contentsOfDirectory(at: backupDir, 
                                                                           includingPropertiesForKeys: [.creationDateKey])
                    let jsonFiles = files.filter { $0.pathExtension == "json" && $0.lastPathComponent != "backup_metadata.json" }
                    
                    if jsonFiles.isEmpty {
                        DispatchQueue.main.async {
                            self.backupCheckResult = .notFound
                            self.isCheckingBackup = false
                        }
                    } else {
                        let oldestDate = try jsonFiles.map { try $0.resourceValues(forKeys: [.creationDateKey]).creationDate }
                            .compactMap { $0 }
                            .min() ?? Date()
                        
                        DispatchQueue.main.async {
                            self.backupCheckResult = .found(jsonFiles.count, oldestDate)
                            self.isCheckingBackup = false
                            self.showingBackupCheckResult = true
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.backupCheckResult = .error("Failed to check backup: \(error.localizedDescription)")
                    self.isCheckingBackup = false
                }
            }
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    private func performRestore() {
        showingRestoreProgress = true
        
        recoveryManager.restoreFromBackup { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let count):
                    self.restoredCount = count
                    self.restoreCompleted = true
                    self.restoreError = nil
                case .failure(let error):
                    self.restoreError = error
                    self.restoreCompleted = true
                }
            }
        }
    }
}

// MARK: - Restore Progress View

struct RestoreProgressView: View {
    @ObservedObject var recoveryManager: BackupRecoveryManager
    @Binding var isCompleted: Bool
    @Binding var restoreError: Error?
    @Binding var restoredCount: Int
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if isCompleted {
                    if let error = restoreError {
                        // Error state
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.red)
                        
                        Text("Restore Failed")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text(error.localizedDescription)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    } else {
                        // Success state
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("Restore Complete")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Successfully restored \(restoredCount) journal entries")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Done") {
                        onDismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top)
                } else {
                    // Progress state
                    VStack(spacing: 16) {
                        ProgressView(value: recoveryManager.restoreProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .padding(.horizontal)
                        
                        Text(recoveryManager.restoreStatus)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        
                        Text("\(Int(recoveryManager.restoreProgress * 100))%")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding(.top)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Restore from Backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isCompleted {
                        Button("Done") {
                            onDismiss()
                        }
                    }
                }
            }
        }
        .interactiveDismissDisabled(!isCompleted)
    }
}