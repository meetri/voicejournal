//
//  AIPromptManagementView.swift
//  voicejournal
//
//  Created on 5/19/25.
//

import SwiftUI
import CoreData

struct AIPromptManagementView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.themeManager) var themeManager
    @Environment(\.dismiss) var dismiss
    
    @State private var promptType: AIPromptType = .audioAnalysis
    @State private var prompts: [AIPrompt] = []
    @State private var showingAddPrompt = false
    @State private var promptToEdit: AIPrompt?
    @State private var showingDeleteAlert = false
    @State private var promptToDelete: AIPrompt?
    
    @StateObject private var aiManager = AIConfigurationManager.shared
    
    var body: some View {
        NavigationView {
            List {
                // Select prompt type section
                Section {
                    Picker("Prompt Type", selection: $promptType) {
                        ForEach(AIPromptType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: promptType) { _, newValue in
                        loadPrompts(for: newValue)
                    }
                } header: {
                    Text("PROMPT TYPE")
                }
                
                // Existing prompts section
                Section {
                    ForEach(prompts) { prompt in
                        PromptRow(
                            prompt: prompt,
                            onEdit: { promptToEdit = prompt },
                            onDelete: {
                                promptToDelete = prompt
                                showingDeleteAlert = true
                            },
                            onSetDefault: { setDefaultPrompt(prompt) }
                        )
                    }
                    
                    if prompts.isEmpty {
                        Text("No prompts available")
                            .foregroundColor(themeManager.theme.textSecondary)
                            .italic()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 10)
                    }
                } header: {
                    Text("AVAILABLE PROMPTS")
                }
                
                // Add new prompt section
                Section {
                    Button {
                        showingAddPrompt = true
                    } label: {
                        Label("Add New Prompt", systemImage: "plus.circle.fill")
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .background(themeManager.theme.background)
            .scrollContentBackground(.hidden)
            .navigationTitle("AI Prompts")
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
            .onAppear {
                loadPrompts(for: promptType)
                createDefaultPromptsIfNeeded()
            }
        }
        .sheet(isPresented: $showingAddPrompt) {
            AddAIPromptView(promptType: promptType)
                .environment(\.managedObjectContext, viewContext)
                .onDisappear {
                    loadPrompts(for: promptType)
                }
        }
        .sheet(item: $promptToEdit) { prompt in
            EditAIPromptView(prompt: prompt)
                .environment(\.managedObjectContext, viewContext)
                .onDisappear {
                    loadPrompts(for: promptType)
                }
        }
        .alert("Delete Prompt", isPresented: $showingDeleteAlert, presenting: promptToDelete) { prompt in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deletePrompt(prompt)
            }
        } message: { prompt in
            Text("Are you sure you want to delete '\(prompt.name)'?")
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadPrompts(for type: AIPromptType) {
        prompts = AIPrompt.fetch(type: type, in: viewContext)
    }
    
    private func setDefaultPrompt(_ prompt: AIPrompt) {
        prompt.setAsDefault(in: viewContext)
        
        // If this is an audio analysis prompt, update the active configuration
        if prompt.promptType == .audioAnalysis, 
           let activeConfig = aiManager.activeConfiguration {
            activeConfig.audioAnalysisPrompt = prompt.content
            try? viewContext.save()
        }
        
        loadPrompts(for: promptType)
    }
    
    private func deletePrompt(_ prompt: AIPrompt) {
        viewContext.delete(prompt)
        try? viewContext.save()
        loadPrompts(for: promptType)
    }
    
    private func createDefaultPromptsIfNeeded() {
        // Check if default audio analysis prompt exists
        let audioAnalysisPrompts = AIPrompt.fetch(type: .audioAnalysis, in: viewContext)
        if audioAnalysisPrompts.isEmpty {
            // Create default audio analysis prompt
            let defaultContent = aiManager.getDefaultAudioAnalysisPrompt()
            _ = AIPrompt.create(
                name: "Standard Analysis",
                content: defaultContent,
                type: .audioAnalysis,
                isDefault: true,
                in: viewContext
            )
            
            // Create a second helpful prompt
            _ = AIPrompt.create(
                name: "Detailed Summary",
                content: """
                Provide a detailed summary of this audio recording, focusing on:
                
                1. Main topics discussed
                2. Key points for each topic
                3. Any decisions or action items mentioned
                4. Questions that were raised
                5. Any unresolved issues
                
                Format your response in clear, readable markdown with proper headings.
                """,
                type: .audioAnalysis,
                isDefault: false,
                in: viewContext
            )
            
            try? viewContext.save()
        }
        
        // Check if default transcription enhancement prompt exists
        let enhancementPrompts = AIPrompt.fetch(type: .transcriptionEnhancement, in: viewContext)
        if enhancementPrompts.isEmpty {
            // Create default enhancement prompt
            _ = AIPrompt.create(
                name: "Standard Enhancement",
                content: """
                Enhance this raw transcription by adding proper punctuation, capitalization, and paragraph breaks.
                Do not change any words or phrases, only improve formatting and readability.
                """,
                type: .transcriptionEnhancement,
                isDefault: true,
                in: viewContext
            )
            
            try? viewContext.save()
        }
    }
}

// MARK: - Prompt Row

struct PromptRow: View {
    let prompt: AIPrompt
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onSetDefault: () -> Void
    
    @State private var showingDetails = false
    
    var body: some View {
        Button {
            showingDetails = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(prompt.name)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Text(prompt.content.prefix(50) + (prompt.content.count > 50 ? "..." : ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if prompt.isDefault {
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
            PromptDetailView(
                prompt: prompt,
                onEdit: onEdit,
                onDelete: onDelete,
                onSetDefault: onSetDefault
            )
        }
    }
}

// MARK: - Prompt Detail View

struct PromptDetailView: View {
    let prompt: AIPrompt
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onSetDefault: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationView {
            List {
                // Prompt Info
                Section {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(prompt.name)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Type")
                        Spacer()
                        Text(prompt.promptType?.displayName ?? "Unknown")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Default")
                        Spacer()
                        Text(prompt.isDefault ? "Yes" : "No")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Created")
                        Spacer()
                        Text(prompt.createdAt, style: .date)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Modified")
                        Spacer()
                        Text(prompt.modifiedAt, style: .date)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Prompt Content
                Section {
                    Text(prompt.content)
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding(.vertical, 8)
                } header: {
                    Text("PROMPT CONTENT")
                }
                
                // Actions
                Section {
                    if !prompt.isDefault {
                        Button {
                            onSetDefault()
                            dismiss()
                        } label: {
                            Label("Set as Default", systemImage: "checkmark.circle")
                                .foregroundColor(.green)
                        }
                    }
                    
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            onEdit()
                        }
                    } label: {
                        Label("Edit Prompt", systemImage: "pencil")
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete Prompt", systemImage: "trash")
                    }
                    .disabled(prompt.isDefault)
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle(prompt.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Delete Prompt", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete '\(prompt.name)'?")
        }
    }
}

// MARK: - Add AI Prompt View

struct AddAIPromptView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.themeManager) var themeManager
    @Environment(\.dismiss) var dismiss
    
    let promptType: AIPromptType
    
    @State private var name = ""
    @State private var content = ""
    @State private var isDefault = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("PROMPT NAME")) {
                    TextField("Name", text: $name)
                }
                
                Section(header: Text("TYPE")) {
                    Text(promptType.displayName)
                        .foregroundColor(.secondary)
                    
                    Text(promptType.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }
                
                Section(header: Text("PROMPT CONTENT")) {
                    TextEditor(text: $content)
                        .frame(minHeight: 200)
                        .font(.body)
                }
                
                Section {
                    Toggle("Set as Default", isOn: $isDefault)
                }
            }
            .navigationTitle("Add Prompt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePrompt()
                    }
                    .disabled(name.isEmpty || content.isEmpty)
                }
            }
        }
    }
    
    private func savePrompt() {
        let newPrompt = AIPrompt.create(
            name: name,
            content: content,
            type: promptType,
            isDefault: isDefault, 
            in: viewContext
        )
        
        if isDefault {
            // If set as default, update the active configuration
            if promptType == .audioAnalysis,
               let activeConfig = AIConfigurationManager.shared.activeConfiguration {
                activeConfig.audioAnalysisPrompt = content
            }
        }
        
        try? viewContext.save()
        dismiss()
    }
}

