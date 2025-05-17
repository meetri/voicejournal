//
//  EncryptedTagManagementView.swift
//  voicejournal
//
//  Created on 5/4/25.
//

import SwiftUI
import CoreData

/// A view for managing encrypted tags with PIN security
struct EncryptedTagManagementView: View {
    // MARK: - Environment
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Fetch Requests
    
    /// Fetch all tags, sorted by name
    @FetchRequest(
        entity: Tag.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Tag.name, ascending: true)],
        predicate: NSPredicate(format: "isEncrypted == YES")
    ) private var encryptedTags: FetchedResults<Tag>
    
    // MARK: - State
    
    @State private var showingAddTagSheet = false
    @State private var tagToEdit: Tag? = nil
    @State private var showingDeleteConfirmation: Tag? = nil
    @State private var showingPINEntryDialog = false
    @State private var showingChangePINDialog = false
    @State private var selectedTag: Tag? = nil
    @State private var actionAfterPINVerification: ((Tag, String) -> Void)? = nil
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    // Observe changes to the encrypted tags access manager
    @ObservedObject private var accessManager = EncryptedTagsAccessManager.shared
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(encryptedTags) { tag in
                        encryptedTagRow(tag)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    showingDeleteConfirmation = tag
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    selectedTag = tag
                                    showingChangePINDialog = true
                                } label: {
                                    Label("Change PIN", systemImage: "key")
                                }
                                .tint(.orange)
                                
                                Button {
                                    tagToEdit = tag
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                            .contextMenu {
                                Button {
                                    tagToEdit = tag
                                } label: {
                                    Label("Edit Tag", systemImage: "pencil")
                                }
                                
                                Button {
                                    selectedTag = tag
                                    showingChangePINDialog = true
                                } label: {
                                    Label("Change PIN", systemImage: "key")
                                }
                                
                                Divider()
                                
                                Button(role: .destructive) {
                                    showingDeleteConfirmation = tag
                                } label: {
                                    Label("Delete Tag", systemImage: "trash")
                                }
                            }
                    }
                    .onDelete(perform: deleteTags)
                } header: {
                    Text("Encrypted Tags")
                } footer: {
                    Text("Encrypted tags require a PIN to access protected content. Each tag uses a different encryption key derived from its PIN.")
                }
            }
            .navigationTitle("Encrypted Tags")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddTagSheet = true
                    } label: {
                        Label("Create Encrypted Tag", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTagSheet) {
                CreateEncryptedTagView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(item: $tagToEdit) { tag in
                // Only allow editing the name, color and icon - not PIN
                TagEditorView(tagToEdit: tag)
                    .environment(\.managedObjectContext, viewContext)
            }
            .pinEntryDialog(
                isPresented: $showingPINEntryDialog,
                title: "Enter PIN",
                message: "Enter the PIN for \"\(selectedTag?.name ?? "")\" to continue",
                onSubmit: { pin in
                    handlePINSubmission(pin)
                }
            )
            .pinEntryDialog(
                isPresented: $showingChangePINDialog,
                title: "Change PIN",
                message: "First, enter the current PIN for \"\(selectedTag?.name ?? "")\"",
                onSubmit: { pin in
                    verifyAndShowChangePINDialog(pin)
                },
                actionButtonText: "Verify"
            )
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .alert("Delete Encrypted Tag", isPresented: Binding(
                get: { showingDeleteConfirmation != nil },
                set: { if !$0 { showingDeleteConfirmation = nil } }
            )) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let tagToDelete = showingDeleteConfirmation {
                        requestPINBeforeDelete(tagToDelete)
                    }
                }
            } message: {
                Text("Are you sure you want to delete the encrypted tag \"\(showingDeleteConfirmation?.name ?? "")\"? This will permanently remove access to any entries encrypted with this tag.")
            }
            .overlay {
                if encryptedTags.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No encrypted tags")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Create encrypted tags to protect sensitive journal entries with a PIN")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button {
                            showingAddTagSheet = true
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
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private func encryptedTagRow(_ tag: Tag) -> some View {
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
            
            VStack(alignment: .leading, spacing: 4) {
                Text(tag.name ?? "Unnamed Tag")
                    .font(.body)
                
                // Display count of entries associated with the tag
                let count = tag.encryptedEntriesCount
                Text("\(count) encrypted \(count == 1 ? "entry" : "entries")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Access button
            if tag.encryptedEntriesCount > 0 {
                if tag.hasGlobalAccess {
                    // Show a button to revoke access
                    Button {
                        EncryptedTagsAccessManager.shared.revokeAccess(from: tag)
                        // This will automatically notify observers
                    } label: {
                        HStack {
                            Image(systemName: "lock.open.fill")
                            Text("Revoke")
                        }
                        .font(.footnote)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green)
                        .cornerRadius(16)
                    }
                } else {
                    // Show a button to grant access
                    Button {
                        selectedTag = tag
                        setupActionAfterPIN { tag, pin in
                            // Grant global access to this tag
                            let success = EncryptedTagsAccessManager.shared.grantAccess(to: tag, with: pin)
                            if !success {                                
                                showAlert(title: "Error", message: "Failed to grant access to the tag.")
                            }
                        }
                        showingPINEntryDialog = true
                    } label: {
                        HStack {
                            Image(systemName: "lock.fill")
                            Text("Grant Access")
                        }
                        .font(.footnote)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(tag.swiftUIColor)
                        .cornerRadius(16)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Methods
    
    /// Delete multiple tags
    private func deleteTags(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let tag = encryptedTags[index]
                requestPINBeforeDelete(tag)
            }
        }
    }
    
    /// Request PIN verification before deleting a tag
    private func requestPINBeforeDelete(_ tag: Tag) {
        selectedTag = tag
        setupActionAfterPIN { tag, _ in
            deleteTag(tag)
        }
        showingPINEntryDialog = true
    }
    
    /// Delete a tag after PIN verification
    private func deleteTag(_ tag: Tag) {
        // Remove any encryption keys from keychain
        if let keyIdentifier = tag.encryptionKeyIdentifier {
            _ = EncryptionManager.deleteTagEncryptionKey(for: keyIdentifier)
        }
        
        // Delete the tag and save context
        viewContext.delete(tag)
        saveContext()
    }
    
    /// Setup an action to perform after PIN verification
    private func setupActionAfterPIN(_ action: @escaping (Tag, String) -> Void) {
        actionAfterPINVerification = action
    }
    
    /// Handle PIN submission
    private func handlePINSubmission(_ pin: String) {
        guard let tag = selectedTag else { 
            return
        }
        
        if tag.verifyPin(pin) {
            // PIN is valid, perform the action
            actionAfterPINVerification?(tag, pin)
            // Dialog will close automatically
        } else {
            // PIN verification failed
            // We need to show the alert after the dialog dismisses itself
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.showAlert(title: "Incorrect PIN", message: "The PIN you entered does not match the PIN for this tag.")
                
                // Show the PIN entry dialog again after showing the alert
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.showingPINEntryDialog = true
                }
            }
        }
    }
    
    /// Verify current PIN and show change PIN dialog
    private func verifyAndShowChangePINDialog(_ currentPin: String) {
        guard let tag = selectedTag else {
            return
        }
        
        if tag.verifyPin(currentPin) {
            // Show a new dialog to set the new PIN
            withAnimation {
                showEnterNewPINDialog(tag: tag, currentPin: currentPin)
            }
            // Dialog will close automatically
        } else {
            // PIN verification failed
            // We need to show the alert after the dialog dismisses itself
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.showAlert(title: "Incorrect PIN", message: "The PIN you entered does not match the current PIN for this tag.")
                
                // Show the PIN entry dialog again after showing the alert
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.showingChangePINDialog = true
                }
            }
        }
    }
    
    /// Show dialog to enter a new PIN
    private func showEnterNewPINDialog(tag: Tag, currentPin: String) {
        // We'll create a custom state to show a new PIN entry dialog
        let alert = UIAlertController(
            title: "Set New PIN",
            message: "Enter a new PIN for \"\(tag.name ?? "")\"",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "New PIN (at least 4 digits)"
            textField.keyboardType = .numberPad
            textField.isSecureTextEntry = true
        }
        
        alert.addTextField { textField in
            textField.placeholder = "Confirm new PIN"
            textField.keyboardType = .numberPad
            textField.isSecureTextEntry = true
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        let setAction = UIAlertAction(title: "Set New PIN", style: .default) { [weak alert] _ in
            guard let textFields = alert?.textFields,
                  textFields.count >= 2,
                  let newPIN = textFields[0].text,
                  let confirmPIN = textFields[1].text else {
                return
            }
            
            // Validate PIN
            if newPIN.count < 4 {
                self.showAlert(title: "PIN Too Short", message: "PIN must be at least 4 digits.")
                return
            }
            
            if newPIN != confirmPIN {
                self.showAlert(title: "PINs Don't Match", message: "The confirmation PIN doesn't match the new PIN.")
                return
            }
            
            // Change the PIN
            if tag.changePin(currentPin: currentPin, newPin: newPIN) {
                self.showAlert(title: "PIN Changed", message: "The PIN for \"\(tag.name ?? "")\" has been successfully changed.")
            } else {
                self.showAlert(title: "Error", message: "An error occurred while changing the PIN.")
            }
        }
        
        alert.addAction(cancelAction)
        alert.addAction(setAction)
        
        // Present the alert
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }
    
    /// Show an alert with custom title and message
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
    
    /// Save the managed object context
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            // Error occurred
            showAlert(title: "Error", message: "An error occurred while saving changes.")
        }
    }
}

