//
//  AppDelegate.swift
//  voicejournal
//
//  Created on 5/4/25.
//

import UIKit
import CoreData

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Reset all granted tag access on app launch
        EncryptedTagsAccessManager.shared.clearAllAccess()
        
        // Perform path migration if needed
        let context = PersistenceController.shared.container.viewContext
        PathMigrationUtility.migratePathsIfNeeded(context: context)
        
        return true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Reset all granted tag access when app terminates
        EncryptedTagsAccessManager.shared.clearAllAccess()
    }
}
