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
    @State private var showEncryptedTagSheet = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    // MARK: - Body
    
    var body: some View {
        VStack {
            if journalEntry.hasEncryptedContent {
                if isContentDecrypted {
                    // Show decrypted content
                    VStack(spacing: 16) {
                        HStack {
                            Text("Decrypted Content")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button {
                                reEncryptContent()
                            } label: {
                                Label("Lock", systemImage: "lock")
                                    .font(.footnote)
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        if let transcription = journalEntry.transcription, let text = transcription.text {
                            Text(text)
                                .frame(maxWidth: .infinity, alignment: .leading)
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
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
                    )
                } else {
                    // Show locked content message
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
                            
                            if encryptedTag.hasGlobalAccess {
                                // If tag has global access, show a button to auto-decrypt
                                Text("This tag has been granted global access")
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                                
                                Button {
                                    if journalEntry.decryptWithGlobalAccess() {
                                        withAnimation {
                                            isContentDecrypted = true
                                        }
                                    } else {
                                        showAlert(title: "Decryption Failed", message: "Failed to decrypt the content with global access.")
                                    }
                                } label: {
                                    Label("Decrypt with Global Access", systemImage: "lock.open")
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color.green)
                                        )
                                        .foregroundColor(.white)
                                }
                                .padding(.top, 8)
                            } else {
                                Text("This content is encrypted and requires a PIN to access")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                Button {
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
                        } else {
                            Text("Encrypted Content")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("This content is encrypted and requires a PIN to access")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button {
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
                }
            } else {
                // Show option to encrypt with tag
                VStack(spacing: 16) {
                    HStack {
                        Text("Encryption")
                            .font(.headline)
                        
                        Spacer()
                    }
                    
                    HStack {
                        Text("This content is not encrypted")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button {
                            showEncryptedTagSheet = true
                        } label: {
                            Label("Encrypt", systemImage: "lock")
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
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
                )
            }
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
    
    // MARK: - Methods
    
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

#Preview("Encrypted Content", traits: .sizeThatFitsLayout) {
    // Create a journal entry with encrypted content
    let context = PersistenceController.preview.container.viewContext
    let entry = JournalEntry.create(in: context)
    entry.title = "My Encrypted Journal Entry"
    
    // Create a transcription
    let transcription = entry.createTranscription(text: "This is some secret content that I want to keep encrypted.")
    
    // Create an encrypted tag
    let encryptedTag = Tag(context: context)
    encryptedTag.name = "Private"
    encryptedTag.color = "#FF5733"
    encryptedTag.isEncrypted = true
    encryptedTag.pinHash = "dummy-hash" // In real usage, this would be properly hashed
    encryptedTag.pinSalt = "dummy-salt" // In real usage, this would be a proper salt
    
    // Apply the encrypted tag
    entry.encryptedTag = encryptedTag
    
    return EncryptedContentView(journalEntry: entry)
        .environment(\.managedObjectContext, context)
        .padding()
}

#Preview("Unencrypted Content", traits: .sizeThatFitsLayout) {
    // Create a journal entry without encrypted content
    let context = PersistenceController.preview.container.viewContext
    let entry = JournalEntry.create(in: context)
    entry.title = "My Journal Entry"
    
    // Create a transcription
    let transcription = entry.createTranscription(text: "This is content that is not encrypted yet.")
    
    return EncryptedContentView(journalEntry: entry)
        .environment(\.managedObjectContext, context)
        .padding()
}