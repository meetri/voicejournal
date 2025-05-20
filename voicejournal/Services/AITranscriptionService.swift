//
//  AITranscriptionService.swift
//  voicejournal
//
//  Created by meetri on 5/18/25.
//

import Foundation
import CoreData
import Combine
import AVFoundation

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
        let enhancementStartTime = Date()
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
        for (index, feature) in features.sorted(by: { $0.order < $1.order }).enumerated() {
            processingProgress = Float(index + 1) / Float(features.count)
            
            let featureStartTime = Date()
            
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
        
        
        let result = EnhancedTranscription(
            originalText: text,
            enhancedText: enhancedText,
            segments: segments,
            detectedLanguage: detectedLanguage,
            speakers: speakers,
            appliedFeatures: features
        )
        
        
        return result
    }
    
    // MARK: - Public Individual Enhancement Functions
    
    /// Process punctuation enhancement
    func processPunctuation(text: String) async throws -> String {
        return try await addPunctuation(to: text)
    }
    
    /// Process capitalization enhancement
    func processCapitalization(text: String) async throws -> String {
        return try await fixCapitalization(in: text)
    }
    
    /// Process paragraph formatting
    func processParagraphs(text: String) async throws -> String {
        return try await addParagraphs(to: text)
    }
    
    /// Process speaker identification
    func processSpeakerDiarization(text: String) async throws -> (text: String, speakers: [String]) {
        return try await identifySpeakers(in: text)
    }
    
    /// Process language detection
    func processLanguageDetection(text: String) async throws -> String {
        return try await detectLanguage(in: text)
    }
    
    // MARK: - Private Enhancement Functions
    
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
        let requestStartTime = Date()
        print("🔄 [AITranscriptionService.processWithAI] Starting AI request")
        
        guard let config = aiManager.activeConfiguration,
              let apiEndpoint = config.apiEndpoint,
              config.apiKey != nil else {
            print("❌ [AITranscriptionService.processWithAI] Missing configuration")
            throw AITranscriptionError.noActiveConfiguration
        }
        
        print("✅ [AITranscriptionService.processWithAI] Using AI configuration:")
        if let vendor = config.aiVendor {
            print("  - Vendor: \(vendor.rawValue)")
        } else {
            print("  - Vendor: unknown")
        }
        print("  - Endpoint: \(apiEndpoint)")
        print("  - Model: \(config.modelIdentifier ?? "default")")
        
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
            print("❌ [AITranscriptionService.processWithAI] Invalid AI vendor configuration")
            throw AITranscriptionError.invalidConfiguration
        }
        
        // Create the request
        let endpoint = "\(apiEndpoint)/chat/completions"
        print("📡 [AITranscriptionService.processWithAI] Request endpoint: \(endpoint)")
        
        guard let url = URL(string: endpoint) else {
            print("❌ [AITranscriptionService.processWithAI] Invalid URL: \(endpoint)")
            throw AITranscriptionError.invalidEndpoint
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add headers from the AI manager
        if let headers = aiManager.getRequestHeaders() {
            print("📋 [AITranscriptionService.processWithAI] Setting request headers:")
            for (key, value) in headers {
                let maskedValue = key.lowercased() == "authorization" ? 
                    (value.count > 10 ? "\(value.prefix(5))...[\(value.count - 10) chars]...\(value.suffix(5))" : "***") : 
                    value
                print("  - \(key): \(maskedValue)")
                request.setValue(value, forHTTPHeaderField: key)
            }
        } else {
            print("⚠️ [AITranscriptionService.processWithAI] No headers provided by AI manager")
        }
        
        // Add request body
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            request.httpBody = jsonData
            print("📦 [AITranscriptionService.processWithAI] Request body size: \(jsonData.count) bytes")
            print("  - Model: \(requestBody["model"] ?? "unknown")")
            if let messages = requestBody["messages"] as? [[String: Any]] {
                print("  - Messages: \(messages.count)")
                for (i, msg) in messages.enumerated() {
                    if let role = msg["role"] as? String {
                        if let content = msg["content"] as? String {
                            print("    \(i+1). \(role): \(content.count > 50 ? "\(content.prefix(50))... [\(content.count) chars]" : content)")
                        }
                    }
                }
            }
        } catch {
            print("❌ [AITranscriptionService.processWithAI] Failed to serialize request body: \(error)")
            throw error
        }
        
        // Make the API call
        print("🚀 [AITranscriptionService.processWithAI] Sending request to \(endpoint)")
        let requestTime = Date()
        
        let (data, response) = try await URLSession.shared.data(for: request)
        let responseTime = Date().timeIntervalSince(requestTime)
        print("⏱️ [AITranscriptionService.processWithAI] Response received in \(String(format: "%.2f", responseTime)) seconds")
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [AITranscriptionService.processWithAI] Invalid HTTP response")
            throw AITranscriptionError.apiRequestFailed
        }
        
        print("📊 [AITranscriptionService.processWithAI] Response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode != 200 {
            // Log error response
            let errorString = String(data: data, encoding: .utf8) ?? "Unable to decode error response"
            print("❌ [AITranscriptionService.processWithAI] API request failed with status \(httpResponse.statusCode)")
            print("  Error response: \(errorString)")
            throw AITranscriptionError.apiRequestFailed
        }
        
        // Parse the response
        do {
            let jsonObj = try JSONSerialization.jsonObject(with: data)
            print("📝 [AITranscriptionService.processWithAI] Parsing JSON response")
            
            guard let json = jsonObj as? [String: Any] else {
                print("❌ [AITranscriptionService.processWithAI] Invalid JSON response")
                throw AITranscriptionError.invalidResponse
            }
            
            // Check for error message in response
            if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
                print("❌ [AITranscriptionService.processWithAI] API returned error: \(message)")
                throw AITranscriptionError.apiRequestFailed
            }
            
            guard let choices = json["choices"] as? [[String: Any]] else {
                print("❌ [AITranscriptionService.processWithAI] No 'choices' field in response")
                
                // Print the actual response data for debugging
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📄 [AITranscriptionService.processWithAI] Raw response: \(jsonString.prefix(300))...")
                }
                
                throw AITranscriptionError.invalidResponse
            }
            
            print("✅ [AITranscriptionService.processWithAI] Found \(choices.count) choices in response")
            
            guard let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                print("❌ [AITranscriptionService.processWithAI] Missing required fields in response")
                throw AITranscriptionError.invalidResponse
            }
            
            // Extract token usage information if available
            if let usage = json["usage"] as? [String: Any],
               let inputTokens = usage["prompt_tokens"] as? Int,
               let outputTokens = usage["completion_tokens"] as? Int {
                print("📊 [AITranscriptionService.processWithAI] Token usage - Input: \(inputTokens), Output: \(outputTokens)")
                // Update token metrics for the active configuration
                await updateTokenMetrics(inputTokens: inputTokens, outputTokens: outputTokens)
            } else {
                print("⚠️ [AITranscriptionService.processWithAI] No token usage information available")
            }
            
            let result = content.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            print("✅ [AITranscriptionService.processWithAI] Successfully extracted content: \(result.count) characters")
            
            return result
        } catch {
            print("❌ [AITranscriptionService.processWithAI] Error parsing response: \(error)")
            throw error
        }
    }
    
    // MARK: - Helper Functions
    
    /// Update token metrics for the active configuration
    private func updateTokenMetrics(inputTokens: Int, outputTokens: Int) async {
        await MainActor.run {
            guard let config = aiManager.activeConfiguration else { return }
            
            // Update the configuration's token counts
            config.totalInputTokens += Int64(inputTokens)
            config.totalOutputTokens += Int64(outputTokens)
            config.totalRequests += 1
            config.lastUsedAt = Date()
            
            // Save the context
            if let context = config.managedObjectContext {
                do {
                    try context.save()
                } catch {
                    // Failed to save token metrics
                }
            }
        }
    }
    
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
    
    // MARK: - Audio Analysis
    
    /// Analyze an audio file and generate a detailed markdown report
    func analyzeAudioFile(audioURL: URL, transcription: Transcription?) async throws -> String {
        print("🔍 [AITranscriptionService.analyzeAudioFile] Starting audio analysis")
        
        // Check active configuration
        guard let config = aiManager.activeConfiguration else {
            print("❌ [AITranscriptionService.analyzeAudioFile] No active AI configuration found")
            throw AITranscriptionError.noActiveConfiguration
        }
        
        // Verify configuration validity with detailed logging
        print("📋 [AITranscriptionService.analyzeAudioFile] Checking AI configuration:")
        print("  - Vendor: \(config.aiVendor?.rawValue ?? "none")")
        print("  - Endpoint: \(config.apiEndpoint ?? "none")")
        print("  - API Key: \(config.apiKey != nil ? "Set (\(config.apiKey!.count) chars)" : "Not set")")
        print("  - Model: \(config.modelIdentifier ?? "none")")
        print("  - isValid: \(config.isValid)")
        
        if !config.isValid {
            print("❌ [AITranscriptionService.analyzeAudioFile] Invalid AI configuration")
            throw AITranscriptionError.invalidConfiguration
        }
        
        isProcessing = true
        processingProgress = 0.0
        
        defer {
            isProcessing = false
            processingProgress = 1.0
        }
        
        // Read the audio file
        if !FileManager.default.fileExists(atPath: audioURL.path) {
            print("❌ [AITranscriptionService.analyzeAudioFile] Audio file not found at path: \(audioURL.path)")
            
            // Try to find the file using FilePathUtility
            if let foundURL = try? FilePathUtility.findAudioFile(with: audioURL.lastPathComponent) {
                print("✅ [AITranscriptionService.analyzeAudioFile] Found audio file using FilePathUtility at: \(foundURL.path)")
                return try await analyzeAudioFileAtPath(foundURL, transcription: transcription)
            }
            
            // Check if path is relative and try to find with document directory
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            if let documentsDir = documentsDirectory {
                let fullPath = documentsDir.appendingPathComponent(audioURL.lastPathComponent)
                print("🔍 [AITranscriptionService.analyzeAudioFile] Trying alternative path: \(fullPath.path)")
                
                if FileManager.default.fileExists(atPath: fullPath.path) {
                    print("✅ [AITranscriptionService.analyzeAudioFile] Found audio file at alternative path")
                    return try await analyzeAudioFileAtPath(fullPath, transcription: transcription)
                }
                
                // Also check sandbox container directory
                let containerPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                if let containerDir = containerPath {
                    let alternativePath = containerDir.appendingPathComponent(audioURL.lastPathComponent)
                    print("🔍 [AITranscriptionService.analyzeAudioFile] Trying container path: \(alternativePath.path)")
                    
                    if FileManager.default.fileExists(atPath: alternativePath.path) {
                        print("✅ [AITranscriptionService.analyzeAudioFile] Found audio file in container directory")
                        return try await analyzeAudioFileAtPath(alternativePath, transcription: transcription)
                    }
                }
            }
            
            throw AITranscriptionError.invalidInput("Audio file not found at path: \(audioURL.path)")
        }
        
        return try await analyzeAudioFileAtPath(audioURL, transcription: transcription)
    }
    
    /// Helper method to analyze an audio file at a specific path
    private func analyzeAudioFileAtPath(_ audioURL: URL, transcription: Transcription?) async throws -> String {
        print("🔍 [AITranscriptionService.analyzeAudioFileAtPath] Processing audio at: \(audioURL.path)")
        
        // Validate configuration a second time
        guard let config = aiManager.activeConfiguration, config.isValid else {
            throw AITranscriptionError.noActiveConfiguration
        }
        
        // Verify the file exists one more time
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw AITranscriptionError.invalidInput("Audio file still not found at fixed path: \(audioURL.path)")
        }
        
        // Get audio duration
        let asset = AVURLAsset(url: audioURL)
        let duration = try await asset.load(.duration)
        let durationInSeconds = CMTimeGetSeconds(duration)
        
        // Get file size
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: audioURL.path)
        let fileSize = fileAttributes[.size] as? Int64 ?? 0
        let fileSizeInMB = Double(fileSize) / (1024 * 1024)
        
        print("📊 [AITranscriptionService.analyzeAudioFileAtPath] Audio file details:")
        print("  - Duration: \(Int(durationInSeconds)) seconds (\(Int(durationInSeconds/60)) minutes)")
        print("  - Size: \(String(format: "%.2f", fileSizeInMB)) MB")
        
        // Get the audio analysis prompt - first try to get a custom one from the config
        var promptTemplate = config.audioAnalysisPrompt
        print("🔍 [AITranscriptionService.analyzeAudioFileAtPath] Checking for prompt template")
        print("  - Custom prompt from config: \(promptTemplate != nil ? "Found (\(promptTemplate!.count) chars)" : "Not found")")
        
        // If no custom prompt in config, check for default prompt in database
        if promptTemplate == nil {
            print("🔍 [AITranscriptionService.analyzeAudioFileAtPath] Looking for default prompt in database")
            let context = PersistenceController.shared.container.viewContext
            if let defaultPrompt = AIPrompt.fetchDefault(for: .audioAnalysis, in: context) {
                promptTemplate = defaultPrompt.content
                print("✅ [AITranscriptionService.analyzeAudioFileAtPath] Found default prompt: '\(defaultPrompt.name ?? "Unnamed")' (\(defaultPrompt.content?.count ?? 0) chars)")
            } else {
                print("⚠️ [AITranscriptionService.analyzeAudioFileAtPath] No default prompt found in database")
            }
        }
        
        // If still no prompt, use hardcoded default
        if promptTemplate == nil {
            print("⚠️ [AITranscriptionService.analyzeAudioFileAtPath] Using hardcoded default prompt")
            promptTemplate = """
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
            print("✅ [AITranscriptionService.analyzeAudioFileAtPath] Hardcoded default prompt set (\(promptTemplate!.count) chars)")
        }
        
        // Add audio details to the prompt
        let prompt = """
        \(promptTemplate!)
        
        Audio Details:
        - Duration: \(Int(durationInSeconds)) seconds (\(Int(durationInSeconds/60)) minutes)
        - File Size: \(String(format: "%.2f", fileSizeInMB)) MB
        """
        
        // If we have a transcription, include it in the analysis
        var contentToAnalyze = prompt
        
        if let transcription = transcription {
            print("📝 [AITranscriptionService.analyzeAudioFileAtPath] Adding transcription to analysis")
            if let rawText = transcription.rawText, !rawText.isEmpty {
                contentToAnalyze += "\n\nTranscription:\n\(rawText)"
                print("  - Using raw transcription text (\(rawText.count) chars)")
            } else if let text = transcription.text, !text.isEmpty {
                contentToAnalyze += "\n\nTranscription:\n\(text)"
                print("  - Using enhanced transcription text (\(text.count) chars)")
            } else {
                print("⚠️ [AITranscriptionService.analyzeAudioFileAtPath] No transcription text available")
            }
        } else {
            print("⚠️ [AITranscriptionService.analyzeAudioFileAtPath] No transcription object available")
        }
        
        // Process with AI
        let systemPrompt = "You are an expert audio analyst. Analyze the provided audio information and generate a comprehensive markdown report."
        print("🚀 [AITranscriptionService.analyzeAudioFileAtPath] Sending request to AI service")
        return try await processWithAI(prompt: contentToAnalyze, systemPrompt: systemPrompt)
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
    case invalidInput(String)
    
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
        case .invalidInput(let message):
            return message
        }
    }
}