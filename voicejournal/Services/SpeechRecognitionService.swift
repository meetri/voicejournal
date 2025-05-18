//
//  SpeechRecognitionService.swift
//  voicejournal
//
//  Created on 4/27/25.
//

import Foundation
import Speech
import Combine
import AVFoundation

/// Enum representing the possible states of speech recognition
enum SpeechRecognitionState {
    case unavailable
    case notAuthorized
    case ready
    case recognizing
    case paused
    case finished
    case error(Error)
}

// Add Equatable conformance to SpeechRecognitionState
extension SpeechRecognitionState: Equatable {
    static func == (lhs: SpeechRecognitionState, rhs: SpeechRecognitionState) -> Bool {
        switch (lhs, rhs) {
        case (.unavailable, .unavailable),
             (.notAuthorized, .notAuthorized),
             (.ready, .ready),
             (.recognizing, .recognizing),
             (.paused, .paused),
             (.finished, .finished):
            return true
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

/// Enum representing speech recognition permission states
enum SpeechRecognitionPermission {
    case granted
    case denied
    case restricted
    case notDetermined
}

/// Enum representing errors that can occur during speech recognition
enum SpeechRecognitionError: Error {
    case authorizationFailed
    case recognitionFailed
    case audioFormatNotSupported
    case noRecognitionAvailable
    case fileNotFound
    case languageNotSupported
    case languageNotAvailable
    case languageModelDownloadRequired
    case languageModelDownloadFailed
    case resourceLimitReached
    case unknown(Error)
    
    var localizedDescription: String {
        switch self {
        case .authorizationFailed:
            return "Speech recognition authorization failed"
        case .recognitionFailed:
            return "Speech recognition failed"
        case .audioFormatNotSupported:
            return "Audio format not supported for speech recognition"
        case .noRecognitionAvailable:
            return "Speech recognition is not available on this device"
        case .fileNotFound:
            return "Audio file not found"
        case .languageNotSupported:
            return "This language is not supported for transcription"
        case .languageNotAvailable:
            return "This language is not available on your device"
        case .languageModelDownloadRequired:
            return "Language model needs to be downloaded. Please connect to Wi-Fi and try again"
        case .languageModelDownloadFailed:
            return "Failed to download language model. Please check your connection and try again"
        case .resourceLimitReached:
            return "System resource limit reached. Please try again later"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
    
    /// Create a SpeechRecognitionError from a system error
    static func fromSystemError(_ error: Error) -> SpeechRecognitionError {
        let nsError = error as NSError
        
        // Check for specific error domains and codes
        if nsError.domain == "kAFAssistantErrorDomain" {
            switch nsError.code {
            case 1101:
                // This typically means the language model isn't available or needs to be downloaded
                return .languageModelDownloadRequired
            case 1102:
                return .languageModelDownloadFailed
            case 1103, 1104:
                return .resourceLimitReached
            default:
                break
            }
        }
        
        return .unknown(error)
    }
}

/// Enum representing the status of a language for speech recognition
enum LanguageStatus {
    case unknown
    case unavailable
    case downloading
    case available
    
    var description: String {
        switch self {
        case .unknown:
            return "Unknown"
        case .unavailable:
            return "Unavailable"
        case .downloading:
            return "Downloading..."
        case .available:
            return "Available"
        }
    }
}

/// Service responsible for handling speech recognition functionality
@MainActor
class SpeechRecognitionService: ObservableObject {
    // MARK: - Published Properties
    
    /// Current state of speech recognition
    @Published private(set) var state: SpeechRecognitionState = .ready
    
    /// Current transcription text
    @Published private(set) var transcription: String = ""

    /// Interim transcription text (not finalized)
    @Published private(set) var interimTranscription: String = ""

    /// Recognition progress (0.0 to 1.0)
    @Published private(set) var progress: Float = 0.0

    /// Timing data for transcription segments
    @Published private(set) var timingData: [TranscriptionSegment] = []
    
    /// Whether speech recognition is available on this device
    @Published private(set) var isAvailable: Bool = false
    
    /// Current status of the selected language
    @Published private(set) var languageStatus: LanguageStatus = .unknown
    
    /// Error message if there's an issue with speech recognition
    @Published private(set) var errorMessage: String = ""
    
    // MARK: - Properties
    
    /// The current locale used for speech recognition
    private(set) var currentLocale: Locale = Locale(identifier: "en-US")
    
    // MARK: - Private Properties
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    private var processingQueue = DispatchQueue(label: "com.voicejournal.speechrecognition", qos: .userInitiated)
    
    // MARK: - Initialization
    
    nonisolated init(locale: Locale = Locale(identifier: "en-US")) {
        // Move any main actor work to a separate method
        Task { @MainActor in
            print("[SpeechRecognition] Initializing with locale: \(locale.identifier)")
            self.currentLocale = locale
            self.speechRecognizer = SFSpeechRecognizer(locale: locale)
            print("[SpeechRecognition] Created recognizer: \(self.speechRecognizer != nil ? "Success" : "Failed")")
            if let recognizer = self.speechRecognizer {
                print("[SpeechRecognition] Recognizer locale: \(recognizer.locale.identifier)")
            }
            await self.checkAvailability()
        }
    }
    
    // MARK: - Public Methods
    
    /// Check if speech recognition is available on this device
    func checkAvailability() {
        // Make sure the recognizer is initialized with the current locale
        if speechRecognizer == nil {
            speechRecognizer = SFSpeechRecognizer(locale: currentLocale)
        }
        
        isAvailable = speechRecognizer?.isAvailable ?? false
        
        if !isAvailable {
            state = .unavailable
        }
    }
    
    /// Set the locale for speech recognition
    func setRecognitionLocale(_ locale: Locale) {
        print("[SpeechRecognition] Setting locale to: \(locale.identifier)")
        print("[SpeechRecognition] Previous locale was: \(currentLocale.identifier)")
        
        currentLocale = locale
        // Update the speech recognizer with the new locale
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        
        print("[SpeechRecognition] Created recognizer: \(speechRecognizer != nil ? "Success" : "Failed")")
        if let recognizer = speechRecognizer {
            print("[SpeechRecognition] Recognizer locale: \(recognizer.locale.identifier)")
            print("[SpeechRecognition] Recognizer available: \(recognizer.isAvailable)")
        }
        
        checkAvailability()
    }
    
    /// Get available locales for speech recognition
    static func getAvailableLocales() -> [Locale] {
        return SFSpeechRecognizer.supportedLocales().sorted { 
            $0.localizedString(forIdentifier: $0.identifier) ?? "" < 
            $1.localizedString(forIdentifier: $1.identifier) ?? "" 
        }
    }
    
    /// Request speech recognition authorization
    func requestAuthorization() async -> SpeechRecognitionPermission {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                switch status {
                case .authorized:
                    Task { @MainActor in
                        self.state = .ready
                    }
                    continuation.resume(returning: .granted)
                case .denied:
                    Task { @MainActor in
                        self.state = .notAuthorized
                    }
                    continuation.resume(returning: .denied)
                case .restricted:
                    Task { @MainActor in
                        self.state = .notAuthorized
                    }
                    continuation.resume(returning: .restricted)
                case .notDetermined:
                    continuation.resume(returning: .notDetermined)
                @unknown default:
                    continuation.resume(returning: .notDetermined)
                }
            }
        }
    }
    
    /// Check current speech recognition authorization status
    func checkAuthorization() -> SpeechRecognitionPermission {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return .granted
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }
    
    /// Check the status of a language for speech recognition
    func checkLanguageStatus(locale: Locale) -> LanguageStatus {
        // Create a speech recognizer for the locale
        let recognizer = SFSpeechRecognizer(locale: locale)
        
        // Check if the recognizer is available
        if let recognizer = recognizer {
            if recognizer.isAvailable {
                return .available
            } else {
                // Check if the locale is supported
                let supportedLocales = SFSpeechRecognizer.supportedLocales()
                if supportedLocales.contains(where: { $0.identifier == locale.identifier }) {
                    // Supported but not available - likely downloading or needs download
                    return .downloading
                } else {
                    // Not supported at all
                    return .unavailable
                }
            }
        } else {
            // If the recognizer is nil, the language might not be supported
            return .unavailable
        }
    }
    
    /// Update the language status for the current locale
    func updateLanguageStatus() {
        languageStatus = checkLanguageStatus(locale: currentLocale)
        
        // Log the language status for debugging
        print("[SpeechRecognition] Language status for \(currentLocale.identifier): \(languageStatus.description)")
        
        // Additional diagnostics
        if languageStatus != .available {
            let supportedLocales = SFSpeechRecognizer.supportedLocales()
            let isSupported = supportedLocales.contains(where: { $0.identifier == currentLocale.identifier })
            print("[SpeechRecognition] Locale \(currentLocale.identifier) is \(isSupported ? "supported" : "not supported")")
            print("[SpeechRecognition] Total supported locales: \(supportedLocales.count)")
        }
    }
    
    /// Start real-time speech recognition from the microphone
    func startLiveRecognition() async throws {
        print("[SpeechRecognition] Starting live recognition with locale: \(currentLocale.identifier)")
        
        // Reset error message
        errorMessage = ""
        
        // Check authorization
        let permission = checkAuthorization()
        guard permission == .granted else {
            errorMessage = SpeechRecognitionError.authorizationFailed.localizedDescription
            throw SpeechRecognitionError.authorizationFailed
        }
        
        // Ensure recognizer is using the current locale
        if speechRecognizer == nil || speechRecognizer?.locale != currentLocale {
            print("[SpeechRecognition] Creating new recognizer for locale: \(currentLocale.identifier)")
            speechRecognizer = SFSpeechRecognizer(locale: currentLocale)
        }
        
        print("[SpeechRecognition] Current recognizer locale: \(speechRecognizer?.locale.identifier ?? "nil")")
        
        // Update and check language status
        updateLanguageStatus()
        
        // Check availability
        guard speechRecognizer?.isAvailable == true else {
            print("[SpeechRecognition] Speech recognizer not available for locale: \(currentLocale.identifier)")
            
            // Check if it's a language model issue
            if let recognizer = speechRecognizer {
                print("[SpeechRecognition] Recognizer exists but not available")
                print("[SpeechRecognition] Supported locales: \(SFSpeechRecognizer.supportedLocales().map { $0.identifier })")
                
                // Update language status based on availability
                if languageStatus == .downloading {
                    errorMessage = "Language model is downloading. Please try again in a moment."
                    throw SpeechRecognitionError.languageModelDownloadRequired
                } else {
                    languageStatus = .unavailable
                    errorMessage = SpeechRecognitionError.languageNotAvailable.localizedDescription
                    state = .error(SpeechRecognitionError.languageNotAvailable)
                    throw SpeechRecognitionError.languageNotAvailable
                }
            } else {
                errorMessage = SpeechRecognitionError.noRecognitionAvailable.localizedDescription
                state = .unavailable
                throw SpeechRecognitionError.noRecognitionAvailable
            }
        }
        
        // Stop any ongoing recognition
        stopRecognition()
        
        // Reset transcription and timing data
        transcription = ""
        interimTranscription = ""
        progress = 0.0
        timingData = []
        
        // Create audio engine if needed
        if audioEngine == nil {
            audioEngine = AVAudioEngine()
        }
        
        guard let audioEngine = audioEngine else {
            errorMessage = SpeechRecognitionError.recognitionFailed.localizedDescription
            throw SpeechRecognitionError.recognitionFailed
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            errorMessage = SpeechRecognitionError.recognitionFailed.localizedDescription
            throw SpeechRecognitionError.recognitionFailed
        }
        
        // Configure request
        recognitionRequest.shouldReportPartialResults = true
        
        // Get audio input node
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .default)
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                Task { @MainActor in
                    let nsError = error as NSError
                    
                    // Check if it's the expected "No speech detected" timeout (code 1110)
                    if nsError.code == 1110 && nsError.domain == "kAFAssistantErrorDomain" {
                        print("[SpeechRecognition] Recognition ended with expected timeout - processing complete")
                        // This is normal when audio ends and recognition times out
                        self.state = .finished
                        // Don't treat this as an error - we already have our results
                        return
                    }
                    
                    print("[SpeechRecognition] Recognition error: \(error)")
                    print("[SpeechRecognition] Error domain: \(nsError.domain), code: \(nsError.code)")
                    
                    // Convert the error to a more specific SpeechRecognitionError
                    let specificError = SpeechRecognitionError.fromSystemError(error)
                    self.errorMessage = specificError.localizedDescription
                    self.state = .error(specificError)
                    
                    // If it's a language model issue, update the language status
                    if case .languageModelDownloadRequired = specificError {
                        self.languageStatus = .downloading
                    } else if case .languageNotAvailable = specificError {
                        self.languageStatus = .unavailable
                    }
                    
                    // Stop the recognition
                    self.stopRecognition()
                }
                return
            }
            
            if let result = result {
                Task { @MainActor in
                    print("[SpeechRecognition] Recognition result - isFinal: \(result.isFinal), text: '\(result.bestTranscription.formattedString)'")
                    
                    // Update interim transcription with partial results
                    self.interimTranscription = result.bestTranscription.formattedString
                    print("[SpeechRecognition] Updated interim transcription: '\(self.interimTranscription)'")
                    
                    // For both interim and final results, extract timing data
                    // This ensures we capture timing even if we never get final results
                    let previousLength = self.transcription.count
                    
                    // If final result, update the main transcription
                    if result.isFinal {
                        self.transcription += result.bestTranscription.formattedString + " "
                        print("[SpeechRecognition] Updated final transcription: '\(self.transcription)'")
                    }
                    
                    // Extract timing data for all results (both interim and final)
                    self.extractTimingDataForCurrentState(from: result.bestTranscription, transcriptionOffset: previousLength, isFinal: result.isFinal)
                    print("[SpeechRecognition] Total timing segments: \(self.timingData.count)")
                    
                    // Update progress
                    if self.recognitionRequest != nil {
                        // This is an approximation as there's no direct way to get progress
                        self.progress = min(1.0, Float(self.transcription.count) / 100.0)
                    }
                }
            }
        }
        
        state = .recognizing
    }
    
