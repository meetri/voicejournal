//
//  voicejournalApp.swift
//  voicejournal
//
//  Created by meetri on 4/27/25.
//

import SwiftUI

@main
struct voicejournalApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
