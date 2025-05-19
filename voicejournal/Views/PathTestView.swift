//
//  PathTestView.swift
//  voicejournal
//
//  Created on 4/27/25.
//

import SwiftUI
import CoreData

struct PathTestView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: JournalEntry.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \JournalEntry.createdAt, ascending: false)]
    )
    private var entries: FetchedResults<JournalEntry>
    
    @State private var testResults: [String] = []
    
    var body: some View {
        VStack {
            HStack {
                Button("Run Path Tests") {
                    runTests()
                }
                .padding()
                
                Button("Run Migration") {
                    runMigration()
                }
                .padding()
            }
            
            List {
                Section("Test Results") {
                    ForEach(testResults, id: \.self) { result in
                        Text(result)
                            .font(.caption)
                    }
                }
                
                Section("Journal Entries") {
                    ForEach(entries) { entry in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(entry.title ?? "Untitled")
                                .font(.headline)
                            
                            if let recording = entry.audioRecording {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Audio Recording:")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    if let filePath = recording.filePath {
                                        Text("File Path: \(filePath)")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                        
                                        let absoluteURL = FilePathUtility.toAbsolutePath(from: filePath)
                                        Text("Absolute URL: \(absoluteURL.path)")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                        
                                        let fileExists = FileManager.default.fileExists(atPath: absoluteURL.path)
                                        Text("File Exists: \(fileExists ? "✓" : "✗")")
                                            .font(.caption)
                                            .foregroundColor(fileExists ? .green : .red)
                                        
                                        // Check if file path has container ID
                                        let hasContainerID = filePath.contains("/Containers/")
                                        Text("Has Container ID: \(hasContainerID ? "YES (problematic)" : "NO (good)")")
                                            .font(.caption)
                                            .foregroundColor(hasContainerID ? .red : .green)
                                    }
                                    
                                    if let originalPath = recording.originalFilePath {
                                        Text("Original Path: \(originalPath)")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                    
                                    Text("Is Encrypted: \(recording.isEncrypted ? "Yes" : "No")")
                                        .font(.caption)
                                        .foregroundColor(.purple)
                                }
                                .padding(.vertical, 4)
                            }
                            
                            if let baseEncryptedPath = entry.baseEncryptedAudioPath {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Base Encrypted Path:")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Text(baseEncryptedPath)
                                        .font(.caption)
                                        .foregroundColor(.indigo)
                                    
                                    let absoluteURL = FilePathUtility.toAbsolutePath(from: baseEncryptedPath)
                                    Text("Absolute URL: \(absoluteURL.path)")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                    
                                    let fileExists = FileManager.default.fileExists(atPath: absoluteURL.path)
                                    Text("File Exists: \(fileExists ? "✓" : "✗")")
                                        .font(.caption)
                                        .foregroundColor(fileExists ? .green : .red)
                                    
                                    // Check if file path has container ID
                                    let hasContainerID = baseEncryptedPath.contains("/Containers/")
                                    Text("Has Container ID: \(hasContainerID ? "YES (problematic)" : "NO (good)")")
                                        .font(.caption)
                                        .foregroundColor(hasContainerID ? .red : .green)
                                }
                                .padding(.vertical, 4)
                            }
                            
                            Divider()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Path Test")
    }
    
    func runTests() {
        testResults.removeAll()
        
        // Test recordings directory
        let recordingsDir = FilePathUtility.recordingsDirectory
        testResults.append("Recordings Dir: \(recordingsDir.path)")
        testResults.append("Recordings Dir Exists: \(FileManager.default.fileExists(atPath: recordingsDir.path))")
        
        // Test conversion
        let testFilename = "recording_123456.m4a"
        let absolutePath = recordingsDir.appendingPathComponent(testFilename)
        let relativePath = FilePathUtility.toRelativePath(from: absolutePath.path)
        let convertedBack = FilePathUtility.toAbsolutePath(from: relativePath)
        
        testResults.append("---")
        testResults.append("Test conversion:")
        testResults.append("Original: \(absolutePath.path)")
        testResults.append("Relative: \(relativePath)")
        testResults.append("Converted Back: \(convertedBack.path)")
        testResults.append("Paths Match: \(absolutePath.path == convertedBack.path)")
        
        // Test with actual files
        if let recordings = try? viewContext.fetch(AudioRecording.fetchRequest() as NSFetchRequest<AudioRecording>) {
            testResults.append("---")
            testResults.append("Found \(recordings.count) recordings")
            
            for (index, recording) in recordings.enumerated() {
                testResults.append("---")
                testResults.append("Recording \(index + 1):")
                
                if let path = recording.filePath {
                    testResults.append("Path: \(path)")
                    testResults.append("Has Container ID: \(path.contains("/Containers/") ? "YES" : "NO")")
                    
                    let absPath = FilePathUtility.toAbsolutePath(from: path)
                    testResults.append("Absolute: \(absPath.path)")
                    testResults.append("Exists: \(FileManager.default.fileExists(atPath: absPath.path))")
                }
                
                if recording.isEncrypted {
                    testResults.append("Is Encrypted: YES")
                    if let originalPath = recording.originalFilePath {
                        testResults.append("Original Path: \(originalPath)")
                        testResults.append("Original Has Container ID: \(originalPath.contains("/Containers/") ? "YES" : "NO")")
                    }
                }
            }
        }
        
        testResults.append("---")
        testResults.append("App Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
        
        // Show current app container
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        testResults.append("Current Documents: \(documentsDir.path)")
    }
    
    func runMigration() {
        testResults.removeAll()
        
        // Check if migration is needed
        let needsMigration = PathMigrationUtility.checkIfMigrationNeeded(context: viewContext)
        testResults.append("Migration needed: \(needsMigration)")
        
        if needsMigration {
            testResults.append("Running migration...")
            PathMigrationUtility.migratePathsIfNeeded(context: viewContext)
            testResults.append("Migration completed!")
        } else {
            testResults.append("No migration needed - all paths are already relative")
        }
        
        // Re-run tests to show the results
        runTests()
    }
}

#Preview {
    NavigationView {
        PathTestView()
    }
}