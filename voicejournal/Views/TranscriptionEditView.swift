//
//  TranscriptionEditView.swift
//  voicejournal
//
//  Created on 4/27/25.
//

import SwiftUI
import CoreData

/// A view for editing transcription text
struct TranscriptionEditView: View {
    // MARK: - Properties
    
    let journalEntry: JournalEntry
    @Binding var transcriptionText: String
    let onSave: () -> Void
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    
    @State private var editedText: String
    @State private var showDiscardAlert = false
    
    // MARK: - Initialization
    
    init(journalEntry: JournalEntry, transcriptionText: Binding<String>, onSave: @escaping () -> Void) {
        self.journalEntry = journalEntry
        self._transcriptionText = transcriptionText
        self.onSave = onSave
        self._editedText = State(initialValue: transcriptionText.wrappedValue)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            VStack {
                // Text editor
                TextEditor(text: $editedText)
                    .font(.body)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding()
                
                // Formatting tools
                formattingToolbar
                    .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Edit Transcription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if editedText != transcriptionText {
                            showDiscardAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTranscription()
                    }
                }
            }
            .alert("Discard Changes?", isPresented: $showDiscardAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Discard", role: .destructive) {
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to discard your changes?")
            }
        }
    }
    
    // MARK: - Subviews
    
    /// Toolbar with formatting options
    private var formattingToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                // Capitalize first letter of each sentence
                Button(action: {
                    editedText = capitalizeFirstLetterOfSentences(editedText)
                }) {
                    VStack {
                        Image(systemName: "textformat.abc.dottedunderline")
                            .font(.system(size: 20))
                        Text("Capitalize")
                            .font(.caption)
                    }
                }
                
                // Add periods at the end of sentences
                Button(action: {
                    editedText = addPeriodsToSentences(editedText)
                }) {
                    VStack {
                        Image(systemName: "text.append")
                            .font(.system(size: 20))
                        Text("Add Periods")
                            .font(.caption)
                    }
                }
                
                // Fix common speech recognition errors
                Button(action: {
                    editedText = fixCommonErrors(editedText)
                }) {
                    VStack {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 20))
                        Text("Fix Common")
                            .font(.caption)
                    }
                }
                
                // Clear formatting
                Button(action: {
                    editedText = editedText.trimmingCharacters(in: .whitespacesAndNewlines)
                }) {
                    VStack {
                        Image(systemName: "text.badge.xmark")
                            .font(.system(size: 20))
                        Text("Clean Up")
                            .font(.caption)
                    }
                }
                
                // Clear all text
                Button(action: {
                    editedText = ""
                }) {
                    VStack {
                        Image(systemName: "trash")
                            .font(.system(size: 20))
                        Text("Clear All")
                            .font(.caption)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Methods
    
    /// Save the edited transcription
    private func saveTranscription() {
        transcriptionText = editedText
        onSave()
        dismiss()
    }
    
    /// Capitalize the first letter of each sentence
    private func capitalizeFirstLetterOfSentences(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        
        // Split text into sentences
        let sentenceDelimiters = CharacterSet(charactersIn: ".!?")
        var sentences = text.components(separatedBy: sentenceDelimiters)
        
        // Process each sentence
        for i in 0..<sentences.count {
            let trimmed = sentences[i].trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                // Find the first letter and capitalize it
                if let firstLetterIndex = trimmed.firstIndex(where: { $0.isLetter }) {
                    let prefix = trimmed[..<firstLetterIndex]
                    let firstLetter = String(trimmed[firstLetterIndex]).uppercased()
                    let suffix = trimmed[trimmed.index(after: firstLetterIndex)...]
                    sentences[i] = prefix + firstLetter + suffix
                }
            }
        }
        
        // Rejoin sentences with their delimiters
        var result = ""
        for (i, sentence) in sentences.enumerated() {
            result += sentence
            if i < sentences.count - 1 {
                // Add back the delimiter that was removed
                if i < text.count {
                    let index = text.index(text.startIndex, offsetBy: result.count)
                    if index < text.endIndex {
                        result += String(text[index])
                    } else {
                        result += "."
                    }
                } else {
                    result += "."
                }
            }
        }
        
        return result
    }
    
    /// Add periods to sentences that don't have ending punctuation
    private func addPeriodsToSentences(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        
        // Split text into sentences based on common patterns
        let pattern = "([.!?])\\s+([A-Z])"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        
        let nsText = text as NSString
        let matches = regex?.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length)) ?? []
        
        var sentences: [String] = []
        var lastEnd = 0
        
        // Extract sentences based on regex matches
        for match in matches {
            let range = NSRange(location: lastEnd, length: match.range.location + 1 - lastEnd)
            sentences.append(nsText.substring(with: range))
            lastEnd = match.range.location + 1
        }
        
        // Add the last sentence
        if lastEnd < nsText.length {
            sentences.append(nsText.substring(from: lastEnd))
        }
        
        // Process each sentence to ensure it ends with punctuation
        for i in 0..<sentences.count {
            let trimmed = sentences[i].trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                let lastChar = trimmed.last!
                if !".!?".contains(lastChar) {
                    sentences[i] = trimmed + "."
                } else {
                    sentences[i] = trimmed
                }
            }
        }
        
        // Rejoin sentences with spaces
        return sentences.joined(separator: " ")
    }
    
    /// Fix common speech recognition errors
    private func fixCommonErrors(_ text: String) -> String {
        var correctedText = text
        
        // Common speech recognition errors and their corrections
        let corrections: [String: String] = [
            "i ": "I ",
            "i'm": "I'm",
            "i'll": "I'll",
            "i've": "I've",
            "i'd": "I'd",
            "cant": "can't",
            "dont": "don't",
            "wont": "won't",
            "didnt": "didn't",
            "couldnt": "couldn't",
            "shouldnt": "shouldn't",
            "wouldnt": "wouldn't",
            "isnt": "isn't",
            "arent": "aren't",
            "wasnt": "wasn't",
            "werent": "weren't",
            "hasnt": "hasn't",
            "havent": "haven't",
            "hadnt": "hadn't",
            "doesnt": "doesn't"            
        ]
        
        // Apply corrections
        for (error, correction) in corrections {
            correctedText = correctedText.replacingOccurrences(
                of: error,
                with: correction,
                options: [.caseInsensitive],
                range: nil
            )
        }
        
        return correctedText
    }
}

// MARK: - Preview

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let entry = JournalEntry.create(in: context)
    entry.title = "Test Journal Entry"
    
    let transcription = entry.createTranscription(text: "this is a sample transcription text that needs editing i cant believe how well speech recognition works its really impressive")
    
    return TranscriptionEditView(
        journalEntry: entry,
        transcriptionText: .constant(transcription.text ?? ""),
        onSave: {}
    )
}
