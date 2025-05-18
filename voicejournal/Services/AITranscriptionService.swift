//
//  AITranscriptionService.swift
//  voicejournal
//
//  Created by meetri on 5/18/25.
//

import Foundation
import CoreData
import Combine

/// Service for enhancing transcriptions using AI
class AITranscriptionService: ObservableObject {
    static let shared = AITranscriptionService()
    
    @Published var isProcessing = false
    @Published var processingProgress: Float = 0.0
    
    private let aiManager = AIConfigurationManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    // MARK: - Main Enhancement Function
    
    /// Enhance a transcription with AI post-processing
    func enhanceTranscription(
        text: String,
        features: Set<TranscriptionFeature> = [.punctuation, .capitalization, .paragraphs],
        context: NSManagedObjectContext
    ) async throws -> EnhancedTranscription {
        guard let config = aiManager.activeConfiguration,
              config.isValid else {
            throw AITranscriptionError.noActiveConfiguration
        }
        
        isProcessing = true
        processingProgress = 0.0
        
        defer {
            isProcessing = false
            processingProgress = 1.0
        }
        
        var enhancedText = text
        var segments: [TranscriptionSegment] = []
        var detectedLanguage: String?
        var speakers: [String]?
        
        // Process each feature
        for feature in features.sorted(by: { $0.order < $1.order }) {
            processingProgress = Float(feature.order) / Float(features.count)
            
            switch feature {
            case .punctuation:
                enhancedText = try await addPunctuation(to: enhancedText)
            case .capitalization:
                enhancedText = try await fixCapitalization(in: enhancedText)
            case .paragraphs:
                enhancedText = try await addParagraphs(to: enhancedText)
            case .speakerDiarization:
                let result = try await identifySpeakers(in: enhancedText)
                enhancedText = result.text
                speakers = result.speakers
            case .languageDetection:
                detectedLanguage = try await detectLanguage(in: enhancedText)
            case .noiseReduction:
                // This would be handled at the audio level, not text
                break
            }
        }
        
        return EnhancedTranscription(
            originalText: text,
            enhancedText: enhancedText,
            segments: segments,
            detectedLanguage: detectedLanguage,
            speakers: speakers,
            appliedFeatures: features
        )
    }
    
    // MARK: - Individual Enhancement Functions
    
    /// Add punctuation to unpunctuated text
    private func addPunctuation(to text: String) async throws -> String {
        let prompt = """
        Add appropriate punctuation to the following text while maintaining the exact words and their order. Only add punctuation marks where needed:
        
        \(text)
        """
        
        return try await processWithAI(prompt: prompt, systemPrompt: "You are a punctuation assistant. Add only necessary punctuation without changing any words.")
    }
    
    /// Fix capitalization issues
    private func fixCapitalization(in text: String) async throws -> String {
        let prompt = """
        Fix the capitalization in the following text. Capitalize proper nouns, sentence beginnings, and follow standard English capitalization rules:
        
        \(text)
        """
        
        return try await processWithAI(prompt: prompt, systemPrompt: "You are a capitalization assistant. Fix capitalization without changing any words.")
    }
    
    /// Add paragraph breaks to long text
    private func addParagraphs(to text: String) async throws -> String {
        let prompt = """
        Add paragraph breaks to the following text where appropriate. Group related sentences together. Do not change any words:
        
        \(text)
        """
        
        return try await processWithAI(prompt: prompt, systemPrompt: "You are a text formatting assistant. Add paragraph breaks without changing any words.")
    }
    
    /// Identify different speakers in the text
    private func identifySpeakers(in text: String) async throws -> (text: String, speakers: [String]) {
        let prompt = """
        Identify different speakers in the following conversation and mark them appropriately. Use format "Speaker 1:", "Speaker 2:", etc. if names are not evident:
        
        \(text)
        """
        
        let result = try await processWithAI(prompt: prompt, systemPrompt: "You are a conversation analyst. Identify speakers without changing the conversation content.")
        
        // Extract speaker labels from the result
        let speakers = extractSpeakers(from: result)
        
        return (text: result, speakers: speakers)
    }
    
    /// Detect the language of the text
    private func detectLanguage(in text: String) async throws -> String {
        let prompt = """
        Detect the language of the following text and return only the ISO 639-1 language code (e.g., 'en' for English, 'es' for Spanish):
        
        \(text)
        """
        
        return try await processWithAI(prompt: prompt, systemPrompt: "You are a language detection system. Return only the ISO 639-1 language code.")
    }
    
    // MARK: - AI Processing
    
