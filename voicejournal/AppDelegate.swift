//
//  AppDelegate.swift
//  voicejournal
//
//  Created on 5/4/25.
//

import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Reset all granted tag access on app launch
        EncryptedTagsAccessManager.shared.clearAllAccess()
        return true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Reset all granted tag access when app terminates
        EncryptedTagsAccessManager.shared.clearAllAccess()
    }
}
