//
//  EnhancedJournalEntryView.swift
//  voicejournal
//
//  Created on 4/28/25.
//

import SwiftUI
import CoreData

/// An enhanced view that displays a journal entry with modern iOS design and improved functionality
struct EnhancedJournalEntryView: View {
    // MARK: - Environment
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - Properties
    
    let journalEntry: JournalEntry
    
    // MARK: - State
    
    @StateObject private var playbackViewModel: AudioPlaybackViewModel
    @State private var showDeleteConfirmation = false
    @State private var isEditingTitle = false
    @State private var entryTitle: String
    @State private var isEditingTranscription = false
    @State private var transcriptionText: String = ""
    @State private var showingEditView = false
    @State private var showingShareSheet = false
    @State private var showingOptions = false
    @State private var scrollOffset: CGFloat = 0
    @State private var showingTagSelection = false
    @State private var selectedTags = Set<Tag>()
    
    // MARK: - Initialization
    
    init(journalEntry: JournalEntry) {
        self.journalEntry = journalEntry
        
        // Initialize playback view model
        let playbackService = AudioPlaybackService()
        _playbackViewModel = StateObject(wrappedValue: AudioPlaybackViewModel(playbackService: playbackService))
        
        // Initialize title state
        _entryTitle = State(initialValue: journalEntry.title ?? "Untitled Entry")
        
        // Initialize transcription text
        if let transcription = journalEntry.transcription, let text = transcription.text {
            _transcriptionText = State(initialValue: text)
        }
        
        // Initialize selected tags
        var tags = Set<Tag>()
        if let entryTags = journalEntry.tags as? Set<Tag> {
            tags = entryTags
        }
        _selectedTags = State(initialValue: tags)
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header with title and date
                headerSection
                
                // Content sections
                VStack(spacing: 24) {
                    // Audio playback
                    if let _ = journalEntry.audioRecording {
                        audioSection
                    }
                    
                    // Transcription
                    if let transcription = journalEntry.transcription, let text = transcription.text {
                        transcriptionSection(text: text)
                    }
                    
                    // Tags - always show the tag section, even if there are no tags yet
                    tagSection(tags: journalEntry.tags ?? NSSet())
                    
                    // Metadata
                    metadataSection
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if scrollOffset > 20 {
                    Text(entryTitle)
                        .font(.headline)
                        .lineLimit(1)
                        .transition(.opacity)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        showingEditView = true
                    }) {
                        Label("Edit Entry", systemImage: "pencil")
                    }
                    
                    Button(action: {
                        isEditingTitle = true
                    }) {
                        Label("Edit Title", systemImage: "pencil.line")
                    }
                    
                    Button(action: {
                        showingShareSheet = true
                    }) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    
                    Divider()
                    
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
        .sheet(isPresented: $showingEditView) {
            JournalEntryEditView(journalEntry: journalEntry)
                .environment(\.managedObjectContext, viewContext)
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
        .sheet(isPresented: $isEditingTranscription) {
            TranscriptionEditView(
                journalEntry: journalEntry,
                transcriptionText: $transcriptionText,
                onSave: saveTranscription
            )
        }
        .sheet(isPresented: $showingShareSheet) {
            if let text = journalEntry.transcription?.text {
                ActivityViewController(activityItems: [entryTitle, text])
            } else {
                ActivityViewController(activityItems: [entryTitle])
            }
        }
        .onAppear {
            loadAudio()
        }
        .onDisappear {
            playbackViewModel.stop()
        }
    }
    
    // MARK: - Sections
    
    /// Header section with title and date
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title with edit button
            HStack {
                Text(entryTitle)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {
                    isEditingTitle = true
                }) {
                    Image(systemName: "pencil.circle")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 16)
            
            // Date with icon
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.secondary)
                
