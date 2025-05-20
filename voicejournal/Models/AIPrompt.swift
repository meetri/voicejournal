//
//  AIPrompt.swift
//  voicejournal
//
//  Created on 5/19/25.
//

import Foundation
import CoreData

/// Model for storing AI prompt templates
class AIPrompt: NSManagedObject, Identifiable {
    
    // MARK: - Properties
    
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var content: String
    @NSManaged var type: String
    @NSManaged var isDefault: Bool
    @NSManaged var createdAt: Date
    @NSManaged var modifiedAt: Date
    
    // MARK: - Initialization
    
    static func create(
        name: String,
        content: String,
        type: AIPromptType,
        isDefault: Bool = false,
        in context: NSManagedObjectContext
    ) -> AIPrompt {
        let prompt = AIPrompt(context: context)
        prompt.id = UUID()
        prompt.name = name
        prompt.content = content
        prompt.type = type.rawValue
        prompt.isDefault = isDefault
        prompt.createdAt = Date()
        prompt.modifiedAt = Date()
        return prompt
    }
    
    // MARK: - Helpers
    
    var promptType: AIPromptType? {
        guard let type = self.type else { return nil }
        return AIPromptType(rawValue: type)
    }
    
    // MARK: - Fetch Requests
    
    static func fetch(
        type: AIPromptType? = nil,
        in context: NSManagedObjectContext
    ) -> [AIPrompt] {
        let request: NSFetchRequest<AIPrompt> = AIPrompt.fetchRequest()
        
        // Add type predicate if specified
        if let type = type {
            request.predicate = NSPredicate(format: "type == %@", type.rawValue)
        }
        
        // Sort by name
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \AIPrompt.isDefault, ascending: false),
            NSSortDescriptor(keyPath: \AIPrompt.name, ascending: true)
        ]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching AI prompts: \(error)")
            return []
        }
    }
    
    static func fetchDefault(
        for type: AIPromptType,
        in context: NSManagedObjectContext
    ) -> AIPrompt? {
        let request: NSFetchRequest<AIPrompt> = AIPrompt.fetchRequest()
        request.predicate = NSPredicate(format: "type == %@ AND isDefault == YES", type.rawValue)
        request.fetchLimit = 1
        
        do {
            let results = try context.fetch(request)
            return results.first
        } catch {
            print("Error fetching default AI prompt: \(error)")
            return nil
        }
    }
    
    /// Set this prompt as the default for its type
    func setAsDefault(in context: NSManagedObjectContext) {
        guard let type = self.type else { return }
        
        // Unset any existing defaults for this type
        let request: NSFetchRequest<AIPrompt> = AIPrompt.fetchRequest()
        request.predicate = NSPredicate(format: "type == %@ AND isDefault == YES", type)
        
        do {
            let results = try context.fetch(request)
            for prompt in results {
                prompt.isDefault = false
            }
        } catch {
            print("Error clearing default prompts: \(error)")
        }
        
        // Set this prompt as default
        self.isDefault = true
        self.modifiedAt = Date()
        
        // Save changes
        try? context.save()
    }
}

// MARK: - Types

enum AIPromptType: String, CaseIterable {
    case audioAnalysis = "audioAnalysis"
    case transcriptionEnhancement = "transcriptionEnhancement"
    
    var displayName: String {
        switch self {
        case .audioAnalysis:
            return "Audio Analysis"
        case .transcriptionEnhancement:
            return "Transcription Enhancement"
        }
    }
    
    var description: String {
        switch self {
        case .audioAnalysis:
            return "Used to analyze audio recordings and generate insights"
        case .transcriptionEnhancement:
            return "Used to enhance and format raw transcription text"
        }
    }
}

// MARK: - Core Data Generation

extension AIPrompt {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<AIPrompt> {
        return NSFetchRequest<AIPrompt>(entityName: "AIPrompt")
    }
}