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
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var isAuthenticating = false
    
    // MARK: - Body
    
    var body: some View {
        contentView
            .pinEntryDialog(
                isPresented: $showingPINEntryDialog,
                title: "Enter PIN",
                message: "Enter the PIN for \"\(journalEntry.encryptedTag?.name ?? "encrypted tag")\" to access the content",
                onSubmit: { pin in
                    decryptContent(with: pin)
                }
            )
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
    }
    
    // MARK: - Computed Properties
    
    /// Returns true if the journal entry has an encrypted tag with global access
    private var hasGlobalAccess: Bool {
        return journalEntry.encryptedTag?.hasGlobalAccess ?? false
    }
    
    /// View for showing content
    private var contentView: some View {
        VStack(spacing: 16) {
            // Header with encryption status and controls
            HStack {
                if journalEntry.hasEncryptedContent {
                    // Show tag info for encrypted content with clear indicator of global access
                    if let tag = journalEntry.encryptedTag {
                        // Tag display
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
                }
            }
            
            // Content display
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
                    // Tag encrypted content without global access
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
        print("🔑 [EncryptedContentView] Attempting decryption with PIN")
        
        if journalEntry.decryptContent(withPin: pin) {
            print("✅ [EncryptedContentView] Decryption successful")
            
            // Check what's available after decryption
            if let transcription = journalEntry.transcription {
                print("📊 [EncryptedContentView] Post-decryption transcription state:")
                print("  - Raw text: \(transcription.rawText?.count ?? 0) characters")
                print("  - Enhanced text: \(transcription.enhancedText?.count ?? 0) characters")
                print("  - AI analysis: \(transcription.aiAnalysis?.count ?? 0) characters")
            }
            
            withAnimation {
                isContentDecrypted = true
            }
            // Success - dialog will close automatically
        } else {
            print("❌ [EncryptedContentView] Decryption failed")
            
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