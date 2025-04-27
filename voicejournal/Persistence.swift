//
//  Persistence.swift
//  voicejournal
//
//  Created by meetri on 4/27/25.
//

import CoreData
import CoreTransferable
import Foundation

class PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        for _ in 0..<10 {
            let newItem = JournalEntry(context: viewContext)
            newItem.createdAt = Date()
            newItem.modifiedAt = Date()
            newItem.title = "Sample Journal Entry \(Int.random(in: 1...100))"
        }
        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "voicejournal")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
            
            // Perform data migrations after successful store load
            self.performDataMigrations()
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    /// Perform any necessary data migrations
    private func performDataMigrations() {
        // Create recordings directory if needed
        FilePathUtility.createRecordingsDirectoryIfNeeded()
        
        // Migrate audio file paths from absolute to relative paths
        Task {
            let migratedCount = MigrationUtility.migrateAudioFilePaths(in: container.viewContext)
            if migratedCount > 0 {
                print("Successfully migrated \(migratedCount) audio file paths")
            }
        }
    }
}
