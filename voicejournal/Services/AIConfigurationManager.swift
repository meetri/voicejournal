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
        
        // Set default audio analysis prompt
        config.audioAnalysisPrompt = getDefaultAudioAnalysisPrompt()
        
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
        systemPrompt: String? = nil,
        audioAnalysisPrompt: String? = nil
    ) {
        configuration.update(
            name: name,
            apiEndpoint: apiEndpoint,
            apiKey: apiKey,
            modelIdentifier: modelIdentifier,
            systemPrompt: systemPrompt,
            audioAnalysisPrompt: audioAnalysisPrompt
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
        guard let config = activeConfiguration else {
            print("Error: No active AI configuration found for request headers")
            return nil
        }
        guard let apiKey = config.apiKey, !apiKey.isEmpty else {
            print("Error: Missing API key in active configuration \(config.name ?? "unknown")")
            return nil
        }
        
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
        guard let config = activeConfiguration else {
            print("Error: No active AI configuration found for base URL")
            return nil
        }
        guard let endpoint = config.apiEndpoint, !endpoint.isEmpty else {
            print("Error: Missing API endpoint in active configuration \(config.name ?? "unknown")")
            return nil
        }
        return endpoint
    }
    
    func getModelIdentifier() -> String? {
        guard let config = activeConfiguration else {
            print("Error: No active AI configuration found for model identifier")
            return nil
        }
        guard let modelId = config.modelIdentifier, !modelId.isEmpty else {
            if config.aiVendor?.requiresModelSelection == true {
                print("Warning: Missing model identifier in active configuration \(config.name ?? "unknown")")
            }
            return nil
        }
        return modelId
    }
    
    func getSystemPrompt() -> String? {
        guard let config = activeConfiguration else {
            print("Error: No active AI configuration found for system prompt")
            return nil
        }
        // System prompt is optional, so we only check if it exists but don't require it
        let prompt = config.systemPrompt
        if prompt == nil {
            print("Info: No system prompt defined in active configuration \(config.name ?? "unknown")")
        }
        return prompt
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
    
    // MARK: - Default Prompt
    
    func getDefaultAudioAnalysisPrompt() -> String {
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
}