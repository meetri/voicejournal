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
    
    // MARK: - Body
    
    var body: some View {
        // Use the enhanced journal entry view
        EnhancedJournalEntryView(journalEntry: journalEntry)
    }
}


// MARK: - Preview

#Preview {
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