    /// Start speech recognition from an audio file
    func recognizeFromFile(url: URL) async throws -> String {
        print("[SpeechRecognition] Recognizing file with locale: \(currentLocale.identifier)")
        
        // Check authorization
        let permission = checkAuthorization()
        guard permission == .granted else {
            throw SpeechRecognitionError.authorizationFailed
        }
        
        // Ensure recognizer is using the current locale
        if speechRecognizer == nil || speechRecognizer?.locale != currentLocale {
            print("[SpeechRecognition] Creating new recognizer for file with locale: \(currentLocale.identifier)")
            speechRecognizer = SFSpeechRecognizer(locale: currentLocale)
        }
        
        print("[SpeechRecognition] Recognizer locale for file: \(speechRecognizer?.locale.identifier ?? "nil")")
        
        // Check availability
        guard speechRecognizer?.isAvailable == true else {
            throw SpeechRecognitionError.noRecognitionAvailable
        }
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw SpeechRecognitionError.fileNotFound
        }
        
        // Reset transcription
        transcription = ""
        interimTranscription = ""
        progress = 0.0
        timingData = []
        
        state = .recognizing
        
        // Create recognition request
        let recognitionRequest = SFSpeechURLRecognitionRequest(url: url)
        
        // Configure request
        recognitionRequest.shouldReportPartialResults = true
        
