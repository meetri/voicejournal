//
//  AIPromptDefaultManager.swift
//  voicejournal
//
//  Created on 5/19/25.
//

import Foundation
import CoreData

/// Manages the creation of default AI prompts if none exist
class AIPromptDefaultManager {
    static let shared = AIPromptDefaultManager()
    
    private init() {}
    
    /// Create default prompts if they don't exist
    func createDefaultPromptsIfNeeded(in context: NSManagedObjectContext) {
        for promptType in AIPromptType.allCases {
            // Check if any prompts of this type exist
            let request: NSFetchRequest<AIPrompt> = AIPrompt.fetchRequest()
            request.predicate = NSPredicate(format: "type == %@", promptType.rawValue)
            request.fetchLimit = 1
            
            do {
                let count = try context.count(for: request)
                if count == 0 {
                    createDefaultPrompt(for: promptType, in: context)
                }
            } catch {
                print("Error checking for existing AI prompts: \(error)")
            }
        }
    }
    
    /// Create a default prompt for the specified type
    private func createDefaultPrompt(for type: AIPromptType, in context: NSManagedObjectContext) {
        print("Creating default prompt for \(type.displayName)")
        
        switch type {
        case .audioAnalysis:
            let prompt = AIPrompt.create(
                name: "Standard Audio Analysis",
                content: getDefaultAudioAnalysisPrompt(),
                type: .audioAnalysis,
                isDefault: true,
                in: context
            )
            print("Created default audio analysis prompt: \(prompt.name ?? "")")
            
        case .transcriptionEnhancement:
            let prompt = AIPrompt.create(
                name: "Standard Transcription Enhancement",
                content: getDefaultTranscriptionEnhancementPrompt(),
                type: .transcriptionEnhancement,
                isDefault: true,
                in: context
            )
            print("Created default transcription enhancement prompt: \(prompt.name ?? "")")
        }
        
        try? context.save()
    }
    
    // MARK: - Default Prompt Templates
    
    private func getDefaultAudioAnalysisPrompt() -> String {
        return """
        Please analyze this audio recording and provide:

        1. A detailed summary of the audio content
        2. Key topics and themes discussed
        3. Important insights or conclusions
        4. Any notable patterns or recurring elements
        5. Suggested action items or follow-ups (if applicable)
        6. Create relevant mermaid diagrams if the content involves:
           - Processes or workflows
           - Relationships or hierarchies
           - Timeline or sequences
           - Decision trees

        Format the response in markdown with clear sections and headers.
        If creating mermaid diagrams, use proper mermaid syntax blocks.
        """
    }
    
    private func getDefaultTranscriptionEnhancementPrompt() -> String {
        return """
        Please enhance this raw transcription text by:

        1. Correcting obvious speech-to-text errors
        2. Adding proper punctuation and capitalization
        3. Formatting paragraphs where appropriate
        4. Removing filler words and repetitions
        5. Preserving the original meaning and intent

        Return only the enhanced text without additional comments.
        """
    }
}