                Text(formattedDate(journalEntry.createdAt))
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
        )
        .padding(.horizontal)
    }
    
    /// Audio playback section
    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Label("Audio Recording", systemImage: "waveform")
                    .font(.headline)
                
                Spacer()
                
                if let recording = journalEntry.audioRecording {
                    Text(formatDuration(recording.duration))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Playback view
            EnhancedPlaybackView(viewModel: playbackViewModel)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
        )
    }
    
    /// Transcription section
    private func transcriptionSection(text: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header with edit button
            HStack {
                Label("Transcription", systemImage: "text.bubble")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    transcriptionText = text
                    isEditingTranscription = true
                }) {
                    Label("Edit", systemImage: "pencil")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            
            // Transcription text
            if playbackViewModel.isPlaybackInProgress {
                AttributedHighlightableText(
                    text: text,
                    highlightRange: playbackViewModel.currentHighlightRange,
                    highlightColor: .yellow.opacity(0.4),
                    textColor: .primary,
                    font: .body
                )
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
            } else {
                Text(text)
                    .font(.body)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
        )
    }
    
    /// Tags section
    private func tagSection(tags: NSSet) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header with edit button
            HStack {
                Label("Tags", systemImage: "tag")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    showingTagSelection = true
                }) {
                    Label("Edit", systemImage: "pencil")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            
            // Tags cloud
            FlowLayout(spacing: 8) {
                ForEach(Array(tags) as? [Tag] ?? [], id: \.self) { tag in
                    EnhancedTagView(tag: tag)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
        )
        .sheet(isPresented: $showingTagSelection) {
            TagSelectionView(selectedTags: $selectedTags)
                .environment(\.managedObjectContext, viewContext)
                .onDisappear {
                    updateEntryTags()
                }
        }
    }
    
    /// Metadata section
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            Label("Details", systemImage: "info.circle")
                .font(.headline)
            
            // Metadata grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                // Created date
                VStack(alignment: .leading, spacing: 4) {
                    Text("Created")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formattedDate(journalEntry.createdAt))
                        .font(.subheadline)
                }
                
                // Modified date
                VStack(alignment: .leading, spacing: 4) {
                    Text("Modified")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formattedDate(journalEntry.modifiedAt))
                        .font(.subheadline)
                }
                
                // Audio duration
                if let recording = journalEntry.audioRecording {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Duration")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(formatDuration(recording.duration))
                            .font(.subheadline)
                    }
                    
                    // File size
                    VStack(alignment: .leading, spacing: 4) {
                        Text("File Size")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(formatFileSize(recording.fileSize))
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
        )
    }
    
    // MARK: - Helper Views
    
    /// An enhanced tag view, now with icon support
    struct EnhancedTagView: View {
        let tag: Tag
        
        var body: some View {
            HStack(spacing: 6) {
                // Display icon if available, otherwise color circle
                if let iconName = tag.iconName, !iconName.isEmpty {
                    Image(systemName: iconName)
                        .font(.caption) // Adjust size as needed
                        .foregroundColor(Color(hex: tag.color ?? "#007AFF"))
                } else {
                    Circle()
                        .fill(Color(hex: tag.color ?? "#007AFF"))
                        .frame(width: 8, height: 8)
                }
                
                Text(tag.name ?? "")
                    .font(.subheadline)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(hex: tag.color ?? "#007AFF").opacity(0.15))
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color(hex: tag.color ?? "#007AFF").opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    /// A flow layout for tags
    struct FlowLayout: Layout {
        var spacing: CGFloat = 8
        
        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            let width = proposal.width ?? 0
            var height: CGFloat = 0
            var x: CGFloat = 0
            var y: CGFloat = 0
            var maxHeight: CGFloat = 0
            
            for view in subviews {
                let size = view.sizeThatFits(.unspecified)
                
                if x + size.width > width {
                    // Move to next row
                    x = 0
                    y += maxHeight + spacing
                    maxHeight = 0
                }
                
                maxHeight = max(maxHeight, size.height)
                x += size.width + spacing
            }
            
            height = y + maxHeight
            
            return CGSize(width: width, height: height)
        }
        
        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            var x = bounds.minX
            var y = bounds.minY
            var maxHeight: CGFloat = 0
            
            for view in subviews {
                let size = view.sizeThatFits(.unspecified)
                
                if x + size.width > bounds.maxX {
                    // Move to next row
                    x = bounds.minX
                    y += maxHeight + spacing
                    maxHeight = 0
                }
                
                view.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                
                maxHeight = max(maxHeight, size.height)
                x += size.width + spacing
            }
        }
    }
    
    /// Activity view controller for sharing
    struct ActivityViewController: UIViewControllerRepresentable {
        var activityItems: [Any]
        var applicationActivities: [UIActivity]? = nil
        
        func makeUIViewController(context: Context) -> UIActivityViewController {
            let controller = UIActivityViewController(
                activityItems: activityItems,
                applicationActivities: applicationActivities
            )
            return controller
        }
        
        func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
    }
    
    // MARK: - Methods
    
    /// Load the audio file for playback
    private func loadAudio() {
        guard let recording = journalEntry.audioRecording,
              let filePath = recording.filePath else {
            return
        }
        
        // Use the AudioPlaybackViewModel's method which properly handles path conversion
        Task {
            await playbackViewModel.loadAudio(from: recording)
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
    
    /// Save edited transcription
    private func saveTranscription() {
        guard let transcription = journalEntry.transcription else { return }
        
        transcription.text = transcriptionText
        transcription.modifiedAt = Date()
        journalEntry.modifiedAt = Date()
        
        do {
            try viewContext.save()
        } catch {
            print("Error saving transcription: \(error.localizedDescription)")
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
    
    /// Update the journal entry's tags based on the selected tags
    private func updateEntryTags() {
        // Get the current tags
        let currentTags = journalEntry.tags as? Set<Tag> ?? Set<Tag>()
        
        // If nothing changed, return early
        if currentTags == selectedTags {
            return
        }
        
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
        
        // Update modified date
        journalEntry.modifiedAt = Date()
        
        // Save changes
        do {
            try viewContext.save()
            print("Tags updated successfully")
        } catch {
            print("Error updating tags: \(error.localizedDescription)")
        }
    }
}

// MARK: - Preview

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let entry = JournalEntry.create(in: context)
    entry.title = "My Voice Journal Entry"
    entry.createdAt = Date()
    entry.modifiedAt = Date()
    
    // Create audio recording
    let recording = entry.createAudioRecording(filePath: "/path/to/audio.m4a")
    recording.duration = 125.5
    recording.fileSize = 1024 * 1024 * 2 // 2 MB
    
    // Create transcription
    let transcription = entry.createTranscription(text: "This is a sample transcription of a voice journal entry. It contains the text that would be generated from the audio recording using speech recognition. The transcription can be quite long and may contain multiple paragraphs of text. This allows users to read through their journal entries even when they can't listen to the audio.")
    
    // Add tags
    let _ = entry.addTag("Personal", color: "#FF5733")
    let _ = entry.addTag("Ideas", color: "#33FF57")
    let _ = entry.addTag("Important", color: "#3357FF")
    let _ = entry.addTag("Work", color: "#FFCC00")
    let _ = entry.addTag("Family", color: "#FF33F3")
    
    return NavigationView {
        EnhancedJournalEntryView(journalEntry: entry)
            .environment(\.managedObjectContext, context)
    }
}