        // Start recognition task
        return try await withCheckedThrowingContinuation { continuation in
            self.recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self = self else {
                    continuation.resume(throwing: SpeechRecognitionError.recognitionFailed)
                    return
                }
                
                if let error = error {
                    Task { @MainActor in
                        self.state = .error(error)
                    }
                    continuation.resume(throwing: SpeechRecognitionError.unknown(error))
                    return
                }
                
                if let result = result {
                    Task { @MainActor in
                        // Update interim transcription with partial results
                        self.interimTranscription = result.bestTranscription.formattedString
                        
                        // Update progress
                        self.progress = result.isFinal ? 1.0 : min(0.99, Float(result.bestTranscription.formattedString.count) / 100.0)
                        
                        // If final result, update the main transcription and complete
                        if result.isFinal {
                            self.transcription = result.bestTranscription.formattedString
                            
                            // Extract timing data from transcription segments
                            Task { @MainActor in
                                self.extractTimingData(from: result.bestTranscription)
                            }
                            
                            self.state = .finished
                            continuation.resume(returning: result.bestTranscription.formattedString)
                        }
                    }
                }
            }
        }
    }
    
    /// Pause speech recognition
    func pauseRecognition() {
        if case .recognizing = state {
            audioEngine?.pause()
            state = .paused
        }
    }
    
    /// Resume speech recognition
    func resumeRecognition() throws {
        if case .paused = state {
            try audioEngine?.start()
            state = .recognizing
        }
    }
    
    /// Stop speech recognition
    func stopRecognition() {
        // Stop audio engine first
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        
        // Finish the recognition request to trigger final results
        recognitionRequest?.endAudio()
        
        // Give the recognizer a moment to process final results
        // We'll use a completion handler for when recognition is truly done
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.finalizeRecognition()
        }
    }
    
    /// Finalize recognition after giving time for final results
    private func finalizeRecognition() {
        // Cancel and clean up recognition task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Clean up recognition request
        recognitionRequest = nil
        
        if state == .recognizing || state == .paused {
            state = .finished
        }
    }
    
    /// Reset the service
    func reset() {
        stopRecognition()
        transcription = ""
        interimTranscription = ""
        progress = 0.0
        timingData = []
        state = .ready
    }
    
    // MARK: - Helper Methods

    /// Get the combined transcription (final + interim)
    var currentTranscription: String {
        if interimTranscription.isEmpty {
            return transcription
        } else {
            return transcription + interimTranscription
        }
    }

    /// Extract timing data for the current recognition state
    private func extractTimingDataForCurrentState(from transcription: SFTranscription, transcriptionOffset: Int, isFinal: Bool) {
        // For interim results, we'll store them temporarily and replace them when we get the final result
        // This handles the case where we never get final results due to errors
        
        print("[SpeechRecognition] Extracting timing data - isFinal: \(isFinal), transcriptionOffset: \(transcriptionOffset)")
        print("[SpeechRecognition] Transcription text: '\(transcription.formattedString)'")
        print("[SpeechRecognition] Number of segments: \(transcription.segments.count)")
        
        var newTimingData: [TranscriptionSegment] = []
        
        // Process all segments in the current transcription
        for (index, segment) in transcription.segments.enumerated() {
            let segmentText = segment.substring
            let timestamp = segment.timestamp
            let duration = segment.duration
            let nsRange = segment.substringRange // Use the provided range from Apple
            
            print("[SpeechRecognition] Processing segment \(index): '\(segmentText)'")
            print("[SpeechRecognition]   - timestamp: \(timestamp), duration: \(duration)")
            print("[SpeechRecognition]   - range: \(nsRange)")
            
            // For interim results, Apple often provides unreliable timing (0.011s durations)
            // We'll adjust this to be more reasonable
            var adjustedDuration = duration
            if !isFinal && duration < 0.05 {
                adjustedDuration = 0.1 // Minimum 100ms per segment for interim results
            }
            
            // Adjust timestamp if needed to ensure sequential ordering
            var adjustedTimestamp = timestamp
            if let lastSegment = newTimingData.last {
                // Ensure no overlap with previous segment
                if adjustedTimestamp < lastSegment.endTime {
                    adjustedTimestamp = lastSegment.endTime
                }
            }
            
            let transcriptionSegment = TranscriptionSegment(
                text: segmentText,
                startTime: adjustedTimestamp,
                endTime: adjustedTimestamp + adjustedDuration,
                range: nsRange,
                locale: currentLocale.identifier
            )
            
            newTimingData.append(transcriptionSegment)
            print("[SpeechRecognition] Added segment: '\(segmentText)' at \(adjustedTimestamp)-\(adjustedTimestamp + adjustedDuration)s")
        }
        
        // Replace existing timing data with cleaned version
        if !isFinal {
            // For interim results, replace all timing data
            self.timingData = self.cleanupOverlappingSegments(newTimingData)
        } else {
            // For final results, use the accumulation method
            print("[SpeechRecognition] Using accumulation method for final results")
            self.extractAndAccumulateTimingData(from: transcription, withOffset: transcriptionOffset)
        }
        
        print("[SpeechRecognition] Total timing segments: \(self.timingData.count)")
        if let first = self.timingData.first, let last = self.timingData.last {
            print("[SpeechRecognition] Duration range: \(first.startTime) - \(last.endTime) seconds")
        }
        
        // Validate segment coverage
        if isFinal {
            validateSegmentCoverage(for: transcription.formattedString)
        }
    }
    
    /// Validate that segments cover the entire transcription without gaps
    private func validateSegmentCoverage(for fullText: String) {
        guard !timingData.isEmpty else { return }
        
        // Sort segments by location
        let sortedSegments = timingData.sorted { $0.textRange.location < $1.textRange.location }
        
        // Check for gaps between segments
        for i in 0..<(sortedSegments.count - 1) {
            let currentSegment = sortedSegments[i]
            let nextSegment = sortedSegments[i + 1]
            
            let currentEnd = currentSegment.textRange.location + currentSegment.textRange.length
            let nextStart = nextSegment.textRange.location
            
            if nextStart > currentEnd {
                let gapLength = nextStart - currentEnd
                let gapStart = fullText.index(fullText.startIndex, offsetBy: currentEnd)
                let gapEnd = fullText.index(fullText.startIndex, offsetBy: nextStart)
                let gapText = String(fullText[gapStart..<gapEnd])
                
                print("[SpeechRecognition] WARNING: Gap found between segments")
                print("[SpeechRecognition]   - Gap position: \(currentEnd)-\(nextStart) (length: \(gapLength))")
                print("[SpeechRecognition]   - Gap text: '\(gapText)'")
                print("[SpeechRecognition]   - Between: '\(currentSegment.text)' and '\(nextSegment.text)'")
            }
        }
        
        // Check if first segment starts at beginning
        if let firstSegment = sortedSegments.first, firstSegment.textRange.location > 0 {
            let missedText = String(fullText.prefix(firstSegment.textRange.location))
            print("[SpeechRecognition] WARNING: Text before first segment: '\(missedText)'")
        }
        
        // Check if last segment ends at the end
        if let lastSegment = sortedSegments.last {
            let lastEnd = lastSegment.textRange.location + lastSegment.textRange.length
            if lastEnd < fullText.count {
                let missedText = String(fullText.suffix(fullText.count - lastEnd))
                print("[SpeechRecognition] WARNING: Text after last segment: '\(missedText)'")
            }
        }
    }
    
    /// Clean up overlapping segments by removing duplicates and substrings
    private func cleanupOverlappingSegments(_ segments: [TranscriptionSegment]) -> [TranscriptionSegment] {
        var cleanedSegments: [TranscriptionSegment] = []
        
        for segment in segments {
            // Check if this segment represents a word evolution at the same position
            // (e.g., "let" -> "let's" or "work" -> "work or")
            let isEvolution = cleanedSegments.contains { existing in
                // Same starting position and one is a prefix of the other
                existing.textRange.location == segment.textRange.location &&
                (segment.text.hasPrefix(existing.text) || existing.text.hasPrefix(segment.text)) &&
                segment.text != existing.text
            }
            
            if isEvolution {
                // Remove the shorter version and keep the longer evolution
                cleanedSegments.removeAll { existing in
                    existing.textRange.location == segment.textRange.location &&
                    existing.text != segment.text &&
                    (segment.text.hasPrefix(existing.text) || existing.text.hasPrefix(segment.text))
                }
            }
            
            // Always add the current segment if not already present
            if !cleanedSegments.contains(where: { $0.text == segment.text && $0.textRange.location == segment.textRange.location }) {
                cleanedSegments.append(segment)
            }
        }
        
        // Sort by text range location to ensure proper ordering
        return cleanedSegments.sorted { $0.textRange.location < $1.textRange.location }
    }
    
    /// Extract timing data from a transcription and accumulate it with existing data
    private func extractAndAccumulateTimingData(from transcription: SFTranscription, withOffset offset: Int) {
        var newSegments: [TranscriptionSegment] = []
        
        // Get the full transcription text to calculate proper ranges
        let fullText = transcription.formattedString
        
        print("[SpeechRecognition] Extracting and accumulating timing data")
        print("[SpeechRecognition] - Full text: '\(fullText)' with offset \(offset)")
        print("[SpeechRecognition] - Number of segments: \(transcription.segments.count)")
        
        // Track the highest timestamp we already have to ensure continuity
        let highestExistingTime = self.timingData.last?.endTime ?? 0
        print("[SpeechRecognition] Highest existing timestamp: \(highestExistingTime)")
        
        // Process each segment in the transcription
        for i in 0..<transcription.segments.count {
            let segment = transcription.segments[i]
            let segmentText = segment.substring
            let timestamp = segment.timestamp
            let duration = segment.duration
            let originalRange = segment.substringRange // Use the provided range
            
            print("[SpeechRecognition] Processing segment \(i): '\(segmentText)'")
            print("[SpeechRecognition]   - SF timestamp: \(timestamp), duration: \(duration)")
            print("[SpeechRecognition]   - SF segment range: \(originalRange)")
            
            // Only process segments we haven't seen before (based on timestamp)
            if timestamp > highestExistingTime - 0.1 { // small overlap tolerance
                // Check if we already have this exact segment to avoid duplicates
                let isDuplicate = self.timingData.contains { existing in
                    existing.text == segmentText && 
                    abs(existing.startTime - timestamp) < 0.05 // 50ms tolerance
                }
                
                if !isDuplicate {
                    // Adjust the range to account for the offset in the accumulated transcription
                    let adjustedRange = NSRange(location: originalRange.location + offset, length: originalRange.length)
                    
                    print("[SpeechRecognition] Adding new segment: '\(segmentText)' at time \(timestamp)-\(timestamp + duration)s")
                    print("[SpeechRecognition]   - Original range: \(originalRange), adjusted range: \(adjustedRange)")
                    
                    // Create a segment with timing information and locale
                    let transcriptionSegment = TranscriptionSegment(
                        text: segmentText,
                        startTime: timestamp,
                            endTime: timestamp + duration,
                            range: adjustedRange,
                            locale: currentLocale.identifier
                        )
                        
                        newSegments.append(transcriptionSegment)
                    
                } else {
                    print("[SpeechRecognition] Skipping duplicate segment: '\(segmentText)' at \(timestamp)")
                }
            } else {
                print("[SpeechRecognition] Skipping old segment: '\(segmentText)' at \(timestamp) (before \(highestExistingTime))")
            }
        }
        
        // Append new segments to existing timing data
        timingData.append(contentsOf: newSegments)
        print("[SpeechRecognition] Added \(newSegments.count) timing segments, total: \(timingData.count)")
        print("[SpeechRecognition] Full transcription so far: '\(self.transcription)'")
    }
    
    /// Extract timing data from a transcription (used for file recognition)
    private func extractTimingData(from transcription: SFTranscription) {
        var segments: [TranscriptionSegment] = []
        
        // Process each segment in the transcription
        for i in 0..<transcription.segments.count {
            let segment = transcription.segments[i]
            let segmentText = segment.substring
            let nsRange = segment.substringRange // Use the provided range
            
            // Create a segment with timing information and locale
            let transcriptionSegment = TranscriptionSegment(
                text: segmentText,
                startTime: segment.timestamp,
                endTime: segment.timestamp + segment.duration,
                range: nsRange,
                locale: currentLocale.identifier
            )
            
            segments.append(transcriptionSegment)
        }
        
        // Store the timing data
        timingData = segments
        print("[SpeechRecognition] Extracted \(segments.count) timing segments")
    }

    /// Get the timing data as a JSON string
    func getTimingDataJSON() -> String? {
        guard !timingData.isEmpty else {
            print("[SpeechRecognition] No timing data to encode")
            return nil
        }
        
        print("[SpeechRecognition] Encoding \(timingData.count) timing segments")
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(timingData)
            if let json = String(data: data, encoding: .utf8) {
                print("[SpeechRecognition] Encoded timing data: \(json.prefix(200))...")
                return json
            }
            return nil
        } catch {
            print("[SpeechRecognition] Error encoding timing data: \(error)")
            return nil
        }
    }
}

// MARK: - Testing Support

extension SpeechRecognitionService {
    /// Internal method to set state (for testing)
    @MainActor
    internal func setStateForTesting(_ newState: SpeechRecognitionState) {
        state = newState
    }
    
    /// Internal method to set transcription (for testing)
    @MainActor
    internal func setTranscriptionForTesting(_ text: String) {
        transcription = text
    }
    
    /// Internal method to set interim transcription (for testing)
    @MainActor
    internal func setInterimTranscriptionForTesting(_ text: String) {
        interimTranscription = text
    }
    
    /// Internal method to set progress (for testing)
    @MainActor
    internal func setProgressForTesting(_ value: Float) {
        progress = value
    }
    
    /// Internal method to set timing data (for testing)
    @MainActor
    internal func setTimingDataForTesting(_ segments: [TranscriptionSegment]) {
        timingData = segments
    }
}
