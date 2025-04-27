//
//  ImportUtility.swift
//  voicejournal
//
//  Created on 4/27/25.
//

import Foundation

/// This file ensures that all utility files are properly imported in the project
/// It's a workaround for the fact that Swift doesn't have a way to import local files
/// without adding them to the project.
///
/// The FilePathUtility and MigrationUtility classes are used throughout the app
/// to handle file paths and data migrations.

// This is a utility class that provides access to other utility classes
// and ensures they are properly initialized.
class ImportUtility {
    // Static references to utility classes
    static let filePathUtility = FilePathUtility.self
    static let migrationUtility = MigrationUtility.self
    
    // Shared instance for singleton pattern
    static let shared = ImportUtility()
    
    // Private initializer for singleton pattern
    private init() {
        // Initialize any required resources
        print("ImportUtility initialized")
    }
    
    // Method to ensure all utilities are initialized
    static func initializeAll() {
        // Access the shared instance to trigger initialization
        _ = ImportUtility.shared
        
        // Ensure FilePathUtility is initialized
        FilePathUtility.createRecordingsDirectoryIfNeeded()
        
        print("All utilities initialized")
    }
}
