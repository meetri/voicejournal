//
//  ModernJournalEntryRow.swift
//  voicejournal
//
//  Created on 5/17/25.
//

import SwiftUI
import CoreData

/// A modernized row component for displaying journal entries with glassmorphism
struct ModernJournalEntryRow: View {
    @Environment(\.themeManager) var themeManager
    
    let entry: JournalEntry
    var onToggleLock: ((JournalEntry) -> Void)?
    
    var body: some View {
        GlassCardView(cornerRadius: 16, shadowRadius: 8) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with time and lock status
                HStack {
                    if let date = entry.createdAt {
                        Text(date, formatter: timeFormatter)
                            .font(.caption)
                            .foregroundColor(themeManager.theme.textSecondary)
                    }
                    
                    if let recording = entry.audioRecording {
                        Text("•")
                            .foregroundColor(themeManager.theme.textSecondary)
                        
                        Text(formatDuration(recording.duration))
                            .font(.caption)
                            .foregroundColor(themeManager.theme.textSecondary)
                    }
                    
                    Spacer()
                    
                    // Encrypted tag indicator
                    if entry.hasEncryptedContent, let tag = entry.encryptedTag {
                        HStack(spacing: 4) {
                            Image(systemName: tag.hasGlobalAccess ? "lock.open.fill" : "lock.fill")
                                .font(.caption)
                                .foregroundColor(tag.swiftUIColor)
                                
                            Text(tag.name ?? "")
                                .font(.caption)
                                .foregroundColor(tag.swiftUIColor)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(tag.swiftUIColor.opacity(0.15))
                        )
                    }
                    
                    // Lock toggle button
                    Button(action: {
                        onToggleLock?(entry)
                    }) {
                        Image(systemName: entry.isLocked ? "lock.fill" : "lock.open.fill")
                            .font(.system(size: 14))
                            .foregroundColor(entry.isLocked ? themeManager.theme.accent : themeManager.theme.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(themeManager.theme.surface.opacity(0.8))
                            )
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                
                // Title
                Text(entry.title ?? "Untitled Entry")
                    .font(.headline)
                    .foregroundColor(themeManager.theme.text)
                    .lineLimit(2)
                
                // Tags
                if let allTags = entry.tags as? Set<Tag>, !allTags.isEmpty {
                    let regularTags = allTags.filter { tag in 
                        if let encryptedTag = entry.encryptedTag {
                            return tag.objectID != encryptedTag.objectID
                        }
                        return true
                    }
                    
                    if !regularTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(Array(regularTags), id: \.self) { tag in
                                    if let name = tag.name, let color = tag.color {
                                        HStack(spacing: 4) {
                                            if let iconName = tag.iconName, !iconName.isEmpty {
                                                Image(systemName: iconName)
                                                    .font(.system(size: 11))
                                                    .foregroundColor(Color(hex: color))
                                            } else {
                                                Circle()
                                                    .fill(Color(hex: color))
                                                    .frame(width: 8, height: 8)
                                            }
                                            
                                            Text(name)
                                                .font(.caption)
                                                .foregroundColor(Color(hex: color))
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(Color(hex: color).opacity(0.15))
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Transcription preview
                if let transcription = entry.transcription {
                    if entry.hasEncryptedContent && !entry.isDecrypted {
                        if entry.hasGlobalAccess {
                            if entry.decryptWithGlobalAccess(), let text = transcription.text, !text.isEmpty {
                                Text(text)
                                    .font(.subheadline)
                                    .foregroundColor(themeManager.theme.textSecondary)
                                    .lineLimit(3)
                                    .padding(.top, 2)
                            } else {
                                HStack {
                                    Image(systemName: "lock.open")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                    Text("Encrypted content (access granted)")
                                        .font(.subheadline)
                                        .foregroundColor(themeManager.theme.textSecondary)
                                        .italic()
                                }
                                .padding(.top, 2)
                            }
                        } else {
                            HStack {
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundColor(themeManager.theme.accent)
                                Text("Encrypted content")
                                    .font(.subheadline)
                                    .foregroundColor(themeManager.theme.textSecondary)
                                    .italic()
                            }
                            .padding(.top, 2)
                        }
                    } else if let text = transcription.text, !text.isEmpty {
                        Text(text)
                            .font(.subheadline)
                            .foregroundColor(themeManager.theme.textSecondary)
                            .lineLimit(3)
                            .padding(.top, 2)
                    }
                }
            }
            .padding(16)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
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

// MARK: - Preview

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
    let transcription = entry.createTranscription(text: "This is a sample transcription of a voice journal entry. It contains the text that would be generated from the audio recording using speech recognition.")
    
    // Add tags
    let _ = entry.addTag("Personal", color: "#FF5733")
    let _ = entry.addTag("Ideas", color: "#33FF57")
    
    return List {
        ModernJournalEntryRow(entry: entry, onToggleLock: { _ in })
    }
    .environment(\.managedObjectContext, context)
    .environment(\.themeManager, ThemeManager())
}