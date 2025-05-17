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
    @State private var themeManager = ThemeManager()
    
    // Create a UIApplicationDelegateAdaptor to handle app lifecycle events
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    

    var body: some Scene {
        WindowGroup {
            if authService.isAuthenticated {
                ContentView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .environmentObject(authService)
                    .environment(\.themeManager, themeManager)
                    .preferredColorScheme(colorScheme(for: themeManager.currentThemeID))
                    .onAppear {
                        themeManager.setContext(persistenceController.container.viewContext)
                        ThemeUtility.updateSystemAppearance(with: themeManager.theme)
                    }
            } else {
                AuthenticationView()
                    .environmentObject(authService)
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
    
}
