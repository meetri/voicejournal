//
//  ContentView.swift
//  voicejournal
//
//  Created by meetri on 4/27/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authService: AuthenticationService
    
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Recording tab
            RecordingView()
                .tabItem {
                    Label("Record", systemImage: "mic.fill")
                }
                .tag(0)
            
            // Journal entries tab
            JournalEntriesView()
                .tabItem {
                    Label("Journal", systemImage: "book.fill")
                }
                .tag(1)
            
            // Settings tab
            SettingsTabView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
        }
        .accentColor(.blue)
    }
}

/// View for displaying journal entries
struct JournalEntriesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \JournalEntry.createdAt, ascending: false)],
        animation: .default)
    private var entries: FetchedResults<JournalEntry>
    
    var body: some View {
        NavigationView {
            List {
                ForEach(entries) { entry in
                    NavigationLink {
                        JournalEntryView(journalEntry: entry)
                    } label: {
                        JournalEntryRow(entry: entry)
                    }
                }
                .onDelete(perform: deleteEntries)
            }
            .navigationTitle("Journal Entries")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            
            // Placeholder for when no entry is selected
            Text("Select an entry")
                .font(.title2)
                .foregroundColor(.secondary)
        }
    }
    
    private func deleteEntries(offsets: IndexSet) {
        withAnimation {
            offsets.map { entries[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Error deleting entries: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

/// Row view for a journal entry in the list
struct JournalEntryRow: View {
    let entry: JournalEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.title ?? "Untitled Entry")
                .font(.headline)
            
            HStack {
                if entry.audioRecording != nil {
                    Image(systemName: "waveform")
                        .foregroundColor(.blue)
                }
                
                if let createdAt = entry.createdAt {
                    Text(createdAt, formatter: itemFormatter)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// Detail view for a journal entry
struct JournalEntryDetailView: View {
    let entry: JournalEntry
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Title
                Text(entry.title ?? "Untitled Entry")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Date
                if let createdAt = entry.createdAt {
                    Text("Created: \(createdAt, formatter: itemFormatter)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Audio recording
                if let recording = entry.audioRecording {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Audio Recording")
                            .font(.headline)
                        
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading) {
                                Text("Duration: \(formatDuration(recording.duration))")
                                Text("Size: \(formatFileSize(recording.fileSize))")
                            }
                            .font(.subheadline)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    .padding(.vertical)
                }
                
                // Transcription
                if let transcription = entry.transcription, let text = transcription.text {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Transcription")
                            .font(.headline)
                        
                        Text(text)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                    .padding(.vertical)
                } else {
                    Text("No transcription available")
                        .italic()
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    /// Format duration in seconds to MM:SS
    private func formatDuration(_ duration: Double) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// Format file size in bytes to human-readable string
    private func formatFileSize(_ size: Int64) -> String {
        let byteCountFormatter = ByteCountFormatter()
        byteCountFormatter.allowedUnits = [.useKB, .useMB]
        byteCountFormatter.countStyle = .file
        
        return byteCountFormatter.string(fromByteCount: size)
    }
}

/// Settings tab view
struct SettingsTabView: View {
    @EnvironmentObject private var authService: AuthenticationService
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Security")) {
                    Button("Lock App") {
                        authService.lock()
                    }
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(AuthenticationService())
}
