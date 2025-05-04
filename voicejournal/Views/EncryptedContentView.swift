//
//  EncryptedContentView.swift
//  voicejournal
//
//  Created on 5/4/25.
//

import SwiftUI
import CoreData

/// A view for handling encrypted content in journal entries
struct EncryptedContentView: View {
    // MARK: - Environment
    
    @Environment(\.managedObjectContext) private var viewContext
    
    // MARK: - Properties
    
    let journalEntry: JournalEntry
    
    // MARK: - State
    
    @State private var showingPINEntryDialog = false
    @State private var isContentDecrypted = false
    @State private var isBaseContentDecrypted = false
    @State private var showEncryptedTagSheet = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var isAuthenticating = false
    
    // MARK: - Body
    
    var body: some View {
        VStack {
            // Always show content view - no lock screens
            contentView
        }
        .pinEntryDialog(
            isPresented: $showingPINEntryDialog,
            title: "Enter PIN",
            message: "Enter the PIN for \"\(journalEntry.encryptedTag?.name ?? "encrypted tag")\" to access the content",
            onSubmit: { pin in
                decryptContent(with: pin)
            }
        )
        .sheet(isPresented: $showEncryptedTagSheet) {
            EncryptedTagSelectionView(journalEntry: journalEntry) { success in
                if success {
                    showAlert(title: "Content Encrypted", message: "Your content has been encrypted with the selected tag. You will need the PIN to access it in the future.")
                }
            }
            .environment(\.managedObjectContext, viewContext)
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Computed Properties
    
    /// Returns true if we can show the content (either it's not encrypted or it's been decrypted)
    private var canShowContent: Bool {
        // Can show if base decrypted (or not base encrypted)
        // For tag encryption, we always show content regardless of encryption state
        let baseOk = !journalEntry.isBaseEncrypted || isBaseContentDecrypted
        
        // Always show content for entries with encrypted tags - the transcription will 
        // be automatically decrypted if it has global access
        return baseOk
    }
    
    /// Returns true if we need to decrypt with base encryption
    private var needsBaseDecryption: Bool {
        return journalEntry.isBaseEncrypted && !isBaseContentDecrypted
    }
    
    /// Returns true if we need to decrypt with tag encryption
    private var needsTagDecryption: Bool {
        // Never show tag decryption UI - we auto-attempt decryption on appear
        return false
    }
    
    /// Returns true if the journal entry has an encrypted tag with global access
    private var hasGlobalAccess: Bool {
        return journalEntry.encryptedTag?.hasGlobalAccess ?? false
    }
    
    /// View for base decryption using biometric authentication
    private var baseDecryptionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("Journal Entry Encrypted")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("This journal entry is encrypted with the app's master key")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                authenticateAndDecryptBase()
            } label: {
                Label("Unlock with Face ID/Touch ID", systemImage: "faceid")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.blue)
                    )
                    .foregroundColor(.white)
            }
            .disabled(isAuthenticating)
            .padding(.top, 8)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
        )
    }
    
    /// View for tag decryption using PIN (simplified to auto-attempt decryption)
    private var tagDecryptionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            if let encryptedTag = journalEntry.encryptedTag {
                Text("Content encrypted with tag")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                EnhancedEncryptedTagView(tag: encryptedTag)
                    .padding(.vertical, 8)
                
                Button {
                    // Always try to show the PIN dialog directly
                    showingPINEntryDialog = true
                } label: {
                    Label("Enter PIN", systemImage: "key")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.accentColor)
                        )
                        .foregroundColor(.white)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
        )
        .onAppear {
            // Attempt to decrypt immediately if we have global access
            if hasGlobalAccess {
                if journalEntry.decryptWithGlobalAccess() {
                    withAnimation {
                        isContentDecrypted = true
                    }
                }
            }
        }
    }
    
    /// View for showing content (whether encrypted or not)
    private var contentView: some View {
        VStack(spacing: 16) {
            // Header with encryption status and controls
            HStack {
                if journalEntry.hasEncryptedContent {
                    // Show tag info for encrypted content with clear indicator of global access
                    HStack(spacing: 4) {
                        if let tag = journalEntry.encryptedTag {
                            // Improved tag display
                            HStack(spacing: 6) {
                                EnhancedEncryptedTagView(tag: tag)
                                    .frame(height: 20)
                                
                                if tag.hasGlobalAccess {
                                    // Clear indication that global access is enabled
                                    HStack(spacing: 2) {
                                        Image(systemName: "checkmark.shield.fill")
                                            .font(.caption2)
                                            .foregroundColor(.green)
                                        
                                        Text("Access Granted")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(Color.green.opacity(0.1))
                                    )
                                }
                            }
                        }
                    }
                    
                    Spacer()
                                        
                } else if journalEntry.isBaseEncrypted {
                    // Base encryption indicator
                    HStack(spacing: 4) {
                        Image(systemName: "lock.shield.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Text("Base Encrypted")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Button to add additional tag protection
                    Button {
                        showEncryptedTagSheet = true
                    } label: {
                        Label("Add Tag Protection", systemImage: "lock")
                            .font(.footnote)
                    }
                    .buttonStyle(.bordered)
                } else {
                    // No encryption indicator
                    Text("Not Encrypted")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                
                    // Button to encrypt with tag
                    Button {
                        showEncryptedTagSheet = true
                    } label: {
                        Label("Encrypt with Tag", systemImage: "lock")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue)
                            )
                            .foregroundColor(.white)
                    }
                }
            }
            
            // Content display for all encryption types
            if let transcription = journalEntry.transcription {
                if let text = transcription.text {
                    // Normal text display when content is available
                    Text(text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                } else if journalEntry.isBaseEncrypted && !isBaseContentDecrypted {
                    // Base encrypted content
                    HStack {
                        Text("Content is encrypted")
                            .foregroundColor(.secondary)
                        Spacer()
                        Button {
                            authenticateAndDecryptBase()
                        } label: {
                            Label("Unlock", systemImage: "faceid")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                } else if journalEntry.hasEncryptedContent && !isContentDecrypted && !hasGlobalAccess {
                    // Tag encrypted content
                    HStack {
                        Text("Protected content")
                            .foregroundColor(.secondary)
                        Spacer()
                        Button {
                            showingPINEntryDialog = true
                        } label: {
                            Label("Unlock", systemImage: "key")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                } else {
                    Text("No transcription available")
                        .italic()
                        .foregroundColor(.secondary)
                }
            } else {
                Text("No transcription available")
                    .italic()
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
        )
        .onAppear {
            // Try to auto-decrypt base encryption if present
            if journalEntry.isBaseEncrypted && !isBaseContentDecrypted {
                if journalEntry.decryptBaseContent() {
                    withAnimation {
                        isBaseContentDecrypted = true
                    }
                }
            }
            
            // Try to auto-decrypt tag encryption if present and has global access
            if journalEntry.hasEncryptedContent && !isContentDecrypted && hasGlobalAccess {
                if journalEntry.decryptWithGlobalAccess() {
                    withAnimation {
                        isContentDecrypted = true
                    }
                }
            }
        }
    }
    
    // MARK: - Methods
    
    /// Authenticate with biometrics and decrypt base content
    private func authenticateAndDecryptBase() {
        isAuthenticating = true
        
        EncryptionManager.getRootEncryptionKeyWithBiometrics { key in
            isAuthenticating = false
            
            if key != nil {
                // Success - authentication passed
                if self.journalEntry.decryptBaseContent() {
                    withAnimation {
                        self.isBaseContentDecrypted = true
                    }
                } else {
                    self.showAlert(title: "Decryption Failed", message: "Failed to decrypt the content with the root key.")
                }
            } else {
                // Authentication failed
                self.showAlert(title: "Authentication Failed", message: "Biometric authentication failed or was cancelled.")
            }
        }
    }
    
    /// Decrypt the content with the provided PIN
    private func decryptContent(with pin: String) {
        if journalEntry.decryptContent(withPin: pin) {
            withAnimation {
                isContentDecrypted = true
            }
            // Success - dialog will close automatically
        } else {
            // PIN verification failed
            // We need to show the alert after the dialog dismisses itself
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showAlert(title: "Incorrect PIN", message: "The PIN you entered is incorrect.")
                
                // Show the PIN entry dialog again after showing the alert
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showingPINEntryDialog = true
                }
            }
        }
    }
    
    /// Re-encrypt the content
    private func reEncryptContent() {
        // Simply set the state to show the locked view
        withAnimation {
            isContentDecrypted = false
        }
    }
    
    /// Re-encrypt base content
    private func reEncryptBaseContent() {
        // Simply set the state to show the locked view
        withAnimation {
            isBaseContentDecrypted = false
        }
        journalEntry.markAsBaseEncrypted()
    }
    
    /// Show an alert with the given title and message
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}

/// A view for selecting an encrypted tag to apply to a journal entry
struct EncryptedTagSelectionView: View {
    // MARK: - Environment
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let journalEntry: JournalEntry
    let onComplete: (Bool) -> Void
    
    // MARK: - State
    
    @State private var selectedTag: Tag? = nil
    @State private var showingPINEntryDialog = false
    @State private var showCreateTagSheet = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    // MARK: - Fetch Requests
    
    @FetchRequest(
        entity: Tag.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Tag.name, ascending: true)],
        predicate: NSPredicate(format: "isEncrypted == YES")
    ) private var encryptedTags: FetchedResults<Tag>
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            VStack {
                if encryptedTags.isEmpty {
                    // No encrypted tags available
                    VStack(spacing: 16) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No encrypted tags available")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("You need to create an encrypted tag before you can encrypt this content")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button {
                            showCreateTagSheet = true
                        } label: {
                            Label("Create Encrypted Tag", systemImage: "plus")
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.accentColor.opacity(0.1))
                                )
                        }
                        .padding(.top)
                    }
                    .padding()
                } else {
                    // List of encrypted tags
                    List {
                        Section {
                            ForEach(encryptedTags) { tag in
                                Button {
                                    selectedTag = tag
                                    showingPINEntryDialog = true
                                } label: {
                                    HStack {
                                        // Tag color and icon
                                        ZStack {
                                            Circle()
                                                .fill(tag.swiftUIColor)
                                                .frame(width: 32, height: 32)
                                            
                                            // Lock icon overlay
                                            Image(systemName: "lock.fill")
                                                .font(.system(size: 10))
                                                .foregroundColor(.white)
                                        }
                                        
                                        Text(tag.name ?? "Unnamed Tag")
                                        
                                        Spacer()
                                        
                                        if selectedTag == tag {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        } header: {
                            Text("Select an encrypted tag")
                        } footer: {
                            Text("You'll need to enter the PIN for the selected tag to encrypt this content.")
                        }
                        
                        Section {
                            Button {
                                showCreateTagSheet = true
                            } label: {
                                Label("Create New Encrypted Tag", systemImage: "plus")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Encrypt Content")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                        onComplete(false)
                    }
                }
            }
            .pinEntryDialog(
                isPresented: $showingPINEntryDialog,
                title: "Enter PIN",
                message: "Enter the PIN for \"\(selectedTag?.name ?? "")\" to encrypt this content",
                onSubmit: { pin in
                    encryptContent(with: pin)
                }
            )
            .sheet(isPresented: $showCreateTagSheet) {
                CreateEncryptedTagView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // MARK: - Methods
    
    /// Encrypt the content with the selected tag using the provided PIN
    private func encryptContent(with pin: String) {
        guard let tag = selectedTag else {
            return
        }
        
        // Verify the PIN
        if !tag.verifyPin(pin) {
            // PIN verification failed
            // We need to show the alert after the dialog dismisses itself
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.showAlert(title: "Incorrect PIN", message: "The PIN you entered does not match the PIN for this tag.")
                
                // Show the PIN entry dialog again after showing the alert
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.showingPINEntryDialog = true
                }
            }
            return
        }
        
        // Apply the encrypted tag to the entry and immediately encrypt the content in one operation
        if journalEntry.applyEncryptedTagWithPin(tag, pin: pin) {
            // Success! Close the sheet and notify parent
            dismiss()
            onComplete(true)
        } else {
            // Show error but don't reshow PIN dialog since PIN was correct
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.showAlert(title: "Encryption Failed", message: "An error occurred while applying the encrypted tag or encrypting the content.")
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

// MARK: - Preview

#Preview("Encrypted Content With Tag", traits: .sizeThatFitsLayout) {
    // Create a journal entry with tag-encrypted content
    let context = PersistenceController.preview.container.viewContext
    let entry = JournalEntry.create(in: context)
    entry.title = "My Encrypted Journal Entry"
    
    // Create a transcription and dummy encrypted tag
    let transcription = entry.createTranscription(text: "This is some secret content that I want to keep encrypted.")
    transcription.text = nil
    transcription.encryptedText = Data("This is some secret content that I want to keep encrypted.".utf8)
    
    let encryptedTag = Tag(context: context)
    encryptedTag.name = "Private"
    encryptedTag.color = "#FF5733"
    encryptedTag.isEncrypted = true
    entry.encryptedTag = encryptedTag
    
    return EncryptedContentView(journalEntry: entry)
        .environment(\.managedObjectContext, context)
        .padding()
}

#Preview("Encrypted Content with Global Access", traits: .sizeThatFitsLayout) {
    // Create a journal entry with tag-encrypted content but global access
    let context = PersistenceController.preview.container.viewContext
    let entry = JournalEntry.create(in: context)
    entry.title = "Journal with Global Access"
    
    // Create a transcription with decrypted content (simulating global access)
    let transcription = entry.createTranscription(text: "This content is decrypted via global access.")
    transcription.encryptedText = Data("This content is decrypted via global access.".utf8)
    
    let encryptedTag = Tag(context: context)
    encryptedTag.name = "Work"
    encryptedTag.color = "#3357FF"
    encryptedTag.isEncrypted = true
    encryptedTag.encryptionKeyIdentifier = "test_identifier"
    entry.encryptedTag = encryptedTag
    
    // Set up preview to simulate that the content is decrypted via global access
    // This would typically happen through EncryptedTagsAccessManager.shared
    return EncryptedContentView(journalEntry: entry)
        .environment(\.managedObjectContext, context)
        .padding()
        .onAppear {
            // Simulate global access being granted for preview purposes only
            entry.markAsDecrypted()
        }
}

#Preview("Base Encrypted Content", traits: .sizeThatFitsLayout) {
    // Create a journal entry with base encryption
    let context = PersistenceController.preview.container.viewContext
    let entry = JournalEntry.create(in: context)
    entry.title = "Base Encrypted Journal"
    entry.isBaseEncrypted = true
    
    // Create a transcription that's encrypted at the base level
    let transcription = entry.createTranscription(text: "This content is protected with base encryption.")
    transcription.text = nil
    transcription.encryptedText = Data("This content is protected with base encryption.".utf8)
    
    return EncryptedContentView(journalEntry: entry)
        .environment(\.managedObjectContext, context)
        .padding()
}

#Preview("Unencrypted Content", traits: .sizeThatFitsLayout) {
    // Create a journal entry without any encryption
    let context = PersistenceController.preview.container.viewContext
    let entry = JournalEntry.create(in: context)
    entry.title = "My Journal Entry"
    entry.isBaseEncrypted = false
    
    // Create a transcription
    _ = entry.createTranscription(text: "This is content that is not encrypted.")
    
    return EncryptedContentView(journalEntry: entry)
        .environment(\.managedObjectContext, context)
        .padding()
}
