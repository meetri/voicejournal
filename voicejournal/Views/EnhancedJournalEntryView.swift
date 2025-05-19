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
    @Environment(\.themeManager) private var themeManager
    
    // MARK: - Properties
    
    @ObservedObject var journalEntry: JournalEntry
    
    // MARK: - State
    
    @StateObject private var playbackViewModel: AudioPlaybackViewModel
    @State private var showDeleteConfirmation = false
    @State private var entryTitle: String
    @State private var showingEditView = false
    @State private var showingShareSheet = false
    @State private var showingOptions = false
    @State private var scrollOffset: CGFloat = 0
    @State private var showEnhancedTranscription = false
    @State private var showAIAnalysis = false
    
    // MARK: - Initialization
    
    init(journalEntry: JournalEntry) {
        self.journalEntry = journalEntry
        
        // Initialize playback view model
        let playbackService = AudioPlaybackService()
        _playbackViewModel = StateObject(wrappedValue: AudioPlaybackViewModel(playbackService: playbackService))
        
        // Initialize title state
        _entryTitle = State(initialValue: journalEntry.title ?? "Untitled Entry")
    }
    
    // MARK: - Computed Properties
    
    private var shareItems: [Any] {
        var items: [Any] = [entryTitle]
        
        // Add transcription text if available
        if let text = journalEntry.transcription?.text {
            items.append(text)
        }
        
        // Add audio file if available
        if let audioURL = prepareAudioForSharing() {
            items.append(audioURL)
        }
        
        return items
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 0) {
                // Header with title and date
                headerSection
                    .padding(.bottom, 24)
                
                // Content sections
                VStack(spacing: 24) {
                    // Audio playback
                    if let _ = journalEntry.audioRecording {
                        audioSection
                    }
                    
                    // Always show transcription section
                    // EncryptedContentView will handle decryption internally when needed
                    if let transcription = journalEntry.transcription, let text = transcription.text {
                        transcriptionSection(text: text)
                    } else if journalEntry.transcription != nil {
                        // Transcription exists but needs decryption
                        EncryptedContentView(journalEntry: journalEntry)
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
        .navigationBarItems(
            trailing: Menu {
                Button(action: {
                    showingEditView = true
                }) {
                    Label("Edit Entry", systemImage: "pencil")
                }
                
                Button(action: {
                    shareEntry()
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
        )
        .sheet(isPresented: $showingEditView) {
            JournalEntryEditView(journalEntry: journalEntry)
                .environment(\.managedObjectContext, viewContext)
        }
        .alert("Delete Entry", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteEntry()
            }
        } message: {
            Text("Are you sure you want to delete this journal entry? This action cannot be undone.")
        }
        .sheet(isPresented: $showingShareSheet) {
            ActivityViewController(activityItems: shareItems)
        }
        .onAppear {
            loadAudio()
            
            // Debug logging for transcription state
            if let transcription = journalEntry.transcription {
                print("📊 [EnhancedJournalEntryView.onAppear] Transcription state:")
                print("  - Raw text: \(transcription.rawText?.count ?? 0) characters")
                print("  - Enhanced text: \(transcription.enhancedText?.count ?? 0) characters")
                print("  - AI analysis: \(transcription.aiAnalysis?.count ?? 0) characters")
                print("  - Encrypted enhanced: \(transcription.encryptedEnhancedText?.count ?? 0) bytes")
                print("  - Encrypted AI: \(transcription.encryptedAIAnalysis?.count ?? 0) bytes")
                print("  - Entry has encrypted content: \(journalEntry.hasEncryptedContent)")
                print("  - Entry is decrypted: \(journalEntry.isDecrypted)")
                print("  - Entry is base encrypted: \(journalEntry.isBaseEncrypted)")
                print("  - Entry is base decrypted: \(journalEntry.isBaseDecrypted)")
                
                // Try to decrypt if needed
                if journalEntry.hasEncryptedContent && transcription.encryptedEnhancedText != nil && transcription.enhancedText == nil {
                    print("  - Attempting to decrypt enhanced text...")
                    if journalEntry.decryptWithGlobalAccess() {
                        print("  - Decryption succeeded")
                    } else {
                        print("  - Decryption failed")
                    }
                }
            }
        }
        .onDisappear {
            playbackViewModel.stop()
        }
    }
    
    // MARK: - Sections
    
    /// Header section with title and date
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title
            HStack {
                Text(entryTitle)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
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
                .fill(themeManager.theme.cellBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(themeManager.theme.cellBorder, lineWidth: 1)
                )
                .shadow(color: themeManager.theme.shadowColor, radius: 3, x: 0, y: 2)
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
                    if recording.isMissingFile {
                        MissingAudioIndicator()
                    } else {
                        Text(formatDuration(recording.duration))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Check if audio file is missing
            if let recording = journalEntry.audioRecording, recording.isMissingFile {
                MissingAudioView()
            } else {
                // Playback view
                EnhancedPlaybackView(viewModel: playbackViewModel)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeManager.theme.cellBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(themeManager.theme.cellBorder, lineWidth: 1)
                )
                .shadow(color: themeManager.theme.shadowColor, radius: 3, x: 0, y: 2)
        )
    }
    
    /// Transcription section
    private func transcriptionSection(text: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Label("Transcription", systemImage: "text.bubble")
                    .font(.headline)
                
                Spacer()
                
                // Toggle between different content types
                if let transcription = journalEntry.transcription {
                    Menu {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showEnhancedTranscription = false
                                showAIAnalysis = false
                            }
                        }) {
                            Label("Raw", systemImage: "text.alignleft")
                        }
                        
                        if transcription.enhancedText != nil {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showEnhancedTranscription = true
                                    showAIAnalysis = false
                                }
                            }) {
                                Label("Enhanced", systemImage: "sparkles")
                            }
                        }
                        
                        if transcription.aiAnalysis != nil {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showEnhancedTranscription = false
                                    showAIAnalysis = true
                                }
                            }) {
                                Label("AI Analysis", systemImage: "brain")
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: showAIAnalysis ? "brain" : (showEnhancedTranscription ? "sparkles" : "text.alignleft"))
                                .font(.system(size: 14))
                            Text(showAIAnalysis ? "Analysis" : (showEnhancedTranscription ? "Enhanced" : "Raw"))
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(showAIAnalysis ? Color.green.opacity(0.15) : (showEnhancedTranscription ? Color.blue.opacity(0.15) : Color.gray.opacity(0.15)))
                        )
                        .foregroundColor(showAIAnalysis ? .green : (showEnhancedTranscription ? .blue : .gray))
                    }
                }
            }
            
            // Display content based on type
            if showAIAnalysis, let analysis = journalEntry.transcription?.aiAnalysis {
                // Show AI analysis in a scrollable markdown view
                ScrollView {
                    Text(analysis)
                        .font(.body)
                        .padding()
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 400)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(themeManager.theme.surface)
                )
            } else if showEnhancedTranscription, let enhanced = journalEntry.transcription?.enhancedText {
                // Show enhanced transcription
                if playbackViewModel.isPlaybackInProgress {
                    AttributedHighlightableText(
                        text: enhanced,
                        highlightRange: playbackViewModel.currentHighlightRange,
                        highlightColor: .yellow.opacity(0.4),
                        textColor: .primary,
                        font: .body
                    )
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(themeManager.theme.surface)
                    )
                } else {
                    Text(enhanced)
                        .font(.body)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(themeManager.theme.surface)
                        )
                }
            } else if showEnhancedTranscription && journalEntry.transcription?.encryptedEnhancedText != nil {
                // Enhanced text is encrypted but not decrypted yet
                Text("Enhanced transcription is encrypted. Please decrypt to view.")
                    .font(.body)
                    .foregroundColor(themeManager.theme.textSecondary)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(themeManager.theme.surface)
                    )
            } else {
                // Show regular transcription with playback highlighting
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
                            .fill(themeManager.theme.surface)
                    )
                } else {
                    Text(text)
                        .font(.body)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(themeManager.theme.surface)
                        )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeManager.theme.cellBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(themeManager.theme.cellBorder, lineWidth: 1)
                )
                .shadow(color: themeManager.theme.shadowColor, radius: 3, x: 0, y: 2)
        )
    }
    
    /// Tags section
    private func tagSection(tags: NSSet) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Label("Tags", systemImage: "tag")
                    .font(.headline)
                
                Spacer()
                
                // Show encrypted tag indicator if applicable
                if journalEntry.hasEncryptedContent, let encryptedTag = journalEntry.encryptedTag {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                        
                        Text(encryptedTag.name ?? "")
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(encryptedTag.swiftUIColor.opacity(0.2))
                    )
                    .foregroundColor(encryptedTag.swiftUIColor)
                }
            }
            
            // Tags cloud
            FlowLayout(spacing: 8) {
                ForEach(Array(tags) as? [Tag] ?? [], id: \.self) { tag in
                    EnhancedEncryptedTagView(tag: tag)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeManager.theme.cellBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(themeManager.theme.cellBorder, lineWidth: 1)
                )
                .shadow(color: themeManager.theme.shadowColor, radius: 3, x: 0, y: 2)
        )
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
                .fill(themeManager.theme.cellBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(themeManager.theme.cellBorder, lineWidth: 1)
                )
                .shadow(color: themeManager.theme.shadowColor, radius: 3, x: 0, y: 2)
        )
    }
    
    // MARK: - Helper Views
    
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
        print("🎵 [EnhancedJournalEntryView] loadAudio called")
        guard let recording = journalEntry.audioRecording else {
            print("⚠️ [EnhancedJournalEntryView] No audio recording found")
            return
        }
        
        print("  - Audio exists: \(recording.filePath ?? "nil")")
        print("  - Is encrypted: \(recording.isEncrypted)")
        print("  - Entry has encrypted content: \(journalEntry.hasEncryptedContent)")
        print("  - Entry is decrypted: \(journalEntry.isDecrypted)")
        print("  - Entry is base encrypted: \(journalEntry.isBaseEncrypted)")
        print("  - Entry is base decrypted: \(journalEntry.isBaseDecrypted)")
        
        // Ensure entry is decrypted before loading audio
        if journalEntry.hasEncryptedContent && !journalEntry.isDecrypted {
            print("🔐 [EnhancedJournalEntryView] Attempting to decrypt entry for audio playback")
            if !journalEntry.decryptWithGlobalAccess() {
                print("❌ [EnhancedJournalEntryView] Failed to decrypt entry for audio playback")
                return
            }
            print("✅ [EnhancedJournalEntryView] Entry decrypted successfully")
        }
        
        // Check if base encryption needs decryption
        if journalEntry.isBaseEncrypted && !journalEntry.isBaseDecrypted {
            print("🔐 [EnhancedJournalEntryView] Attempting to decrypt base content for audio playback")
            if !journalEntry.decryptBaseContent() {
                print("❌ [EnhancedJournalEntryView] Failed to decrypt base content for audio playback")
                return
            }
            print("✅ [EnhancedJournalEntryView] Base content decrypted successfully")
        }
        
        print("🎵 [EnhancedJournalEntryView] Loading audio after decryption checks")
        
        // Use the AudioPlaybackViewModel's method which properly handles path conversion
        Task {
            await playbackViewModel.loadAudio(from: recording)
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
            // Error occurred
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
    
    /// Handle share action by ensuring entry is decrypted first
    private func shareEntry() {
        // If the entry has encrypted content and isn't decrypted, handle it
        if journalEntry.hasEncryptedContent && !journalEntry.isDecrypted {
            // Try global access first
            if journalEntry.hasGlobalAccess {
                _ = journalEntry.decryptWithGlobalAccess()
            }
            // If still not decrypted, we can't share the audio
        }
        
        // If the entry has base encryption and isn't decrypted, handle it
        if journalEntry.isBaseEncrypted && !journalEntry.isBaseDecrypted {
            _ = journalEntry.decryptBaseContent()
        }
        
        // Show the share sheet
        showingShareSheet = true
    }
    
    /// Prepare audio file for sharing by ensuring we have an unencrypted version
    private func prepareAudioForSharing() -> URL? {
        guard let audioRecording = journalEntry.audioRecording else { 
            return nil 
        }
        
        let fileManager = FileManager.default
        
        // Check all possible paths
        if let effectivePath = audioRecording.effectiveFilePath {
            // Convert relative path to absolute path
            let absoluteURL = FilePathUtility.toAbsolutePath(from: effectivePath)
            let exists = fileManager.fileExists(atPath: absoluteURL.path)
            
            if exists {
                // Skip if this is an encrypted file
                if absoluteURL.pathExtension == "encrypted" || absoluteURL.pathExtension == "baseenc" {
                    // Try to use the original file if available
                    if let originalPath = audioRecording.originalFilePath {
                        let originalURL = FilePathUtility.toAbsolutePath(from: originalPath)
                        let originalExists = fileManager.fileExists(atPath: originalURL.path)
                        
                        if originalExists {
                            return originalURL
                        }
                    }
                    
                    return nil
                }
                
                return absoluteURL
            }
        }
        
        // Fallback to original file path if available
        if let originalPath = audioRecording.originalFilePath {
            let originalURL = FilePathUtility.toAbsolutePath(from: originalPath)
            let originalExists = fileManager.fileExists(atPath: originalURL.path)
            
            if originalExists {
                return originalURL
            }
        }
        
        // Last resort - try the main filePath
        if let filePath = audioRecording.filePath {
            let fileURL = FilePathUtility.toAbsolutePath(from: filePath)
            let fileExists = fileManager.fileExists(atPath: fileURL.path)
            
            if fileExists {
                return fileURL
            }
        }
        
        return nil
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
    _ = entry.createTranscription(text: "This is a sample transcription of a voice journal entry. It contains the text that would be generated from the audio recording using speech recognition. The transcription can be quite long and may contain multiple paragraphs of text. This allows users to read through their journal entries even when they can't listen to the audio.")
    
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
