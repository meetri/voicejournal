//
//  AIConfigurationView.swift
//  voicejournal
//
//  Created by meetri on 5/18/25.
//

import SwiftUI
import CoreData

struct AIConfigurationView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.themeManager) var themeManager
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var aiManager = AIConfigurationManager.shared
    
    @State private var showingAddConfiguration = false
    @State private var configurationToEdit: AIConfiguration?
    @State private var showingDeleteAlert = false
    @State private var configurationToDelete: AIConfiguration?
    
    var body: some View {
        NavigationView {
            List {
                // Active Configuration Section
                Section {
                    if let activeConfig = aiManager.activeConfiguration {
                        ConfigurationRow(
                            configuration: activeConfig,
                            isActive: true,
                            onEdit: { config in
                                configurationToEdit = config
                            },
                            onSetActive: { _ in },
                            onDelete: { config in
                                configurationToDelete = config
                                showingDeleteAlert = true
                            }
                        )
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text("No active configuration")
                                .foregroundColor(themeManager.theme.textSecondary)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                    }
                } header: {
                    Text("ACTIVE CONFIGURATION")
                }
                
                // Other Configurations Section
                let inactiveConfigs = aiManager.configurations.filter { !($0.isActive) }
                if !inactiveConfigs.isEmpty {
                    Section {
                        ForEach(inactiveConfigs, id: \.self) { config in
                            ConfigurationRow(
                                configuration: config,
                                isActive: false,
                                onEdit: { config in
                                    configurationToEdit = config
                                },
                                onSetActive: { config in
                                    aiManager.setActiveConfiguration(config)
                                },
                                onDelete: { config in
                                    configurationToDelete = config
                                    showingDeleteAlert = true
                                }
                            )
                        }
                    } header: {
                        Text("AVAILABLE CONFIGURATIONS")
                    }
                }
                
                // AI Prompts Section
                Section {
                    NavigationLink {
                        AIPromptManagementView()
                            .environment(\.managedObjectContext, viewContext)
                    } label: {
                        Label("Manage AI Prompts", systemImage: "text.bubble")
                    }
                } header: {
                    Text("AI PROMPTS")
                }
                
                // Add New Configuration Section
                Section {
                    Button {
                        showingAddConfiguration = true
                    } label: {
                        Label("Add Configuration", systemImage: "plus.circle.fill")
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .background(themeManager.theme.background)
            .scrollContentBackground(.hidden)
            .navigationTitle("AI Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .themedNavigation()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(themeManager.theme.accent)
                }
            }
        }
        .sheet(isPresented: $showingAddConfiguration) {
            AddAIConfigurationView()
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(item: $configurationToEdit) { config in
            EditAIConfigurationView(configuration: config)
                .environment(\.managedObjectContext, viewContext)
        }
        .alert("Delete Configuration", isPresented: $showingDeleteAlert, presenting: configurationToDelete) { config in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                aiManager.deleteConfiguration(config)
            }
        } message: { config in
            Text("Are you sure you want to delete '\(config.name ?? "Unknown")'?")
        }
    }
}

struct ConfigurationRow: View {
    let configuration: AIConfiguration
    let isActive: Bool
    let onEdit: (AIConfiguration) -> Void
    let onSetActive: (AIConfiguration) -> Void
    let onDelete: (AIConfiguration) -> Void
    
    @State private var showingDetails = false
    
    var body: some View {
        Button {
            showingDetails = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(configuration.name ?? "Unknown")
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 12) {
                        Text(configuration.aiVendor?.displayName ?? "Unknown")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if configuration.totalRequests > 0 {
                            Text("\(configuration.totalRequests) requests")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .imageScale(.large)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                        .imageScale(.small)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetails) {
            ConfigurationDetailView(
                configuration: configuration,
                isActive: isActive,
                onEdit: onEdit,
                onSetActive: onSetActive,
                onDelete: onDelete
            )
        }
    }
}

// MARK: - Configuration Detail View

struct ConfigurationDetailView: View {
    let configuration: AIConfiguration
    let isActive: Bool
    let onEdit: (AIConfiguration) -> Void
    let onSetActive: (AIConfiguration) -> Void
    let onDelete: (AIConfiguration) -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationView {
            List {
                // Configuration Info
                Section {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(configuration.name ?? "Unknown")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Provider")
                        Spacer()
                        Text(configuration.aiVendor?.displayName ?? "Unknown")
                            .foregroundColor(.secondary)
                    }
                    
                    if let endpoint = configuration.apiEndpoint {
                        HStack {
                            Text("Endpoint")
                            Spacer()
                            Text(endpoint)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
                
                // Token Usage
                Section {
                    HStack {
                        Text("Total Requests")
                        Spacer()
                        Text("\(configuration.totalRequests)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Input Tokens")
                        Spacer()
                        Text("\(configuration.totalInputTokens.formatted())")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Output Tokens")
                        Spacer()
                        Text("\(configuration.totalOutputTokens.formatted())")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Total Tokens")
                        Spacer()
                        Text("\((configuration.totalInputTokens + configuration.totalOutputTokens).formatted())")
                            .foregroundColor(.secondary)
                    }
                    
                    if let lastUsed = configuration.lastUsedAt {
                        HStack {
                            Text("Last Used")
                            Spacer()
                            Text(lastUsed, style: .relative)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("USAGE METRICS")
                }
                
                // Actions
                Section {
                    if isActive {
                        Button {
                            AIConfigurationManager.shared.deactivateConfiguration(configuration)
                            dismiss()
                        } label: {
                            Label("Deactivate", systemImage: "stop.circle")
                                .foregroundColor(.orange)
                        }
                    } else {
                        Button {
                            onSetActive(configuration)
                            dismiss()
                        } label: {
                            Label("Set as Active", systemImage: "checkmark.circle")
                                .foregroundColor(.green)
                        }
                    }
                    
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            onEdit(configuration)
                        }
                    } label: {
                        Label("Edit Configuration", systemImage: "pencil")
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete Configuration", systemImage: "trash")
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle(configuration.name ?? "Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Delete Configuration", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete(configuration)
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete '\(configuration.name ?? "Unknown")'?")
        }
    }
}

// MARK: - Add Configuration View

struct AddAIConfigurationView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.themeManager) var themeManager
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var selectedVendor: AIConfiguration.AIVendor = .openai
    @State private var apiEndpoint = ""
    @State private var apiKey = ""
    @State private var modelIdentifier = ""
    @State private var systemPrompt = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Configuration Name")) {
                    TextField("Name", text: $name)
                }
                
                Section(header: Text("AI Provider")) {
                    Picker("Provider", selection: $selectedVendor) {
                        ForEach(AIConfiguration.AIVendor.allCases, id: \.self) { vendor in
                            Text(vendor.displayName).tag(vendor)
                        }
                    }
                    .pickerStyle(DefaultPickerStyle())
                    .onChange(of: selectedVendor) { _, newValue in
                        if let defaultEndpoint = newValue.defaultEndpoint {
                            apiEndpoint = defaultEndpoint
                        }
                    }
                }
                
                Section(header: Text("API Settings")) {
                    TextField("API Endpoint", text: $apiEndpoint)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    SecureField("API Key", text: $apiKey)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    if selectedVendor.requiresModelSelection {
                        TextField("Model ID (e.g., gpt-4)", text: $modelIdentifier)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                }
                
                Section(header: Text("System Prompt (Optional)")) {
                    TextEditor(text: $systemPrompt)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Add Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveConfiguration()
                    }
                    .disabled(name.isEmpty || apiEndpoint.isEmpty || apiKey.isEmpty)
                }
            }
        }
        .onAppear {
            if let defaultEndpoint = selectedVendor.defaultEndpoint {
                apiEndpoint = defaultEndpoint
            }
        }
    }
    
    private func saveConfiguration() {
        // Validate required fields with detailed feedback
        guard !name.isEmpty else {
            print("Error: Configuration name cannot be empty")
            return
        }
        
        guard !apiEndpoint.isEmpty else {
            print("Error: API endpoint cannot be empty")
            return
        }
        
        guard !apiKey.isEmpty else {
            print("Error: API key cannot be empty")
            return
        }
        
        if selectedVendor.requiresModelSelection && modelIdentifier.isEmpty {
            print("Warning: Model identifier is recommended for \(selectedVendor.displayName)")
        }
        
        _ = AIConfigurationManager.shared.createConfiguration(
            name: name,
            vendor: selectedVendor,
            apiEndpoint: apiEndpoint,
            apiKey: apiKey,
            modelIdentifier: modelIdentifier.isEmpty ? nil : modelIdentifier,
            systemPrompt: systemPrompt.isEmpty ? nil : systemPrompt
        )
        dismiss()
    }
}

// MARK: - Edit Configuration View

struct EditAIConfigurationView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.themeManager) var themeManager
    @Environment(\.dismiss) var dismiss
    
    let configuration: AIConfiguration
    
    @State private var name: String
    @State private var apiEndpoint: String
    @State private var apiKey: String
    @State private var modelIdentifier: String
    @State private var systemPrompt: String
    @State private var audioAnalysisPrompt: String
    @State private var selectedPromptId: UUID?
    @State private var audioPrompts: [AIPrompt] = []
    @State private var showingEditPrompt = false
    
    init(configuration: AIConfiguration) {
        self.configuration = configuration
        _name = State(initialValue: configuration.name ?? "")
        _apiEndpoint = State(initialValue: configuration.apiEndpoint ?? "")
        _apiKey = State(initialValue: configuration.apiKey ?? "")
        _modelIdentifier = State(initialValue: configuration.modelIdentifier ?? "")
        _systemPrompt = State(initialValue: configuration.systemPrompt ?? "")
        _audioAnalysisPrompt = State(initialValue: configuration.audioAnalysisPrompt ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Configuration Name")) {
                    TextField("Name", text: $name)
                }
                
                Section(header: Text("AI Provider")) {
                    Text(configuration.aiVendor?.displayName ?? "Unknown")
                        .foregroundColor(themeManager.theme.textSecondary)
                }
                
                Section(header: Text("API Settings")) {
                    TextField("API Endpoint", text: $apiEndpoint)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    SecureField("API Key", text: $apiKey)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    if configuration.aiVendor?.requiresModelSelection == true {
                        TextField("Model ID", text: $modelIdentifier)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                }
                
                Section(header: Text("System Prompt (Optional)")) {
                    TextEditor(text: $systemPrompt)
                        .frame(minHeight: 100)
                }
                
                Section(header: Text("Audio Analysis Prompt")) {
                    Picker("Select Prompt", selection: $selectedPromptId) {
                        Text("Custom").tag(nil as UUID?)
                        ForEach(audioPrompts) { prompt in
                            Text(prompt.name ?? "Unnamed").tag(prompt.id as UUID?)
                        }
                    }
                    .onChange(of: selectedPromptId) { _, newValue in
                        updateSelectedPrompt(newValue)
                    }
                    
                    if selectedPromptId == nil {
                        TextEditor(text: $audioAnalysisPrompt)
                            .frame(minHeight: 150)
                    } else {
                        selectedPromptView
                    }
                    
                    NavigationLink("Manage Prompts") {
                        AIPromptManagementView()
                            .environment(\.managedObjectContext, viewContext)
                            .onDisappear {
                                loadAudioPrompts()
                            }
                    }
                }
            }
            .navigationTitle("Edit Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        updateConfiguration()
                    }
                    .disabled(name.isEmpty || apiEndpoint.isEmpty || apiKey.isEmpty)
                }
            }
            .onAppear {
                loadAudioPrompts()
                
                // Find selected prompt if any
                if let existingPrompt = audioPrompts.first(where: { $0.content == audioAnalysisPrompt }) {
                    selectedPromptId = existingPrompt.id
                } else {
                    selectedPromptId = nil
                }
            }
        }
    }
    
    private func loadAudioPrompts() {
        audioPrompts = AIPrompt.fetch(type: .audioAnalysis, in: viewContext)
        
        // Check if our current prompt matches any existing prompt
        if let existingPrompt = audioPrompts.first(where: { $0.content == audioAnalysisPrompt }) {
            selectedPromptId = existingPrompt.id
        } else {
            selectedPromptId = nil
        }
    }
    
    private func updateConfiguration() {
        // Validate required fields with detailed feedback
        guard !name.isEmpty else {
            print("Error: Configuration name cannot be empty")
            return
        }
        
        guard !apiEndpoint.isEmpty else {
            print("Error: API endpoint cannot be empty")
            return
        }
        
        guard !apiKey.isEmpty else {
            print("Error: API key cannot be empty")
            return
        }
        
        if configuration.aiVendor?.requiresModelSelection == true && modelIdentifier.isEmpty {
            print("Warning: Model identifier is recommended for \(configuration.aiVendor?.displayName ?? "this provider")")
        }
        
        AIConfigurationManager.shared.updateConfiguration(
            configuration,
            name: name,
            apiEndpoint: apiEndpoint,
            apiKey: apiKey,
            modelIdentifier: modelIdentifier.isEmpty ? nil : modelIdentifier,
            systemPrompt: systemPrompt.isEmpty ? nil : systemPrompt,
            audioAnalysisPrompt: audioAnalysisPrompt.isEmpty ? nil : audioAnalysisPrompt
        )
        dismiss()
    }
    
    private func updateSelectedPrompt(_ newValue: UUID?) {
        if let id = newValue, 
           let prompt = audioPrompts.first(where: { $0.id == id }) {
            guard let content = prompt.content, !content.isEmpty else {
                print("Warning: Selected prompt '\(prompt.name ?? "Unknown")' has no content")
                return
            }
            audioAnalysisPrompt = content
        } else if newValue != nil {
            print("Error: Unable to find prompt with ID: \(newValue!)")
        }
    }
    
    private var selectedPromptView: some View {
        Group {
            if let id = selectedPromptId,
               let prompt = audioPrompts.first(where: { $0.id == id }) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(prompt.name ?? "Unnamed")
                        .font(.headline)
                    
                    Text(prompt.content ?? "No content")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                }
                .padding(.vertical, 8)
            } else {
                Text("Selected prompt not found")
                    .foregroundColor(.red)
                    .italic()
            }
        }
    }
}


#Preview {
    AIConfigurationView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environment(\.themeManager, ThemeManager())
}