//
//  JournalEntryRow.swift
//  voicejournal
//
//  Created on 4/29/25.
//

import SwiftUI
import CoreData

/// A reusable row component for displaying journal entries in lists
struct JournalEntryRow: View {
    @Environment(\.themeManager) private var themeManager
    
    let entry: JournalEntry
    var onToggleLock: ((JournalEntry) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Time and duration
            HStack {
                if let date = entry.createdAt {
                    Text(date, formatter: timeFormatter)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let recording = entry.audioRecording {
                    if recording.isMissingFile {
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 2) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            Text("Missing")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    } else {
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(formatDuration(recording.duration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Show encryption indicator if applicable
                if entry.hasEncryptedContent, let tag = entry.encryptedTag {
                    HStack(spacing: 4) {
                        Image(systemName: tag.hasGlobalAccess ? "lock.open.fill" : "lock.fill")
                            .font(.caption)
                            .foregroundColor(tag.swiftUIColor)
                            
                        Text(tag.name ?? "")
                            .font(.caption)
                            .foregroundColor(tag.swiftUIColor)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(tag.swiftUIColor.opacity(0.15))
                    )
                }
                
                Button(action: {
                    onToggleLock?(entry)
                }) {
                    Image(systemName: entry.isLocked ? "lock.fill" : "lock.open.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            
            // Title
            Text(entry.title ?? "Untitled Entry")
                .font(.headline)
                .lineLimit(1)
            
            // Tags (excluding the encrypted tag)
            if let allTags = entry.tags as? Set<Tag>, !allTags.isEmpty {
                // Filter out the encrypted tag from the regular tags display
                let regularTags = allTags.filter { tag in 
                    if let encryptedTag = entry.encryptedTag {
                        return tag.objectID != encryptedTag.objectID
                    }
                    return true
                }
                
                if !regularTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(Array(regularTags), id: \.self) { tag in
                                if let name = tag.name, let color = tag.color {
                                    HStack(spacing: 4) {
                                        // Display icon if available, otherwise color circle
                                        if let iconName = tag.iconName, !iconName.isEmpty {
                                            Image(systemName: iconName)
                                                .font(.caption2)
                                                .foregroundColor(Color(hex: color))
                                        } else {
                                            Circle()
                                                .fill(Color(hex: color))
                                                .frame(width: 6, height: 6)
                                        }
                                        
                                        Text(name)
                                            .font(.caption2)
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(hex: color).opacity(0.2))
                                    .foregroundColor(Color(hex: color))
                                    .cornerRadius(4)
                                }
                            }
                        }
                    }
                }
            }
            
            // Preview of transcription
            if let transcription = entry.transcription {
                if entry.hasEncryptedContent && !entry.isDecrypted {
                    // If there's global access, try to decrypt on the fly for preview
                    if entry.hasGlobalAccess {
                        // Attempt to decrypt with global access
                        if entry.decryptWithGlobalAccess(), let text = transcription.text, !text.isEmpty {
                            Text(text)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                                .padding(.top, 2)
                        } else {
                            // Fallback if decryption fails
                            HStack {
                                Image(systemName: "lock.open")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                Text("Encrypted content (access granted)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                            .padding(.top, 2)
                        }
                    } else {
                        // Show encrypted content placeholder
                        Text("Encrypted content")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .italic()
                            .padding(.top, 2)
                    }
                } else if let text = transcription.text, !text.isEmpty {
                    // Show actual transcription text
                    VStack(alignment: .leading, spacing: 4) {
                        // Show enhanced indicator if enhanced transcription is available
                        if transcription.enhancedText != nil {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Text("AI Enhanced")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        // Show raw transcription by default
                        Text(text)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.theme.cellBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(themeManager.theme.cellBorder, lineWidth: 1)
                )
                .shadow(color: themeManager.theme.shadowColor, radius: 2, x: 0, y: 1)
        )
        .padding(.horizontal, 0)
        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
        .listRowBackground(Color.clear)
    }
    
    /// Format duration in seconds to MM:SS
    private func formatDuration(_ duration: Double) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let entry = JournalEntry.create(in: context)
    entry.title = "Sample Journal Entry"
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
    
    return List {
        JournalEntryRow(entry: entry, onToggleLock: { _ in })
    }
    .environment(\.managedObjectContext, context)
}
