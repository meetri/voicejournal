//
//  voicejournalApp.swift
//  voicejournal
//
//  Created by meetri on 4/27/25.
//

import SwiftUI
import CoreData

// Import our utility files
@_exported import Foundation

@main
struct voicejournalApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var authService = AuthenticationService()
    @State private var themeManager = ThemeManager()
    
    // Create a UIApplicationDelegateAdaptor to handle app lifecycle events
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // Initialize all utility files
        ImportUtility.initializeAll()
    }

    var body: some Scene {
        WindowGroup {
            if authService.isAuthenticated {
                ContentView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .environmentObject(authService)
                    .environment(\.themeManager, themeManager)
            } else {
                AuthenticationView()
                    .environmentObject(authService)
                    .environment(\.themeManager, themeManager)
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
}
