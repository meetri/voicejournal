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
                    .preferredColorScheme(colorScheme(for: themeManager.themeID))
                    .onAppear {
                        updateSystemAppearance()
                    }
            } else {
                AuthenticationView()
                    .environmentObject(authService)
                    .environment(\.themeManager, themeManager)
                    .preferredColorScheme(colorScheme(for: themeManager.themeID))
                    .onAppear {
                        updateSystemAppearance()
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
    
    private func colorScheme(for themeID: ThemeID) -> ColorScheme? {
        switch themeID {
        case .light:
            return .light
        case .dark, .futuristic:
            return .dark
        }
    }
    
    private func updateSystemAppearance() {
        // Apply theme to navigation bar
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(themeManager.theme.surface)
        appearance.titleTextAttributes = [.foregroundColor: UIColor(themeManager.theme.text)]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(themeManager.theme.text)]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        // Apply theme to tab bar
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(themeManager.theme.surface)
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        
        // Apply theme to table view
        UITableView.appearance().backgroundColor = UIColor(themeManager.theme.background)
        UITableView.appearance().separatorColor = UIColor(themeManager.theme.surface)
        
        // Apply theme to collection view (for calendar)
        UICollectionView.appearance().backgroundColor = UIColor(themeManager.theme.background)
    }
}
