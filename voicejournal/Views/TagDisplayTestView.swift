//
//  TagDisplayTestView.swift
//  voicejournal
//
//  Created on 5/4/25.
//

import SwiftUI
import CoreData

#if DEBUG
/// A view for testing and demonstrating tag display in journal entries
struct TagDisplayTestView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var testEntry: JournalEntry?
    @State private var encryptedTagPin = "1234"
    @State private var encryptedTag: Tag?
    @State private var status = ""
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Tag Display Test")
                .font(.title)
                .padding(.top)
            
            Text("This view tests the display of regular and encrypted tags")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Divider()
            
            Group {
                // Actions section
                Button("Create Test Entry") {
                    createTestEntry()
                }
                .buttonStyle(.bordered)
                
                Button("Add Regular Tags") {
                    addRegularTags()
                }
                .buttonStyle(.bordered)
                .disabled(testEntry == nil)
                
                Button("Add Encrypted Tag") {
                    addEncryptedTag()
                }
                .buttonStyle(.bordered)
                .disabled(testEntry == nil)
                
                Button("Grant Global Access to Encrypted Tag") {
                    grantGlobalAccess()
                }
                .buttonStyle(.bordered)
                .disabled(encryptedTag == nil)
                
                Divider()
                
                Text("Status: \(status)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            }
            
            Divider()
            
            // Preview of the entry
            if let entry = testEntry {
                Text("Entry Preview:")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                JournalEntryRow(entry: entry)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                    )
                    .padding(.horizontal)
            }
            
            Spacer()
            
            // Debug info
            if let entry = testEntry {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Debug Info:")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.secondary)
                    
                    Text("Entry has \((entry.tags as? Set<Tag>)?.count ?? 0) regular tags")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Entry has encrypted tag: \(entry.encryptedTag != nil ? "Yes" : "No")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let encryptedTag = entry.encryptedTag {
                        Text("Encrypted tag: \(encryptedTag.name ?? "unnamed")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Has global access: \(encryptedTag.hasGlobalAccess ? "Yes" : "No")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }
        .padding(.bottom)
    }
    
    // MARK: - Helper Methods
    
    private func createTestEntry() {
        // Create a test journal entry
        let entry = JournalEntry.create(in: viewContext)
        entry.title = "Test Entry for Tags"
        entry.createdAt = Date()
        
        // Create a transcription
        let transcription = entry.createTranscription(text: "This is a test entry for demonstrating tag display.")
        
        do {
            try viewContext.save()
            testEntry = entry
            status = "Created test entry"
        } catch {
            status = "Error creating test entry: \(error.localizedDescription)"
        }
    }
    
    private func addRegularTags() {
        guard let entry = testEntry else { return }
        
        // Add three regular tags
        let tag1 = entry.addTag("Personal", color: "#FF5733")
        let tag2 = entry.addTag("Work", color: "#33FF57")
        let tag3 = entry.addTag("Important", color: "#3357FF")
        
        do {
            try viewContext.save()
            status = "Added regular tags"
        } catch {
            status = "Error adding regular tags: \(error.localizedDescription)"
        }
    }
    
    private func addEncryptedTag() {
        guard let entry = testEntry else { return }
        
        // Create an encrypted tag
        let tag = Tag.createEncrypted(name: "Confidential", pin: encryptedTagPin, colorHex: "#FF33F3", in: viewContext)
        
        if let encryptedTag = tag {
            // Apply the encrypted tag to the entry
            if entry.applyEncryptedTagWithPin(encryptedTag, pin: encryptedTagPin) {
                self.encryptedTag = encryptedTag
                status = "Added encrypted tag"
            } else {
                status = "Failed to apply encrypted tag"
            }
        } else {
            status = "Failed to create encrypted tag"
        }
    }
    
    private func grantGlobalAccess() {
        guard let tag = encryptedTag else { return }
        
        if EncryptedTagsAccessManager.shared.grantAccess(to: tag, with: encryptedTagPin) {
            status = "Granted global access to encrypted tag"
        } else {
            status = "Failed to grant global access"
        }
    }
}

#Preview {
    TagDisplayTestView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
#endif