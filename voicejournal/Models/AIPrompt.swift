//
//  AIPrompt.swift
//  voicejournal
//
//  Created on 5/19/25.
//

import Foundation
import CoreData

/// Extension methods for AIPrompt entity
extension AIPrompt {
    
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
        print("🔍 [AIPrompt.fetchDefault] Fetching default prompt for type: \(type.rawValue)")
        
        let request: NSFetchRequest<AIPrompt> = AIPrompt.fetchRequest()
        request.predicate = NSPredicate(format: "type == %@ AND isDefault == YES", type.rawValue)
        request.fetchLimit = 1
        
        // Log existing prompts for debugging
        do {
            let allPromptsRequest: NSFetchRequest<AIPrompt> = AIPrompt.fetchRequest()
            allPromptsRequest.predicate = NSPredicate(format: "type == %@", type.rawValue)
            let allResults = try context.fetch(allPromptsRequest)
            
            print("📊 [AIPrompt.fetchDefault] Found \(allResults.count) prompts of type \(type.rawValue):")
            for (index, prompt) in allResults.enumerated() {
                print("  \(index+1). '\(prompt.name ?? "Unnamed")' - isDefault: \(prompt.isDefault), id: \(prompt.id?.uuidString ?? "nil")")
            }
        } catch {
            print("❌ [AIPrompt.fetchDefault] Error fetching all prompts: \(error)")
        }
        
        // Now try to fetch the default prompt
        do {
            let results = try context.fetch(request)
            if let defaultPrompt = results.first {
                print("✅ [AIPrompt.fetchDefault] Found default prompt: '\(defaultPrompt.name ?? "Unnamed")' with id: \(defaultPrompt.id?.uuidString ?? "nil")")
                return defaultPrompt
            } else {
                print("⚠️ [AIPrompt.fetchDefault] No default prompt found for type: \(type.rawValue)")
                return nil
            }
        } catch {
            print("❌ [AIPrompt.fetchDefault] Error fetching default AI prompt: \(error)")
            return nil
        }
    }
    
    /// Set this prompt as the default for its type
    func setAsDefault(in context: NSManagedObjectContext) {
        guard let type = self.type else {
            print("❌ [AIPrompt.setAsDefault] Failed to set default: prompt has no type")
            return
        }
        
        print("🔄 [AIPrompt.setAsDefault] Setting prompt '\(self.name ?? "Unnamed")' as default for type: \(type)")
        
        // Unset any existing defaults for this type
        let request: NSFetchRequest<AIPrompt> = AIPrompt.fetchRequest()
        request.predicate = NSPredicate(format: "type == %@ AND isDefault == YES", type)
        
        do {
            let results = try context.fetch(request)
            print("📊 [AIPrompt.setAsDefault] Found \(results.count) existing default prompts to clear")
            
            for prompt in results {
                print("  - Unsetting default status for '\(prompt.name ?? "Unnamed")' (id: \(prompt.id?.uuidString ?? "nil"))")
                prompt.isDefault = false
            }
        } catch {
            print("❌ [AIPrompt.setAsDefault] Error clearing default prompts: \(error)")
        }
        
        // Set this prompt as default
        self.isDefault = true
        self.modifiedAt = Date()
        print("✅ [AIPrompt.setAsDefault] Set isDefault = true for prompt '\(self.name ?? "Unnamed")' (id: \(self.id?.uuidString ?? "nil"))")
        
        // Save changes
        do {
            try context.save()
            print("✅ [AIPrompt.setAsDefault] Successfully saved changes to context")
            
            // Verify the change was applied correctly
            if self.isDefault {
                print("✅ [AIPrompt.setAsDefault] Verified prompt isDefault = true after save")
            } else {
                print("⚠️ [AIPrompt.setAsDefault] Warning: prompt.isDefault = false after save!")
            }
        } catch {
            print("❌ [AIPrompt.setAsDefault] Error saving context: \(error)")
        }
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
// fetchRequest() is defined in AIPrompt+CoreDataProperties.swift