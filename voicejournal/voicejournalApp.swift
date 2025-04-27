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
            } else {
                AuthenticationView()
                    .environmentObject(authService)
            }
        }
    }
}
