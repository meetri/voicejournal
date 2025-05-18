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
                if let activeConfig = aiManager.activeConfiguration {
                    Section {
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
                    } header: {
                        Text("Active Configuration")
                            .textCase(nil)
                            .font(.headline)
                            .foregroundColor(themeManager.theme.text)
                    }
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
                        Text("Available Configurations")
                            .textCase(nil)
                            .font(.headline)
                            .foregroundColor(themeManager.theme.text)
                    }
                }
                
                // Add New Configuration Section
                Section {
                    Button {
                        showingAddConfiguration = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(themeManager.theme.accent)
                            Text("Add Configuration")
                                .foregroundColor(themeManager.theme.accent)
                        }
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
    
    @Environment(\.themeManager) var themeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(configuration.name ?? "Unknown")
                        .font(.headline)
                        .foregroundColor(themeManager.theme.text)
                    
                    Text(configuration.aiVendor?.displayName ?? "Unknown")
                        .font(.caption)
                        .foregroundColor(themeManager.theme.textSecondary)
                }
                
                Spacer()
                
                if isActive {
                    Text("Active")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(themeManager.theme.accent.opacity(0.2))
                        .foregroundColor(themeManager.theme.accent)
                        .cornerRadius(12)
                }
            }
            
            HStack(spacing: 16) {
                Button {
                    onEdit(configuration)
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .font(.caption)
                        .foregroundColor(themeManager.theme.accent)
                }
                
                if !isActive {
                    Button {
                        onSetActive(configuration)
                    } label: {
                        Label("Activate", systemImage: "checkmark.circle")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                Button {
                    onDelete(configuration)
                } label: {
                    Label("Delete", systemImage: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 4)
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
    
    init(configuration: AIConfiguration) {
        self.configuration = configuration
        _name = State(initialValue: configuration.name ?? "")
        _apiEndpoint = State(initialValue: configuration.apiEndpoint ?? "")
        _apiKey = State(initialValue: configuration.apiKey ?? "")
        _modelIdentifier = State(initialValue: configuration.modelIdentifier ?? "")
        _systemPrompt = State(initialValue: configuration.systemPrompt ?? "")
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
        }
    }
    
    private func updateConfiguration() {
        AIConfigurationManager.shared.updateConfiguration(
            configuration,
            name: name,
            apiEndpoint: apiEndpoint,
            apiKey: apiKey,
            modelIdentifier: modelIdentifier.isEmpty ? nil : modelIdentifier,
            systemPrompt: systemPrompt.isEmpty ? nil : systemPrompt
        )
        dismiss()
    }
}

#Preview {
    AIConfigurationView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environment(\.themeManager, ThemeManager())
}