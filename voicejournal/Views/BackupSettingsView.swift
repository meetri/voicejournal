//
//  BackupSettingsView.swift
//  voicejournal
//
//  Created on 4/27/25.
//

import SwiftUI

struct BackupSettingsView: View {
    @StateObject private var settings = BackupSettings()
    @State private var totalAudioSize: Int64 = 0
    @State private var showingRestoreAlert = false
    @FocusState private var isTextFieldFocused: Bool
    
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
                        showingRestoreAlert = true
                    }
                }) {
                    Label("Check for Backup Data", systemImage: "arrow.down.circle")
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
        .alert("Restore from iCloud", isPresented: $showingRestoreAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Check Backup") {
                checkForBackupData()
            }
        } message: {
            Text("This will check for backup data in iCloud. Your current data will not be affected unless you choose to restore.")
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
        // TODO: Implement iCloud backup check
        // This would query iCloud for existing backup data
    }
}