// MARK: - Create Encrypted Tag View

/// A view for creating a new encrypted tag with a PIN
struct CreateEncryptedTagView: View {
    // MARK: - Environment
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    
    @State private var tagName: String = ""
    @State private var tagColorHex: String = Tag.generateRandomHexColor()
    @State private var selectedColor: Color = .blue
    @State private var selectedIconName: String? = nil
    @State private var pin: String = ""
    @State private var confirmPin: String = ""
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            Form {
                Section("Tag Information") {
                    TextField("Enter tag name", text: $tagName)
                    
                    ColorPicker("Select Color", selection: $selectedColor, supportsOpacity: false)
                    
                    TextField("Icon name (optional)", text: $selectedIconName.bound)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onChange(of: selectedIconName) { _, newValue in
                            // Limit to valid SF Symbols
                            if let newValue = newValue, !newValue.isEmpty {
                                if UIImage(systemName: newValue) == nil {
                                    // Invalid SF Symbol name
                                    errorMessage = "'\(newValue)' is not a valid SF Symbol name"
                                    showingErrorAlert = true
                                }
                            }
                        }
                        
                    // Display the selected icon if valid
                    if let iconName = selectedIconName, !iconName.isEmpty, UIImage(systemName: iconName) != nil {
                        Label("Selected icon", systemImage: iconName)
                            .foregroundColor(selectedColor)
                    }
                    
                    // Suggestions for icons
                    Text("Examples: lock.shield, key.fill, lock.doc, lock.rectangle, exclamationmark.shield")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Security") {
                    SecureField("Enter PIN (at least 4 digits)", text: $pin)
                        .keyboardType(.numberPad)
                    
                    SecureField("Confirm PIN", text: $confirmPin)
                        .keyboardType(.numberPad)
                    
                    Toggle("Show PIN", isOn: $showPIN)
                    
                    if showPIN {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("PIN: \(pin)")
                            Text("Confirm: \(confirmPin)")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    // Empty section for the footer
                } footer: {
                    Text("Encrypted tags use a PIN to secure content. Make sure you remember this PIN as it cannot be recovered if forgotten.")
                        .font(.caption)
                }
            }
            .onChange(of: selectedColor) { _, newColor in
                // Update hex when color picker changes
                tagColorHex = newColor.toHex() ?? Tag.generateRandomHexColor()
            }
            .navigationTitle("Create Encrypted Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createEncryptedTag()
                    }
                    .disabled(!isFormValid)
                }
            }
            .alert(errorMessage, isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) {}
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Whether to show the PIN in plaintext
    @State private var showPIN: Bool = false
    
    /// Whether the form is valid
    private var isFormValid: Bool {
        let trimmedName = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        let pinValid = pin.count >= 4 && pin == confirmPin && pin.allSatisfy { $0.isNumber }
        return !trimmedName.isEmpty && pinValid
    }
    
    // MARK: - Methods
    
    /// Create a new encrypted tag
    private func createEncryptedTag() {
        let trimmedName = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Verify inputs
        guard !trimmedName.isEmpty else {
            errorMessage = "Tag name cannot be empty"
            showingErrorAlert = true
            return
        }
        
        guard pin.count >= 4 else {
            errorMessage = "PIN must be at least 4 digits"
            showingErrorAlert = true
            return
        }
        
        guard pin == confirmPin else {
            errorMessage = "PINs do not match"
            showingErrorAlert = true
            return
        }
        
        guard pin.allSatisfy({ $0.isNumber }) else {
            errorMessage = "PIN must contain only numbers"
            showingErrorAlert = true
            return
        }
        
        // Create the tag
        if let encryptedTag = Tag.createEncrypted(
            name: trimmedName,
            pin: pin,
            colorHex: tagColorHex,
            in: viewContext
        ) {
            // Set icon if provided
            if let iconName = selectedIconName, !iconName.isEmpty {
                encryptedTag.iconName = iconName
            }
            
            do {
                try viewContext.save()
                dismiss()
            } catch {
                // Error occurred
                errorMessage = "Error creating encrypted tag: \(error.localizedDescription)"
                showingErrorAlert = true
            }
        } else {
            errorMessage = "Failed to create encrypted tag"
            showingErrorAlert = true
        }
    }
}

// MARK: - Preview

#Preview {
    EncryptedTagManagementView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

#Preview("Create Encrypted Tag") {
    CreateEncryptedTagView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