    /// Process text with AI using the active configuration
    private func processWithAI(prompt: String, systemPrompt: String? = nil) async throws -> String {
        guard let config = aiManager.activeConfiguration,
              let apiEndpoint = config.apiEndpoint,
              let apiKey = config.apiKey else {
            throw AITranscriptionError.noActiveConfiguration
        }
        
        let actualSystemPrompt = systemPrompt ?? config.systemPrompt ?? "You are a helpful assistant."
        
        // Create the API request based on the vendor
        let requestBody: [String: Any]
        
        switch config.aiVendor {
        case .openai:
            requestBody = [
                "model": config.modelIdentifier ?? "gpt-4",
                "messages": [
                    ["role": "system", "content": actualSystemPrompt],
                    ["role": "user", "content": prompt]
                ],
                "temperature": 0.3,
                "max_tokens": 4000
            ]
        case .openrouter:
            requestBody = [
                "model": config.modelIdentifier ?? "openai/gpt-4",
                "messages": [
                    ["role": "system", "content": actualSystemPrompt],
                    ["role": "user", "content": prompt]
                ],
                "temperature": 0.3,
                "max_tokens": 4000
            ]
        case .custom:
            // Generic OpenAI-compatible format
            requestBody = [
                "model": config.modelIdentifier ?? "gpt-4",
                "messages": [
                    ["role": "system", "content": actualSystemPrompt],
                    ["role": "user", "content": prompt]
                ],
                "temperature": 0.3,
                "max_tokens": 4000
            ]
        case .none:
            throw AITranscriptionError.invalidConfiguration
        }
        
        // Create the request
        guard let url = URL(string: "\(apiEndpoint)/chat/completions") else {
            throw AITranscriptionError.invalidEndpoint
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add headers from the AI manager
        if let headers = aiManager.getRequestHeaders() {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        // Add request body
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // Make the API call
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AITranscriptionError.apiRequestFailed
        }
        
        // Parse the response
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = json?["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AITranscriptionError.invalidResponse
        }
        
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Helper Functions
    
    /// Extract speaker names from diarized text
    private func extractSpeakers(from text: String) -> [String] {
        let pattern = #"(Speaker \d+|[A-Za-z]+):"#
        let regex = try? NSRegularExpression(pattern: pattern)
        
        let matches = regex?.matches(in: text, range: NSRange(text.startIndex..., in: text)) ?? []
        
        let speakers = matches.compactMap { match -> String? in
            guard let range = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[range])
        }
        
        return Array(Set(speakers)).sorted()
    }
}

// MARK: - Supporting Types

enum TranscriptionFeature: CaseIterable {
    case punctuation
    case capitalization
    case paragraphs
    case speakerDiarization
    case languageDetection
    case noiseReduction
    
    var order: Int {
        switch self {
        case .punctuation: return 1
        case .capitalization: return 2
        case .paragraphs: return 3
        case .speakerDiarization: return 4
        case .languageDetection: return 5
        case .noiseReduction: return 0
        }
    }
    
    var displayName: String {
        switch self {
        case .punctuation:
            return "Punctuation"
        case .capitalization:
            return "Capitalization"
        case .paragraphs:
            return "Paragraph Formatting"
        case .speakerDiarization:
            return "Speaker Identification"
        case .languageDetection:
            return "Language Detection"
        case .noiseReduction:
            return "Noise Reduction"
        }
    }
    
    var description: String {
        switch self {
        case .punctuation:
            return "Add proper punctuation marks"
        case .capitalization:
            return "Fix capitalization issues"
        case .paragraphs:
            return "Add paragraph breaks"
        case .speakerDiarization:
            return "Identify different speakers"
        case .languageDetection:
            return "Detect the spoken language"
        case .noiseReduction:
            return "Reduce background noise"
        }
    }
}

struct EnhancedTranscription {
    let originalText: String
    let enhancedText: String
    let segments: [TranscriptionSegment]
    let detectedLanguage: String?
    let speakers: [String]?
    let appliedFeatures: Set<TranscriptionFeature>
}

enum AITranscriptionError: Error {
    case noActiveConfiguration
    case invalidConfiguration
    case invalidEndpoint
    case apiRequestFailed
    case invalidResponse
    case languageNotSupported
    
    var localizedDescription: String {
        switch self {
        case .noActiveConfiguration:
            return "No active AI configuration found"
        case .invalidConfiguration:
            return "Invalid AI configuration"
        case .invalidEndpoint:
            return "Invalid API endpoint"
        case .apiRequestFailed:
            return "AI API request failed"
        case .invalidResponse:
            return "Invalid response from AI service"
        case .languageNotSupported:
            return "Language not supported for this feature"
        }
    }
}