// MARK: - Edit AI Prompt View

struct EditAIPromptView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.themeManager) var themeManager
    @Environment(\.dismiss) var dismiss
    
    let prompt: AIPrompt
    
    @State private var name: String
    @State private var content: String
    @State private var isDefault: Bool
    
    init(prompt: AIPrompt) {
        self.prompt = prompt
        _name = State(initialValue: prompt.name)
        _content = State(initialValue: prompt.content)
        _isDefault = State(initialValue: prompt.isDefault)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("PROMPT NAME")) {
                    TextField("Name", text: $name)
                }
                
                Section(header: Text("TYPE")) {
                    Text(prompt.promptType?.displayName ?? "Unknown")
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("PROMPT CONTENT")) {
                    TextEditor(text: $content)
                        .frame(minHeight: 200)
                        .font(.body)
                }
                
                Section {
                    Toggle("Set as Default", isOn: $isDefault)
                }
            }
            .navigationTitle("Edit Prompt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        updatePrompt()
                    }
                    .disabled(name.isEmpty || content.isEmpty)
                }
            }
        }
    }
    
    private func updatePrompt() {
        prompt.name = name
        prompt.content = content
        prompt.modifiedAt = Date()
        
        if isDefault && !prompt.isDefault {
            prompt.setAsDefault(in: viewContext)
            
            // If setting as default audio analysis prompt, update the active configuration
            if prompt.promptType == .audioAnalysis,
               let activeConfig = AIConfigurationManager.shared.activeConfiguration {
                activeConfig.audioAnalysisPrompt = content
            }
        }
        
        try? viewContext.save()
        dismiss()
    }
}