//
//  AIConfiguration+Extensions.swift
//  voicejournal
//
//  Created by meetri on 5/18/25.
//

import Foundation
import CoreData

extension AIConfiguration {
    enum AIVendor: String, CaseIterable {
        case openai = "openai"
        case openrouter = "openrouter"
        case custom = "custom"
        
        var displayName: String {
            switch self {
            case .openai:
                return "OpenAI"
            case .openrouter:
                return "OpenRouter"
            case .custom:
                return "Custom Server"
            }
        }
        
        var defaultEndpoint: String? {
            switch self {
            case .openai:
                return "https://api.openai.com/v1"
            case .openrouter:
                return "https://openrouter.ai/api/v1"
            case .custom:
                return nil
            }
        }
        
        var requiresModelSelection: Bool {
            switch self {
            case .openrouter, .openai:
                return true
            case .custom:
                return false
            }
        }
    }
    
    var aiVendor: AIVendor? {
        guard let vendor = self.vendor else { return nil }
        return AIVendor(rawValue: vendor)
    }
    
    // MARK: - Helper methods
    
    static func createConfiguration(
        name: String,
        vendor: AIVendor,
        apiEndpoint: String? = nil,
        apiKey: String? = nil,
        modelIdentifier: String? = nil,
        systemPrompt: String? = nil,
        in context: NSManagedObjectContext
    ) -> AIConfiguration {
        let config = AIConfiguration(context: context)
        config.name = name
        config.vendor = vendor.rawValue
        config.apiEndpoint = apiEndpoint ?? vendor.defaultEndpoint
        config.apiKey = apiKey
        config.modelIdentifier = modelIdentifier
        config.systemPrompt = systemPrompt
        config.createdAt = Date()
        config.modifiedAt = Date()
        config.isActive = false
        return config
    }
    
    func update(
        name: String? = nil,
        apiEndpoint: String? = nil,
        apiKey: String? = nil,
        modelIdentifier: String? = nil,
        systemPrompt: String? = nil
    ) {
        if let name = name {
            self.name = name
        }
        if let apiEndpoint = apiEndpoint {
            self.apiEndpoint = apiEndpoint
        }
        if let apiKey = apiKey {
            self.apiKey = apiKey
        }
        if let modelIdentifier = modelIdentifier {
            self.modelIdentifier = modelIdentifier
        }
        if let systemPrompt = systemPrompt {
            self.systemPrompt = systemPrompt
        }
        self.modifiedAt = Date()
    }
    
    // MARK: - Validation
    
    var isValid: Bool {
        // Name is required
        guard let name = self.name, !name.isEmpty else { return false }
        
        // API endpoint is required
        guard let endpoint = self.apiEndpoint, !endpoint.isEmpty else { return false }
        
        // API key is required
        guard let key = self.apiKey, !key.isEmpty else { return false }
        
        return true
    }
    
    // MARK: - Active Configuration
    
    static func activeConfiguration(in context: NSManagedObjectContext) -> AIConfiguration? {
        let request: NSFetchRequest<AIConfiguration> = AIConfiguration.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        request.fetchLimit = 1
        
        do {
            let results = try context.fetch(request)
            return results.first
        } catch {
            print("Error fetching active AI configuration: \(error)")
            return nil
        }
    }
    
    func setAsActive(in context: NSManagedObjectContext) {
        // Deactivate all other configurations
        let request: NSFetchRequest<AIConfiguration> = AIConfiguration.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        
        do {
            let activeConfigs = try context.fetch(request)
            for config in activeConfigs {
                config.isActive = false
            }
            
            // Set this configuration as active
            self.isActive = true
            self.modifiedAt = Date()
            
        } catch {
            print("Error setting AI configuration as active: \(error)")
        }
    }
}