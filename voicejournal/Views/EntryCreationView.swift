//
//  EntryCreationView.swift
//  voicejournal
//
//  Created on 4/28/25.
//

import SwiftUI
import CoreData

/// A view for creating new journal entries with enhanced metadata options
struct EntryCreationView: View {
    // MARK: - Environment
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Static Properties
    
    /// Dictionary to temporarily store PIN values for encrypted tags before entry creation
    /// Uses tag name as key since object IDs can change after saving context
    static var encryptedTagPINs: [String: String] = [:]
    
    // MARK: - Bindings
    
    @Binding var isPresented: Bool
    
    // MARK: - State
    
    @State private var entryTitle = ""
    @State private var selectedTags = Set<Tag>()
    @State private var showingTagSelection = false
    @State private var showingRecordingView = false
    @State private var journalEntry: JournalEntry?
    @State private var isEditingTranscription = false
    @State private var transcriptionText = ""
    @State private var showingDiscardAlert = false
    @State private var encryptedTag: Tag? = nil
    @State private var selectedLanguage = LanguageSettings.shared.defaultRecordingLanguage
    @StateObject private var languageSettings = LanguageSettings.shared
    
    // AI Enhancement tracking
    @State private var showAIEnhancementStatus = false
    @State private var enhancementStatuses: [AIEnhancementStatus] = []
    @State private var isEnhancing = false
    @State private var enhancementResult: AIEnhancementResult?
    @StateObject private var transcriptionSettings = TranscriptionSettings.shared
    @StateObject private var enhancementManager = AIEnhancementManager.shared
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            Form {
                // Title section
                Section(header: Text("Title")) {
                    TextField("Entry Title", text: $entryTitle)
                }
                
                // Tags section
                Section(header: tagsHeaderView) {
                    tagsContentView
                }
                
                // Language selection section
                Section(header: Text("Recording Language")) {
                    CompactLanguageSelectionView(selectedLanguage: $selectedLanguage)
                }
                
                // Recording section
                Section {
                    if journalEntry == nil {
                        Button(action: {
                            createEntryAndStartRecording()
                        }) {
                            HStack {
                                Image(systemName: "mic.fill")
                                    .font(.title2)
                                    .foregroundColor(.red)
                                Text("Start Recording")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    } else if let entry = journalEntry, let recording = entry.audioRecording {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "waveform")
                                    .foregroundColor(.blue)
                                Text("Recording Complete")
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
                            
                            Button(action: {
                                // Navigate to playback
                            }) {
                                Label("Play Recording", systemImage: "play.circle")
                            }
                            .buttonStyle(BorderedButtonStyle())
                            .padding(.top, 4)
                            
                            // AI Enhancement Status
                            if showAIEnhancementStatus && !enhancementStatuses.isEmpty {
                                aiEnhancementStatusSection
                            }
                        }
                    }
                } header: {
                    Text("Recording")
                } footer: {
                    Text("Record your voice journal entry. You can edit the transcription after recording.")
                }
                
                // Transcription section (only shown after recording)
                if let entry = journalEntry, let transcription = entry.transcription, let text = transcription.text {
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
            }
            .navigationTitle("New Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if journalEntry != nil {
                            showingDiscardAlert = true
                        } else {
                            isPresented = false
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveEntry()
                    }
                    .disabled(journalEntry == nil)
                }
            }
            .sheet(isPresented: $showingTagSelection) {
                TagSelectionView(journalEntry: journalEntry, selectedTags: $selectedTags)
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(isPresented: $showingRecordingView) {
                if let entry = journalEntry {
                    RecordingView(
                        context: viewContext,
                        existingEntry: entry,
                        language: selectedLanguage,
                        onComplete: {
                            showingRecordingView = false
                        }
                    )
                    .onAppear {
                        // Reset enhancement status when recording view appears
                        enhancementStatuses = []
                        showAIEnhancementStatus = false
                    }
                    .onDisappear {
                        // Check for enhancement statuses when recording view is dismissed
                        if let entry = journalEntry {
                            let entryID = entry.objectID.uriRepresentation().absoluteString
                            if let statuses = enhancementManager.enhancementStatuses[entryID] {
                                enhancementStatuses = statuses
                                showAIEnhancementStatus = true
                                isEnhancing = enhancementManager.activeEnhancements.contains(entryID)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $isEditingTranscription) {
                if let entry = journalEntry {
                    TranscriptionEditView(
                        journalEntry: entry,
                        transcriptionText: $transcriptionText,
                        onSave: saveTranscription
                    )
                }
            }
            .alert("Discard Entry?", isPresented: $showingDiscardAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Discard", role: .destructive) {
                    discardEntry()
                }
            } message: {
                Text("Are you sure you want to discard this entry? This action cannot be undone.")
            }
        }
        .onReceive(enhancementManager.$enhancementStatuses) { newValue in
            if let entry = journalEntry {
                let entryID = entry.objectID.uriRepresentation().absoluteString
                if let statuses = newValue[entryID] {
                    enhancementStatuses = statuses
                    showAIEnhancementStatus = true
                    isEnhancing = enhancementManager.activeEnhancements.contains(entryID)
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var tagsHeaderView: some View {
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
    }
    
    @ViewBuilder
    private var tagsContentView: some View {
        if selectedTags.isEmpty {
            Text("No tags selected")
                .foregroundColor(.secondary)
                .italic()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(selectedTags), id: \.self) { tag in
                        selectedTagView(tag)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    @ViewBuilder
    private func selectedTagView(_ tag: Tag) -> some View {
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
    
    private var aiEnhancementStatusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                Text("AI Enhancement")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.top, 8)
            
            ForEach(enhancementStatuses) { status in
                enhancementStatusRow(status)
            }
            
            // Summary message
            if !isEnhancing, let result = enhancementResult {
                Text("Enhancement completed in \(String(format: "%.1f", result.totalDuration))s")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding(.top, 8)
    }
    
    private func enhancementStatusRow(_ status: AIEnhancementStatus) -> some View {
        HStack {
            // Icon showing feature status
            statusIcon(for: status.status)
            
            // Feature name
            Text(status.feature.displayName)
                .font(.caption)
                .foregroundColor(.primary)
            
            Spacer()
            
            // Status text
            Text(status.status.displayName)
                .font(.caption2)
                .foregroundColor(status.status.color)
        }
    }
    
    @ViewBuilder
    private func statusIcon(for status: AIEnhancementStatus.Status) -> some View {
        switch status {
        case .pending:
            Image(systemName: "circle")
                .foregroundColor(.gray)
                .frame(width: 14, height: 14)
        case .inProgress:
            ProgressView()
                .scaleEffect(0.6)
                .frame(width: 14, height: 14)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .frame(width: 14, height: 14)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
                .frame(width: 14, height: 14)
        }
    }
    
    // MARK: - Methods
    
    /// Create a new journal entry and start recording
    private func createEntryAndStartRecording() {
        // Create a new journal entry
        let entry = JournalEntry.create(in: viewContext)
        entry.title = entryTitle.isEmpty ? "Untitled Entry" : entryTitle
        
        // Process selected tags
        
        // Find and process encrypted tags first
        for tag in selectedTags {
            if tag.isEncrypted, let tagName = tag.name {
                
                if EntryCreationView.encryptedTagPINs[tagName] != nil {
                    // Store this encrypted tag for later application (after recording is saved)
                    encryptedTag = tag
                    
                    // We'll apply the encrypted tag after recording to ensure content exists
                    // So we don't add it to tags here
                    continue
                } else {
                }
            }
            
            // Add regular tag
            entry.addToTags(tag)
        }
        
        // Save the context
        do {
            try viewContext.save()
            journalEntry = entry
            
            // Show recording view
            showingRecordingView = true
        } catch {
            // Error creating journal entry
        }
    }
    
    /// Save the journal entry
    private func saveEntry() {
        guard let entry = journalEntry else { return }
        
        // Update title if needed
        if entry.title != entryTitle && !entryTitle.isEmpty {
            entry.title = entryTitle
        }
        
        // Apply encrypted tag if one was selected
        if let tag = encryptedTag, let tagName = tag.name {
            print("🏷️ [EntryCreationView] Applying encrypted tag: \(tagName)")
            
            if let pin = EntryCreationView.encryptedTagPINs[tagName] {
                print("🏷️ [EntryCreationView] PIN found for tag, applying encryption")
                
                // Check transcription state before encryption
                if let transcription = entry.transcription {
                    print("📊 [EntryCreationView] Pre-encryption transcription state:")
                    print("  - Raw text: \(transcription.rawText?.count ?? 0) characters")
                    print("  - Enhanced text: \(transcription.enhancedText?.count ?? 0) characters")
                    print("  - AI analysis: \(transcription.aiAnalysis?.count ?? 0) characters")
                }
                
                // First grant temporary access to the tag so the key is available for background operations
                if EncryptedTagsAccessManager.shared.grantAccess(to: tag, with: pin) {
                    print("🔑 [EntryCreationView] Granted temporary access to encrypted tag")
                }
                
                // Apply tag with PIN to encrypt content
                if entry.applyEncryptedTagWithPin(tag, pin: pin) {
                    print("✅ [EntryCreationView] Encrypted tag applied successfully")
                    
                    // Check post-encryption state
                    if let transcription = entry.transcription {
                        print("📊 [EntryCreationView] Post-encryption transcription state:")
                        print("  - Raw text: \(transcription.rawText?.count ?? 0) characters")
                        print("  - Enhanced text: \(transcription.enhancedText?.count ?? 0) characters")
                        print("  - Encrypted enhanced: \(transcription.encryptedEnhancedText?.count ?? 0) bytes")
                    }
                } else {
                    print("❌ [EntryCreationView] Failed to apply encrypted tag")
                }
                
                // Remove from local storage after use
                EntryCreationView.encryptedTagPINs.removeValue(forKey: tagName)
            } else {
            }
        }
        
        // Update regular tags
        if let currentTags = entry.tags as? Set<Tag> {
            // Remove tags that are no longer selected
            for tag in currentTags {
                if !selectedTags.contains(tag) && !tag.isEncrypted {
                    entry.removeFromTags(tag)
                }
            }
            
            // Add new tags
            for tag in selectedTags {
                if !currentTags.contains(tag) && !tag.isEncrypted {
                    entry.addToTags(tag)
                }
            }
        } else {
            // Add all selected tags that aren't encrypted
            for tag in selectedTags {
                if !tag.isEncrypted {
                    entry.addToTags(tag)
                }
            }
        }
        
        // Update modified date
        entry.modifiedAt = Date()
        
        // Save the context
        do {
            try viewContext.save()
            isPresented = false
        } catch {
            // Error saving journal entry
        }
    }
    
    /// Save edited transcription
    private func saveTranscription() {
        guard let entry = journalEntry, let transcription = entry.transcription else { return }
        
        transcription.text = transcriptionText
        transcription.modifiedAt = Date()
        entry.modifiedAt = Date()
        
        do {
            try viewContext.save()
        } catch {
            // Error saving transcription
        }
    }
    
    /// Discard the entry
    private func discardEntry() {
        if let entry = journalEntry {
            viewContext.delete(entry)
            
            do {
                try viewContext.save()
            } catch {
                // Error deleting entry
            }
        }
        
        isPresented = false
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

// MARK: - Tag Selection View

/// A view for selecting tags for a journal entry
struct TagSelectionView: View {
    // MARK: - Environment
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    /// The journal entry if editing an existing entry
    var journalEntry: JournalEntry?
    
    // MARK: - Bindings
    
    @Binding var selectedTags: Set<Tag>
    
    // MARK: - State
    
    @State private var newTagName = ""
    @State private var newTagColor = "#007AFF" // Default blue color
    @State private var showingColorPicker = false
    @State private var selectedColorIndex = 0
    @State private var showingPINEntryDialog = false
    @State private var selectedEncryptedTag: Tag? = nil
    @State private var showCreateEncryptedTagSheet = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    // MARK: - Fetch Requests
    
    @FetchRequest(
        entity: Tag.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Tag.name, ascending: true)],
        predicate: NSPredicate(format: "isEncrypted == NO")
    ) private var regularTags: FetchedResults<Tag>
    
    @FetchRequest(
        entity: Tag.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Tag.name, ascending: true)],
        predicate: NSPredicate(format: "isEncrypted == YES")
    ) private var encryptedTags: FetchedResults<Tag>
    
    // MARK: - Constants
    
    private let tagColors = [
        "#007AFF", // Blue
        "#FF3B30", // Red
        "#4CD964", // Green
        "#FF9500", // Orange
        "#5856D6", // Purple
        "#FF2D55", // Pink
        "#FFCC00", // Yellow
        "#8E8E93"  // Gray
    ]
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            tagSelectionListView
                .listStyle(InsetGroupedListStyle())
                .navigationTitle("Tags")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
                .sheet(isPresented: $showCreateEncryptedTagSheet) {
                    CreateEncryptedTagView()
                        .environment(\.managedObjectContext, viewContext)
                }
                .pinEntryDialog(
                    isPresented: $showingPINEntryDialog,
                    title: "Enter PIN",
                    message: "Enter PIN for \"\(selectedEncryptedTag?.name ?? "")\" to apply this encrypted tag",
                    onSubmit: { pin in
                        verifyPINAndApplyTag(pin)
                    }
                )
                .alert(alertTitle, isPresented: $showAlert) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(alertMessage)
                }
        }
    }
    
    // MARK: - Subviews
    
    /// The main list view containing all sections
    private var tagSelectionListView: some View {
        List {
            createNewTagSection
            regularTagsSection
            encryptedTagsSection
        }
    }
    
    /// Section for creating a new tag
    private var createNewTagSection: some View {
        Section(header: Text("Create New Tag")) {
            HStack {
                TextField("Tag Name", text: $newTagName)
                
                Button(action: {
                    showingColorPicker = true
                }) {
                    Circle()
                        .fill(Color(hex: newTagColor))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(BorderlessButtonStyle())
                
                Button(action: {
                    createNewTag()
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(newTagName.isEmpty)
            }
            
            if showingColorPicker {
                colorPickerView
            }
        }
    }
    
    /// Color picker view for selecting tag colors
    private var colorPickerView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<tagColors.count, id: \.self) { index in
                    let color = tagColors[index]
                    Circle()
                        .fill(Color(hex: color))
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle()
                                .stroke(Color.primary, lineWidth: selectedColorIndex == index ? 2 : 0)
                        )
                        .onTapGesture {
                            selectedColorIndex = index
                            newTagColor = color
                        }
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    /// Section for regular (non-encrypted) tags
    private var regularTagsSection: some View {
        Section(header: Text("Regular Tags")) {
            if regularTags.isEmpty {
                Text("No regular tags available")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(regularTags, id: \.self) { tag in
                    regularTagRow(tag)
                }
            }
        }
    }
    
    /// Row view for a regular tag
    @ViewBuilder
    private func regularTagRow(_ tag: Tag) -> some View {
        if let name = tag.name, let color = tag.color {
            Button(action: {
                toggleTag(tag)
            }) {
                HStack {
                    Circle()
                        .fill(Color(hex: color))
                        .frame(width: 12, height: 12)
                    
                    Text(name)
                    
                    Spacer()
                    
                    if selectedTags.contains(tag) {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
            }
        } else {
            Button(action: {}) {
                Text("Invalid Tag")
                    .foregroundColor(.secondary)
            }
            .disabled(true)
        }
    }
    
    /// Section for encrypted tags
    private var encryptedTagsSection: some View {
        Section(
            header: encryptedTagsHeader,
            footer: Text("Encrypted tags require a PIN to access content.")
        ) {
            if encryptedTags.isEmpty {
                Text("No encrypted tags available")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(encryptedTags, id: \.self) { tag in
                    encryptedTagRow(tag)
                }
            }
        }
    }
    
    /// Header view for encrypted tags section
    private var encryptedTagsHeader: some View {
        HStack {
            Text("Encrypted Tags")
            Spacer()
            Button(action: {
                showCreateEncryptedTagSheet = true
            }) {
                Text("Create New")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
    }
    
    /// Row view for an encrypted tag
    @ViewBuilder
    private func encryptedTagRow(_ tag: Tag) -> some View {
        if let name = tag.name, let color = tag.color {
            Button(action: {
                selectedEncryptedTag = tag
                showingPINEntryDialog = true
            }) {
                HStack {
                    // Tag color with lock icon overlay
                    ZStack {
                        Circle()
                            .fill(Color(hex: color))
                            .frame(width: 16, height: 16)
                        
                        // Lock icon overlay
                        Image(systemName: "lock.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.white)
                    }
                    
                    Text(name)
                    
                    Spacer()
                    
                    // If this is the currently set encrypted tag
                    if let entry = journalEntry, entry.encryptedTag == tag {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                    // If it's in the selected tags but not the encrypted tag
                    else if selectedTags.contains(tag) {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
            }
        } else {
            Button(action: {}) {
                Text("Invalid Tag")
                    .foregroundColor(.secondary)
            }
            .disabled(true)
        }
    }
    
    // MARK: - Methods
    
    /// Create a new regular tag
    private func createNewTag() {
        guard !newTagName.isEmpty else { return }
        
        // Check if tag already exists
        let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", newTagName)
        
        do {
            let existingTags = try viewContext.fetch(fetchRequest)
            
            if let existingTag = existingTags.first {
                // Tag already exists, just select it
                selectedTags.insert(existingTag)
            } else {
                // Create new tag
                let newTag = Tag(context: viewContext)
                newTag.name = newTagName
                newTag.color = newTagColor
                newTag.createdAt = Date()
                newTag.isEncrypted = false // Ensure it's not encrypted
                
                try viewContext.save()
                
                // Select the new tag
                selectedTags.insert(newTag)
            }
            
            // Reset input fields
            newTagName = ""
            showingColorPicker = false
        } catch {
            // Error creating tag
        }
    }
    
    /// Toggle selection of a regular tag
    private func toggleTag(_ tag: Tag) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }
    
    /// Verify PIN and apply encrypted tag
    private func verifyPINAndApplyTag(_ pin: String) {
        guard let tag = selectedEncryptedTag else {
            return
        }
        
        // Only attempt to apply encrypted tag if we have a journal entry
        if let entry = journalEntry {
            // First verify the PIN
            if tag.verifyPin(pin) {
                // Apply tag with PIN and encrypt content
                if entry.applyEncryptedTagWithPin(tag, pin: pin) {
                    // Add to selected tags
                    selectedTags.insert(tag)
                    
                    // Show success alert after dialog dismisses
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.showAlert(title: "Encrypted Tag Applied", message: "The content has been encrypted with the tag \"\(tag.name ?? "")\".")
                    }
                } else {
                    // Show error but don't reshow PIN dialog since PIN was correct
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.showAlert(title: "Error", message: "Failed to apply encrypted tag. Please try again.")
                    }
                }
            } else {
                // PIN verification failed
                // We need to show the alert after the dialog dismisses itself
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.showAlert(title: "Incorrect PIN", message: "The PIN you entered is incorrect for this tag.")
                    
                    // Show the PIN entry dialog again after showing the alert
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.showingPINEntryDialog = true
                    }
                }
            }
        } else {
            // If no entry exists yet, just add to selected tags and note that PIN verification succeeded
            if tag.verifyPin(pin) {
                // Add to selected tags, will be applied when entry is created
                selectedTags.insert(tag)
                
                // Save the pin in temporary storage for later application
                if let tagName = tag.name {
                    EntryCreationView.encryptedTagPINs[tagName] = pin
                } else {
                }
                
                // Show feedback that the PIN was correct and tag was selected after dialog dismisses
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.showAlert(title: "Encrypted Tag Selected", message: "The tag \"\(tag.name ?? "")\" will be applied and content will be encrypted after recording.")
                }
            } else {
                // PIN verification failed
                // We need to show the alert after the dialog dismisses itself
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.showAlert(title: "Incorrect PIN", message: "The PIN you entered is incorrect for this tag.")
                    
                    // Show the PIN entry dialog again after showing the alert
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.showingPINEntryDialog = true
                    }
                }
            }
        }
    }
    
    /// Show an alert with the given title and message
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}

// MARK: - Entry Recording View

/// A view for recording audio for a journal entry
// EntryRecordingView has been replaced by RecordingView
// See RecordingView.swift for implementation

// MARK: - Preview

#Preview {
    EntryCreationView(isPresented: .constant(true))
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
