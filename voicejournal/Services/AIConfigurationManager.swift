//
//  AIConfigurationManager.swift
//  voicejournal
//
//  Created by meetri on 5/18/25.
//

import Foundation
import CoreData
import Combine

class AIConfigurationManager: ObservableObject {
    static let shared = AIConfigurationManager()
    
    @Published var activeConfiguration: AIConfiguration?
    @Published var configurations: [AIConfiguration] = []
    
    private let context: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        self.context = PersistenceController.shared.container.viewContext
        loadConfigurations()
        setupNotifications()
    }
    
    // MARK: - Configuration Management
    
    func loadConfigurations() {
        let request: NSFetchRequest<AIConfiguration> = AIConfiguration.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \AIConfiguration.name, ascending: true)]
        
        do {
            configurations = try context.fetch(request)
            activeConfiguration = configurations.first(where: { $0.isActive })
        } catch {
            print("Error loading AI configurations: \(error)")
        }
    }
    
    func createConfiguration(
        name: String,
        vendor: AIConfiguration.AIVendor,
        apiEndpoint: String? = nil,
        apiKey: String,
        modelIdentifier: String? = nil,
        systemPrompt: String? = nil
    ) -> AIConfiguration {
        let config = AIConfiguration.createConfiguration(
            name: name,
            vendor: vendor,
            apiEndpoint: apiEndpoint,
            apiKey: apiKey,
            modelIdentifier: modelIdentifier,
            systemPrompt: systemPrompt,
            in: context
        )
        
        save()
        loadConfigurations()
        return config
    }
    
    func deleteConfiguration(_ configuration: AIConfiguration) {
        context.delete(configuration)
        save()
        loadConfigurations()
    }
    
    func updateConfiguration(
        _ configuration: AIConfiguration,
        name: String? = nil,
        apiEndpoint: String? = nil,
        apiKey: String? = nil,
        modelIdentifier: String? = nil,
        systemPrompt: String? = nil
    ) {
        configuration.update(
            name: name,
            apiEndpoint: apiEndpoint,
            apiKey: apiKey,
            modelIdentifier: modelIdentifier,
            systemPrompt: systemPrompt
        )
        
        save()
        loadConfigurations()
    }
    
    func setActiveConfiguration(_ configuration: AIConfiguration) {
        configuration.setAsActive(in: context)
        save()
        loadConfigurations()
    }
    
    func deactivateConfiguration(_ configuration: AIConfiguration) {
        configuration.isActive = false
        save()
        loadConfigurations()
    }
    
    func refreshTokenUsage(for configuration: AIConfiguration) {
        // This method could be used to trigger an update to the UI
        // The actual token usage is updated automatically when API calls are made
        objectWillChange.send()
    }
    
    // MARK: - Preset Configurations
    
    func createPresetConfiguration(for vendor: AIConfiguration.AIVendor) -> AIConfiguration? {
        switch vendor {
        case .openai:
            return createConfiguration(
                name: "OpenAI GPT",
                vendor: .openai,
                apiEndpoint: vendor.defaultEndpoint,
                apiKey: "",
                modelIdentifier: "gpt-4",
                systemPrompt: nil
            )
        case .openrouter:
            return createConfiguration(
                name: "OpenRouter",
                vendor: .openrouter,
                apiEndpoint: vendor.defaultEndpoint,
                apiKey: "",
                modelIdentifier: nil,
                systemPrompt: nil
            )
        case .custom:
            return createConfiguration(
                name: "Custom Server",
                vendor: .custom,
                apiEndpoint: nil,
                apiKey: "",
                modelIdentifier: nil,
                systemPrompt: nil
            )
        }
    }
    
    // MARK: - API Request Configuration
    
    func getRequestHeaders() -> [String: String]? {
        guard let config = activeConfiguration,
              let apiKey = config.apiKey else { return nil }
        
        switch config.aiVendor {
        case .openai:
            return ["Authorization": "Bearer \(apiKey)"]
        case .openrouter:
            return [
                "Authorization": "Bearer \(apiKey)",
                "X-Title": "Voice Journal App"
            ]
        case .custom:
            return ["Authorization": "Bearer \(apiKey)"]
        case .none:
            return nil
        }
    }
    
    func getBaseURL() -> String? {
        return activeConfiguration?.apiEndpoint
    }
    
    func getModelIdentifier() -> String? {
        return activeConfiguration?.modelIdentifier
    }
    
    func getSystemPrompt() -> String? {
        return activeConfiguration?.systemPrompt
    }
    
    // MARK: - Private Methods
    
    private func save() {
        do {
            try context.save()
        } catch {
            print("Error saving AI configurations: \(error)")
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .sink { [weak self] _ in
                self?.loadConfigurations()
            }
            .store(in: &cancellables)
    }
}