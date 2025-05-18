//
//  TranscriptionSettingsView.swift
//  voicejournal
//
//  Created by meetri on 5/18/25.
//

import SwiftUI

struct TranscriptionSettingsView: View {
    @Environment(\.themeManager) var themeManager
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var settings = TranscriptionSettings.shared
    @StateObject private var aiManager = AIConfigurationManager.shared
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - AI Configuration Status
                if aiManager.activeConfiguration == nil {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.yellow)
                            VStack(alignment: .leading) {
                                Text("No AI Configuration")
                                    .font(.headline)
                                Text("Configure an AI service to enable transcription enhancements")
                                    .font(.caption)
                                    .foregroundColor(themeManager.theme.textSecondary)
                            }
                        }
                        .padding(.vertical, 8)
                        
                        NavigationLink(destination: AIConfigurationView()) {
                            Text("Configure AI Service")
                                .foregroundColor(themeManager.theme.accent)
                        }
                    }
                }
                
                // MARK: - Automatic Enhancement
                Section {
                    Toggle("Auto-enhance new transcriptions", isOn: $settings.autoEnhanceNewTranscriptions)
                        .disabled(aiManager.activeConfiguration == nil)
                    
                    Toggle("Enhance existing transcriptions", isOn: $settings.enhanceExistingTranscriptions)
                        .disabled(aiManager.activeConfiguration == nil)
                } header: {
                    Text("Automatic Enhancement")
                        .textCase(nil)
                        .font(.headline)
                        .foregroundColor(themeManager.theme.text)
                } footer: {
                    Text("Automatically apply enabled features to new and existing transcriptions")
                        .foregroundColor(themeManager.theme.textSecondary)
                }
                
                // MARK: - Enhancement Features
                Section {
                    ForEach(TranscriptionFeature.allCases, id: \.self) { feature in
                        if feature != .noiseReduction { // Noise reduction is audio-level, not text
                            FeatureToggleRow(
                                feature: feature,
                                isEnabled: settings.isFeatureEnabled(feature),
                                onToggle: { settings.toggleFeature(feature) }
                            )
                            .disabled(aiManager.activeConfiguration == nil)
                        }
                    }
                } header: {
                    Text("Enhancement Features")
                        .textCase(nil)
                        .font(.headline)
                        .foregroundColor(themeManager.theme.text)
                } footer: {
                    Text("Select which enhancements to apply to transcriptions")
                        .foregroundColor(themeManager.theme.textSecondary)
                }
                
                // MARK: - Language Settings
                Section {
                    HStack {
                        Text("Preferred Language")
                        Spacer()
                        Picker("", selection: $settings.preferredLanguage) {
                            Text("English").tag("en")
                            Text("Spanish").tag("es")
                            Text("French").tag("fr")
                            Text("German").tag("de")
                            Text("Italian").tag("it")
                            Text("Japanese").tag("ja")
                            Text("Korean").tag("ko")
                            Text("Chinese").tag("zh")
                        }
                        .pickerStyle(MenuPickerStyle())
                        .labelsHidden()
                    }
                    
                    Toggle("Automatic language detection", isOn: $settings.enableLanguageDetection)
                        .disabled(aiManager.activeConfiguration == nil)
                } header: {
                    Text("Language Settings")
                        .textCase(nil)
                        .font(.headline)
                        .foregroundColor(themeManager.theme.text)
                } footer: {
                    Text("Set your preferred language or enable automatic detection")
                        .foregroundColor(themeManager.theme.textSecondary)
                }
                
                // MARK: - Advanced Features
                Section {
                    Toggle("Speaker identification", isOn: $settings.enableSpeakerDiarization)
                        .disabled(aiManager.activeConfiguration == nil)
                } header: {
                    Text("Advanced Features")
                        .textCase(nil)
                        .font(.headline)
                        .foregroundColor(themeManager.theme.text)
                } footer: {
                    Text("Identify different speakers in multi-person recordings")
                        .foregroundColor(themeManager.theme.textSecondary)
                }
            }
            .background(themeManager.theme.background)
            .scrollContentBackground(.hidden)
            .navigationTitle("Transcription Settings")
            .navigationBarTitleDisplayMode(.inline)
            .themedNavigation()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        settings.saveSettings()
                        dismiss()
                    }
                    .foregroundColor(themeManager.theme.accent)
                }
            }
        }
    }
}

struct FeatureToggleRow: View {
    let feature: TranscriptionFeature
    let isEnabled: Bool
    let onToggle: () -> Void
    
    @Environment(\.themeManager) var themeManager
    
    var body: some View {
        Toggle(isOn: Binding(
            get: { isEnabled },
            set: { _ in onToggle() }
        )) {
            VStack(alignment: .leading, spacing: 4) {
                Text(feature.displayName)
                    .foregroundColor(themeManager.theme.text)
                Text(feature.description)
                    .font(.caption)
                    .foregroundColor(themeManager.theme.textSecondary)
            }
        }
    }
}

#Preview {
    TranscriptionSettingsView()
        .environment(\.themeManager, ThemeManager())
}