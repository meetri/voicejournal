//
//  JournalEntryView.swift
//  voicejournal
//
//  Created on 4/27/25.
//

import SwiftUI
import CoreData

/// A view that displays a journal entry with audio playback capabilities
struct JournalEntryView: View {
    // MARK: - Environment
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let journalEntry: JournalEntry
    
    // MARK: - State
    
    @StateObject private var playbackViewModel: AudioPlaybackViewModel
    @State private var showDeleteConfirmation = false
    @State private var isEditingTitle = false
    @State private var entryTitle: String
    
    // MARK: - Initialization
    
    init(journalEntry: JournalEntry) {
        self.journalEntry = journalEntry
        
        // Initialize playback view model
        let playbackService = AudioPlaybackService()
        _playbackViewModel = StateObject(wrappedValue: AudioPlaybackViewModel(playbackService: playbackService))
        
        // Initialize title state
        _entryTitle = State(initialValue: journalEntry.title ?? "Untitled Entry")
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Title
                titleSection
                
                // Metadata
                metadataSection
                
                // Audio playback
                if let recording = journalEntry.audioRecording {
                    PlaybackView(viewModel: playbackViewModel)
                        .padding(.vertical)
                }
                
                // Transcription
                if let transcription = journalEntry.transcription, let text = transcription.text {
                    transcriptionSection(text: text)
                }
                
                // Tags
                if let tags = journalEntry.tags, tags.count > 0 {
                    tagSection(tags: tags)
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Journal Entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        isEditingTitle = true
                    }) {
                        Label("Edit Title", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive, action: {
                        showDeleteConfirmation = true
                    }) {
                        Label("Delete Entry", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Edit Title", isPresented: $isEditingTitle) {
            TextField("Title", text: $entryTitle)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                updateEntryTitle()
            }
        }
        .alert("Delete Entry", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteEntry()
            }
        } message: {
            Text("Are you sure you want to delete this journal entry? This action cannot be undone.")
        }
        .alert("Playback Error", isPresented: $playbackViewModel.showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(playbackViewModel.errorMessage ?? "An unknown error occurred")
        }
        .onAppear {
            loadAudio()
        }
        .onDisappear {
            playbackViewModel.stop()
        }
    }
    
    // MARK: - Subviews
    
    private var titleSection: some View {
        HStack {
            Text(entryTitle)
                .font(.title)
                .fontWeight(.bold)
            
            Spacer()
            
            Button(action: {
                isEditingTitle = true
            }) {
                Image(systemName: "pencil")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.secondary)
                
                Text(formattedDate(journalEntry.createdAt))
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
            
            if let recording = journalEntry.audioRecording {
                HStack {
                    Image(systemName: "waveform")
                        .foregroundColor(.secondary)
                    
                    Text(formatDuration(recording.duration))
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
                
                HStack {
                    Image(systemName: "doc")
                        .foregroundColor(.secondary)
                    
                    Text(formatFileSize(recording.fileSize))
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func transcriptionSection(text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transcription")
                .font(.headline)
                .padding(.bottom, 4)
            
            Text(text)
                .font(.body)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
    }
    
    private func tagSection(tags: NSSet) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags")
                .font(.headline)
                .padding(.bottom, 4)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(Array(tags) as? [Tag] ?? [], id: \.self) { tag in
                        TagView(tag: tag)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    /// A view that displays a tag
    struct TagView: View {
        let tag: Tag
        
        var body: some View {
            Text(tag.name ?? "")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: tag.color ?? "#007AFF"))
                .foregroundColor(.white)
                .cornerRadius(12)
        }
    }
    
    // MARK: - Methods
    
    /// Load the audio file for playback
    private func loadAudio() {
        guard let recording = journalEntry.audioRecording,
              let filePath = recording.filePath else {
            print("DEBUG: JournalEntryView - No audio recording or filePath is nil")
            return
        }
        
        print("DEBUG: JournalEntryView - Loading audio from filePath: \(filePath)")
        
        // Use the AudioPlaybackViewModel's method which properly handles path conversion
        Task {
            await playbackViewModel.loadAudio(from: recording)
            print("DEBUG: JournalEntryView - Audio loading completed, isAudioLoaded: \(playbackViewModel.isAudioLoaded)")
        }
    }
    
    /// Update the journal entry title
    private func updateEntryTitle() {
        journalEntry.title = entryTitle
        journalEntry.modifiedAt = Date()
        
        do {
            try viewContext.save()
        } catch {
            print("Error saving title: \(error.localizedDescription)")
        }
    }
    
    /// Delete the journal entry
    private func deleteEntry() {
        // Stop playback
        playbackViewModel.stop()
        
        // Delete the entry
        viewContext.delete(journalEntry)
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error deleting entry: \(error.localizedDescription)")
        }
    }
    
    /// Format a date to a readable string
    private func formattedDate(_ date: Date?) -> String {
        guard let date = date else { return "Unknown date" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        return formatter.string(from: date)
    }
    
    /// Format duration in seconds to MM:SS
    private func formatDuration(_ duration: Double) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    /// Format file size in bytes to human-readable string
    private func formatFileSize(_ size: Int64) -> String {
        let byteCountFormatter = ByteCountFormatter()
        byteCountFormatter.allowedUnits = [.useKB, .useMB]
        byteCountFormatter.countStyle = .file
        
        return byteCountFormatter.string(fromByteCount: size)
    }
}

// MARK: - Extensions

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let entry = JournalEntry.create(in: context)
    entry.title = "My Voice Journal Entry"
    entry.createdAt = Date()
    
    // Create audio recording
    let recording = entry.createAudioRecording(filePath: "/path/to/audio.m4a")
    recording.duration = 125.5
    recording.fileSize = 1024 * 1024 * 2 // 2 MB
    
    // Create transcription
    let transcription = entry.createTranscription(text: "This is a sample transcription of a voice journal entry. It contains the text that would be generated from the audio recording using speech recognition.")
    
    // Add tags
    let _ = entry.addTag("Personal", color: "#FF5733")
    let _ = entry.addTag("Ideas", color: "#33FF57")
    let _ = entry.addTag("Important", color: "#3357FF")
    
    return NavigationView {
        JournalEntryView(journalEntry: entry)
            .environment(\.managedObjectContext, context)
    }
}
