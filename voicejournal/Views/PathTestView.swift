//
//  PathTestView.swift
//  voicejournal
//
//  Created on 4/27/25.
//

import SwiftUI

struct PathTestView: View {
    @State private var testResults: [String] = []
    
    var body: some View {
        VStack {
            Button("Run Path Tests") {
                runTests()
            }
            .padding()
            
            List(testResults, id: \.self) { result in
                Text(result)
                    .font(.caption)
            }
        }
        .navigationTitle("Path Tests")
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
        
        testResults.append("Original: \(absolutePath.path)")
        testResults.append("Relative: \(relativePath)")
        testResults.append("Converted Back: \(convertedBack.path)")
        testResults.append("Paths Match: \(absolutePath.path == convertedBack.path)")
        
        // Test with actual file
        if let firstRecording = try? PersistenceController.shared.container.viewContext.fetch(AudioRecording.fetchRequest()).first {
            testResults.append("---")
            testResults.append("First Recording:")
            testResults.append("FilePath: \(firstRecording.filePath ?? "nil")")
            if let path = firstRecording.filePath {
                let absPath = FilePathUtility.toAbsolutePath(from: path)
                testResults.append("Absolute: \(absPath.path)")
                testResults.append("Exists: \(FileManager.default.fileExists(atPath: absPath.path))")
            }
        }
    }
}

#Preview {
    NavigationView {
        PathTestView()
    }
}