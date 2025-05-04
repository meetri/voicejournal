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
    // MARK: - Properties
    
    let journalEntry: JournalEntry
    
    // MARK: - State
    
    @State private var showingPINEntryDialog = false
    @State private var isPINVerified = false
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            if journalEntry.hasEncryptedContent {
                if isPINVerified || journalEntry.isDecrypted {
                    // If PIN is verified or entry was already decrypted, show the content
                    EnhancedJournalEntryView(journalEntry: journalEntry)
                        .onDisappear {
                            // Clean up any temporary decrypted files when leaving
                            if let recording = journalEntry.audioRecording {
                                recording.tempDecryptedPath = nil
                            }
                        }
                } else {
                    // Show encrypted entry placeholder until PIN is verified
                    EncryptedEntryPlaceholderView(journalEntry: journalEntry) {
                        showingPINEntryDialog = true
                    }
                }
            } else {
                // Regular journal entry view
                EnhancedJournalEntryView(journalEntry: journalEntry)
            }
        }
        .onAppear {
            // If entry has encrypted content and is not decrypted, show PIN entry
            if journalEntry.hasEncryptedContent && !journalEntry.isDecrypted {
                showingPINEntryDialog = true
            } else {
                isPINVerified = true
            }
        }
        .pinEntryDialog(
            isPresented: $showingPINEntryDialog,
            title: "Enter PIN",
            message: "This entry is encrypted with tag \"\(journalEntry.encryptedTag?.name ?? "")\".\nPlease enter the PIN to access the content.",
            onSubmit: { pin in
                verifyPIN(pin)
            }
        )
    }
    
    // MARK: - Methods
    
    private func verifyPIN(_ pin: String) {
        // Try to decrypt the content with the provided PIN
        if journalEntry.decryptContent(withPin: pin) {
            isPINVerified = true
        } else {
            // Show error (will happen automatically with pinEntryDialog)
            showingPINEntryDialog = true
        }
    }
}

/// A placeholder view for encrypted entries before PIN is entered
struct EncryptedEntryPlaceholderView: View {
    let journalEntry: JournalEntry
    let onUnlockTapped: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Title and basic info
            VStack(spacing: 12) {
                Text(journalEntry.title ?? "Untitled Entry")
                    .font(.title)
                    .fontWeight(.bold)
                
                if let date = journalEntry.createdAt {
                    Text(date, style: .date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            
            // Lock icon
            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.secondary)
                
                Text("This entry is encrypted")
                    .font(.headline)
                
                Text("Enter your PIN to view the content")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                if let tag = journalEntry.encryptedTag {
                    Spacer().frame(height: 8)
                    
                    EnhancedEncryptedTagView(tag: tag)
                        .padding(.vertical, 8)
                }
                
                Button {
                    onUnlockTapped()
                } label: {
                    HStack {
                        Image(systemName: "key.fill")
                        Text("Enter PIN")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.top, 8)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            )
            .padding()
            
            Spacer()
        }
        .padding()
    }
}


// MARK: - Preview

#Preview("Regular Entry") {
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

#Preview("Encrypted Entry") {
    let context = PersistenceController.preview.container.viewContext
    let entry = JournalEntry.create(in: context)
    entry.title = "My Secret Journal Entry"
    entry.createdAt = Date()
    
    // Create audio recording
    let recording = entry.createAudioRecording(filePath: "/path/to/audio.m4a")
    recording.duration = 125.5
    recording.fileSize = 1024 * 1024 * 2 // 2 MB
    
    // Create transcription - note that this would normally be encrypted
    let transcription = entry.createTranscription(text: "This is secret content that is protected with a PIN.")
    
    // Create an encrypted tag
    let encryptedTag = Tag(context: context)
    encryptedTag.name = "Private"
    encryptedTag.color = "#FF5733"
    encryptedTag.isEncrypted = true
    encryptedTag.pinHash = "dummy-hash" // In real usage, this would be properly hashed
    encryptedTag.pinSalt = "dummy-salt" // In real usage, this would be a proper salt
    encryptedTag.encryptionKeyIdentifier = "dummy-key-id"
    
    // Apply encrypted tag
    entry.encryptedTag = encryptedTag
    
    return NavigationView {
        JournalEntryView(journalEntry: entry)
            .environment(\.managedObjectContext, context)
    }
}
