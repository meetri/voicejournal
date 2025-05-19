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
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text("No active configuration")
                                .foregroundColor(themeManager.theme.textSecondary)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    Text("Active Configuration")
                        .textCase(nil)
                        .font(.headline)
                        .foregroundColor(themeManager.theme.text)
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
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
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
    
    @State private var isRefreshing = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Main content
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
                
                // Token Usage Metrics
                HStack {
                    TokenMetricsView(configuration: configuration)
                        .font(.caption2)
                        .foregroundColor(themeManager.theme.textSecondary)
                    
                    Spacer()
                    
                    // Refresh button
                    Button {
                        refreshTokenUsage()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                            .foregroundColor(themeManager.theme.accent)
                            .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                            .animation(isRefreshing ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onEdit(configuration)
            }
            
            // Action buttons
            VStack(spacing: 8) {
                if isActive {
                    Button {
                        AIConfigurationManager.shared.deactivateConfiguration(configuration)
                    } label: {
                        Image(systemName: "stop.circle")
                            .foregroundColor(.orange)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                } else {
                    Button {
                        onSetActive(configuration)
                    } label: {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.green)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                
                Button {
                    onDelete(configuration)
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .padding(.vertical, 4)
    }
    
    private func refreshTokenUsage() {
        isRefreshing = true
        AIConfigurationManager.shared.refreshTokenUsage(for: configuration)
        
        // Stop the animation after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isRefreshing = false
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

// MARK: - Token Metrics View

struct TokenMetricsView: View {
    let configuration: AIConfiguration
    
    @Environment(\.themeManager) var themeManager
    
    private var totalTokens: Int64 {
        configuration.totalInputTokens + configuration.totalOutputTokens
    }
    
    private var formattedLastUsed: String {
        if let lastUsed = configuration.lastUsedAt {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return formatter.localizedString(for: lastUsed, relativeTo: Date())
        }
        return "Never"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Token usage row
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle")
                        .font(.system(size: 10))
                    Text("\(configuration.totalInputTokens.formatted()) in")
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 10))
                    Text("\(configuration.totalOutputTokens.formatted()) out")
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "sum")
                        .font(.system(size: 10))
                    Text("\(totalTokens.formatted()) total")
                }
                
                Spacer()
            }
            
            // Request count and last used
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "network")
                        .font(.system(size: 10))
                    Text("\(configuration.totalRequests) requests")
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text(formattedLastUsed)
                }
                
                Spacer()
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(themeManager.theme.surface)
        .cornerRadius(6)
    }
}

#Preview {
    AIConfigurationView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environment(\.themeManager, ThemeManager())
}