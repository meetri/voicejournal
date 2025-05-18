//
//  voicejournalApp.swift
//  voicejournal
//
//  Created by meetri on 4/27/25.
//

import SwiftUI
import CoreData


@main
struct voicejournalApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var authService = AuthenticationService()
    @StateObject private var speechRecognitionService = SpeechRecognitionService(locale: LanguageSettings.shared.selectedLocale)
    @State private var themeManager = ThemeManager()
    @State private var showingRestoreAlert = false
    @State private var missingFilesCount = 0
    
    // Create a UIApplicationDelegateAdaptor to handle app lifecycle events
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    

    var body: some Scene {
        WindowGroup {
            if authService.isAuthenticated {
                ContentView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .environmentObject(authService)
                    .environmentObject(speechRecognitionService)
                    .environment(\.themeManager, themeManager)
                    .preferredColorScheme(colorScheme(for: themeManager.currentThemeID))
                    .onAppear {
                        themeManager.setContext(persistenceController.container.viewContext)
                        ThemeUtility.updateSystemAppearance(with: themeManager.theme)
                        checkForRestore()
                    }
                    .alert("Audio Files Missing", isPresented: $showingRestoreAlert) {
                        Button("OK") { }
                        Button("View Details") {
                            // Navigate to backup settings
                        }
                    } message: {
                        Text("\(missingFilesCount) audio files could not be restored from iCloud backup. These entries will show a missing audio indicator.")
                    }
            } else {
                AuthenticationView()
                    .environmentObject(authService)
                    .environmentObject(speechRecognitionService)
                    .environment(\.themeManager, themeManager)
                    .preferredColorScheme(colorScheme(for: themeManager.currentThemeID))
                    .onAppear {
                        themeManager.setContext(persistenceController.container.viewContext)
                        ThemeUtility.updateSystemAppearance(with: themeManager.theme)
                    }
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background {
                // App is entering background - reset all granted tag access
                EncryptedTagsAccessManager.shared.clearAllAccess()
            }
        }
    }
    
    // Track the scene phase
    @Environment(\.scenePhase) var scenePhase
    
    private func colorScheme(for themeID: String) -> ColorScheme? {
        // Try to match built-in theme first
        if let builtInTheme = ThemeID(rawValue: themeID) {
            switch builtInTheme {
            case .light:
                return .light
            case .dark, .futuristic, .purplehaze:
                return .dark
            }
        }
        // For custom themes, default to automatic
        return nil
    }
    
    private func checkForRestore() {
        if BackupRecoveryManager.shared.checkForRestore() {
            let missingFiles = BackupRecoveryManager.shared.findMissingAudioFiles()
            if !missingFiles.isEmpty {
                missingFilesCount = missingFiles.count
                showingRestoreAlert = true
                
                // Handle the missing files in background
                Task {
                    BackupRecoveryManager.shared.handleMissingFiles { success in
                        if !success {
                            // Log error
                        }
                    }
                }
            }
        }
    }
    
}
