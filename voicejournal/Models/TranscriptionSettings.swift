//
//  TranscriptionSettings.swift
//  voicejournal
//
//  Created by meetri on 5/18/25.
//

import Foundation

class TranscriptionSettings: ObservableObject {
    static let shared = TranscriptionSettings()
    
    @Published var enabledFeatures: Set<TranscriptionFeature> = [.punctuation, .capitalization]
    @Published var autoEnhanceNewTranscriptions = true
    @Published var preferredLanguage: String = "en"
    @Published var enableSpeakerDiarization = false
    @Published var enableLanguageDetection = false
    @Published var enhanceExistingTranscriptions = false
    
    private let userDefaults = UserDefaults.standard
    
    private init() {
        loadSettings()
    }
    
    func loadSettings() {
        if let featuresData = userDefaults.data(forKey: "transcriptionFeatures"),
           let features = try? JSONDecoder().decode(Set<String>.self, from: featuresData) {
            enabledFeatures = Set(features.compactMap { featureName in
                TranscriptionFeature.allCases.first { $0.displayName == featureName }
            })
        }
        
        autoEnhanceNewTranscriptions = userDefaults.bool(forKey: "autoEnhanceNewTranscriptions")
        preferredLanguage = userDefaults.string(forKey: "preferredLanguage") ?? "en"
        enableSpeakerDiarization = userDefaults.bool(forKey: "enableSpeakerDiarization")
        enableLanguageDetection = userDefaults.bool(forKey: "enableLanguageDetection")
        enhanceExistingTranscriptions = userDefaults.bool(forKey: "enhanceExistingTranscriptions")
    }
    
    func saveSettings() {
        let featureNames = enabledFeatures.map { $0.displayName }
        if let featuresData = try? JSONEncoder().encode(featureNames) {
            userDefaults.set(featuresData, forKey: "transcriptionFeatures")
        }
        
        userDefaults.set(autoEnhanceNewTranscriptions, forKey: "autoEnhanceNewTranscriptions")
        userDefaults.set(preferredLanguage, forKey: "preferredLanguage")
        userDefaults.set(enableSpeakerDiarization, forKey: "enableSpeakerDiarization")
        userDefaults.set(enableLanguageDetection, forKey: "enableLanguageDetection")
        userDefaults.set(enhanceExistingTranscriptions, forKey: "enhanceExistingTranscriptions")
    }
    
    func toggleFeature(_ feature: TranscriptionFeature) {
        if enabledFeatures.contains(feature) {
            enabledFeatures.remove(feature)
        } else {
            enabledFeatures.insert(feature)
        }
        saveSettings()
    }
    
    func isFeatureEnabled(_ feature: TranscriptionFeature) -> Bool {
        return enabledFeatures.contains(feature)
    }
}