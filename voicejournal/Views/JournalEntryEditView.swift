//
//  JournalEntryEditView.swift
//  voicejournal
//
//  Created on 4/28/25.
//

import SwiftUI
import CoreData

/// A view for editing existing journal entries
struct JournalEntryEditView: View {
    // MARK: - Environment
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let journalEntry: JournalEntry
    
    // MARK: - State
    
    @State private var entryTitle: String
    @State private var selectedTags: Set<Tag>
    @State private var showingTagSelection = false
    @State private var isEditingTranscription = false
    @State private var transcriptionText: String = ""
    @State private var showingDiscardAlert = false
    @State private var showingDeleteAlert = false
    @State private var showingRecordingView = false
    @State private var suggestedTagNames: [String] = [] // State for suggested tags
    
    // Fetch existing tags for suggestion logic
    @FetchRequest(
        entity: Tag.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
    ) private var allTags: FetchedResults<Tag>
    
    // MARK: - Initialization
    
    init(journalEntry: JournalEntry) {
        self.journalEntry = journalEntry
        
        // Initialize state with entry data
        _entryTitle = State(initialValue: journalEntry.title ?? "Untitled Entry")
        
        // Initialize selected tags
        var tags = Set<Tag>()
        if let entryTags = journalEntry.tags as? Set<Tag> {
            tags = entryTags
        }
        _selectedTags = State(initialValue: tags)
        
        // Initialize transcription text
        if let transcription = journalEntry.transcription, let text = transcription.text {
            _transcriptionText = State(initialValue: text)
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            Form {
                // Title section
                Section(header: Text("Title")) {
                    TextField("Entry Title", text: $entryTitle)
                }
                
                // Tags section
                Section(header: 
                    HStack {
                        Text("Tags")
                        Spacer()
                        Button(action: {
                            showingTagSelection = true
                        }) {
                            Image(systemName: "plus.circle")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                ) {
                    if selectedTags.isEmpty {
                        Text("No tags selected")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        // Display selected tags
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(selectedTags).sorted(by: { $0.name ?? "" < $1.name ?? "" })) { tag in
                                    if let name = tag.name, let color = tag.color {
                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(Color(hex: color))
                                                .frame(width: 8, height: 8)
                                            
                                            Text(name)
                                                .font(.subheadline)
                                            
                                            Button(action: {
                                                selectedTags.remove(tag)
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            .buttonStyle(BorderlessButtonStyle())
                                        }
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                        .background(Color(hex: color).opacity(0.1))
                                        .cornerRadius(12)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // Display suggested tags if available
                    if !suggestedTagNames.isEmpty {
                        Divider()
                        VStack(alignment: .leading) {
                            Text("Suggestions:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(suggestedTagNames, id: \.self) { tagName in
                                        Button(action: {
                                            addSuggestedTag(tagName)
                                        }) {
                                            Text(tagName)
                                                .font(.caption)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.gray.opacity(0.2))
                                                .foregroundColor(.primary)
                                                .cornerRadius(10)
                                        }
                                        .buttonStyle(BorderlessButtonStyle())
                                    }
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                
                // Recording section
                if let recording = journalEntry.audioRecording {
                    Section(header: Text("Recording")) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "waveform")
                                    .foregroundColor(.blue)
                                Text("Audio Recording")
                                    .font(.headline)
                            }
                            
                            HStack {
                                Text("Duration:")
                                Spacer()
                                Text(formatDuration(recording.duration))
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            
                            HStack {
                                Text("File Size:")
                                Spacer()
                                Text(formatFileSize(recording.fileSize))
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            
                            HStack {
                                Button(action: {
                                    // Navigate to playback
                                }) {
                                    Label("Play Recording", systemImage: "play.circle")
                                }
                                .buttonStyle(BorderedButtonStyle())
                                
                                Spacer()
                                
                                Button(action: {
                                    showingRecordingView = true
                                }) {
                                    Label("Re-record", systemImage: "mic.fill")
                                }
                                .buttonStyle(BorderedButtonStyle())
                            }
                            .padding(.top, 4)
                        }
                    }
                } else {
                    Section(header: Text("Recording")) {
                        Button(action: {
                            showingRecordingView = true
                        }) {
                            HStack {
                                Image(systemName: "mic.fill")
                                    .foregroundColor(.red)
                                Text("Add Recording")
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
                
                // Transcription section
                if let transcription = journalEntry.transcription, let text = transcription.text {
                    Section(header: 
                        HStack {
                            Text("Transcription")
                            Spacer()
                            Button(action: {
                                transcriptionText = text
                                isEditingTranscription = true
                            }) {
                                Image(systemName: "pencil")
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                    ) {
                        Text(text)
                            .font(.body)
                            .padding(.vertical, 4)
                    }
                }
                
                // Danger zone
                Section(header: Text("Danger Zone")) {
                    Button(role: .destructive, action: {
                        showingDeleteAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Entry")
                        }
                    }
                }
            }
            .navigationTitle("Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingDiscardAlert = true
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                }
            }
            .sheet(isPresented: $showingTagSelection) {
                TagSelectionView(selectedTags: $selectedTags)
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(isPresented: $isEditingTranscription) {
                TranscriptionEditView(
                    journalEntry: journalEntry,
                    transcriptionText: $transcriptionText,
                    onSave: saveTranscription
                )
            }
            .sheet(isPresented: $showingRecordingView) {
                RecordingView(
                    context: viewContext,
                    existingEntry: journalEntry,
                    onComplete: {
                        showingRecordingView = false
                    }
                )
            }
            .alert("Discard Changes?", isPresented: $showingDiscardAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Discard", role: .destructive) {
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to discard your changes? This action cannot be undone.")
            }
            .alert("Delete Entry?", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteEntry()
                }
            } message: {
                Text("Are you sure you want to delete this entry? This action cannot be undone.")
            }
            .onAppear {
                // Generate initial suggestions when the view appears
                generateTagSuggestions()
            }
            .onChange(of: transcriptionText) { _, _ in
                 // Regenerate suggestions if transcription text changes (e.g., after editing)
                 generateTagSuggestions()
             }
        }
    }
    
    // MARK: - Methods
    
    /// Save changes to the journal entry
    private func saveChanges() {
        // Update title
        journalEntry.title = entryTitle
        
        // Update tags
        if let currentTags = journalEntry.tags as? Set<Tag> {
            // Remove tags that are no longer selected
            for tag in currentTags {
                if !selectedTags.contains(tag) {
                    journalEntry.removeFromTags(tag)
                }
            }
            
            // Add new tags
            for tag in selectedTags {
                if !currentTags.contains(tag) {
                    journalEntry.addToTags(tag)
                }
            }
        } else {
            // Add all selected tags
            for tag in selectedTags {
                journalEntry.addToTags(tag)
            }
        }
        
        // Update modified date
        journalEntry.modifiedAt = Date()
        
        // Save the context
        do {
            try viewContext.save()
            dismiss()
        } catch {
            // Error occurred
        }
    }
    
    /// Save edited transcription and regenerate suggestions
    private func saveTranscription() {
        guard let transcription = journalEntry.transcription else { return }
        
        transcription.text = transcriptionText
        transcription.modifiedAt = Date()
        journalEntry.modifiedAt = Date()
        
        do {
            try viewContext.save()
            // Regenerate suggestions after saving new transcription text
            generateTagSuggestions()
        } catch {
            // Error occurred
        }
    }
    
    /// Generate tag suggestions based on the current transcription text
    private func generateTagSuggestions() {
        // Use the placeholder suggestion logic from Tag+Extensions
        // Pass the current transcription text and the fetched list of all tags
        suggestedTagNames = Tag.suggestTags(
            for: transcriptionText,
            existingTags: Array(allTags),
            context: viewContext
        )
        // Filter out suggestions that are already selected
        suggestedTagNames.removeAll { suggestedName in
            selectedTags.contains { $0.name?.lowercased() == suggestedName.lowercased() }
        }
    }
    
    /// Add a suggested tag to the selected tags set
    private func addSuggestedTag(_ tagName: String) {
        // Find or create the tag using the method from Tag+Extensions
        let tag = Tag.findOrCreate(name: tagName, in: viewContext)
        selectedTags.insert(tag)
        // Remove the tag from suggestions once added
        suggestedTagNames.removeAll { $0.lowercased() == tagName.lowercased() }
    }
    
    /// Delete the journal entry
    private func deleteEntry() {
        viewContext.delete(journalEntry)
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            // Error occurred
        }
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
    _ = entry.createTranscription(text: "This is a sample transcription of a voice journal entry. It contains the text that would be generated from the audio recording using speech recognition.")
    
    // Add tags
    let _ = entry.addTag("Personal", color: "#FF5733")
    let _ = entry.addTag("Ideas", color: "#33FF57")
    
    return JournalEntryEditView(journalEntry: entry)
        .environment(\.managedObjectContext, context)
}
