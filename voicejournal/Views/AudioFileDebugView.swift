//
//  AudioFileDebugView.swift
//  voicejournal
//
//  Created on 4/27/25.
//

import SwiftUI
import CoreData

struct AudioFileDebugView: View {
    @FetchRequest(
        entity: AudioRecording.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \AudioRecording.recordedAt, ascending: false)]
    ) var recordings: FetchedResults<AudioRecording>
    
    var body: some View {
        List(recordings) { recording in
            VStack(alignment: .leading, spacing: 8) {
                Text("Recorded: \(recording.recordedAt?.formatted() ?? "Unknown")")
                    .font(.headline)
                
                Group {
                    Text("FilePath: \(recording.filePath ?? "nil")")
                    Text("Absolute Path: \(recording.filePath.map { FilePathUtility.toAbsolutePath(from: $0).path } ?? "nil")")
                    Text("File Exists: \(recording.fileExists ? "YES" : "NO")")
                    Text("Is Missing: \(recording.isMissingFile ? "YES" : "NO")")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                if let path = recording.filePath {
                    let absoluteURL = FilePathUtility.toAbsolutePath(from: path)
                    let exists = FileManager.default.fileExists(atPath: absoluteURL.path)
                    
                    Text("Direct Check: \(exists ? "EXISTS" : "MISSING")")
                        .font(.caption)
                        .foregroundColor(exists ? .green : .red)
                }
                
                Divider()
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("Audio File Debug")
    }
}

#Preview {
    NavigationView {
        AudioFileDebugView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}