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
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
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
    
    // MARK: - Private Properties
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    private var processingQueue = DispatchQueue(label: "com.voicejournal.speechrecognition", qos: .userInitiated)
    
    // MARK: - Initialization
    
    nonisolated init() {
        // Move any main actor work to a separate method
        Task {
            await self.checkAvailability()
        }
    }
    
    // MARK: - Public Methods
    
    /// Check if speech recognition is available on this device
    func checkAvailability() {
        isAvailable = speechRecognizer?.isAvailable ?? false
        
        if !isAvailable {
            state = .unavailable
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
    
    /// Start real-time speech recognition from the microphone
    func startLiveRecognition() async throws {
        // Check authorization
        let permission = checkAuthorization()
        guard permission == .granted else {
            throw SpeechRecognitionError.authorizationFailed
        }
        
        // Check availability
        guard speechRecognizer?.isAvailable == true else {
            throw SpeechRecognitionError.noRecognitionAvailable
        }
        
        // Stop any ongoing recognition
        stopRecognition()
        
        // Reset transcription
        transcription = ""
        interimTranscription = ""
        progress = 0.0
        
        // Create audio engine if needed
        if audioEngine == nil {
            audioEngine = AVAudioEngine()
        }
        
        guard let audioEngine = audioEngine else {
            throw SpeechRecognitionError.recognitionFailed
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
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
                    self.state = .error(error)
                }
                return
            }
            
            if let result = result {
                Task { @MainActor in
                    // Update interim transcription with partial results
                    self.interimTranscription = result.bestTranscription.formattedString
                    
                    // If final result, update the main transcription
                    if result.isFinal {
                        self.transcription += result.bestTranscription.formattedString + " "
                    }
                    
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
    // Check authorization
    let permission = checkAuthorization()
    guard permission == .granted else {
        throw SpeechRecognitionError.authorizationFailed
    }
    
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
                        self.extractTimingData(from: result.bestTranscription)
                        
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
        // Stop audio engine
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        
        // Stop recognition task
        recognitionTask?.cancel()
        recognitionTask?.finish()
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

/// Extract timing data from a transcription
private func extractTimingData(from transcription: SFTranscription) {
    var segments: [TranscriptionSegment] = []
    
    // Process each segment in the transcription
    for i in 0..<transcription.segments.count {
        let segment = transcription.segments[i]
        
        // Create a segment with timing information
        let transcriptionSegment = TranscriptionSegment(
            text: segment.substring,
            startTime: segment.timestamp,
            endTime: segment.timestamp + segment.duration,
            range: segment.substringRange
        )
        
        segments.append(transcriptionSegment)
    }
    
    // Store the timing data
    timingData = segments
    
    // Log the timing data for debugging
    print("DEBUG: Extracted \(segments.count) timing segments from transcription")
}

/// Get the timing data as a JSON string
func getTimingDataJSON() -> String? {
    guard !timingData.isEmpty else { return nil }
    
    do {
        let encoder = JSONEncoder()
        let data = try encoder.encode(timingData)
        return String(data: data, encoding: .utf8)
    } catch {
        print("ERROR: Failed to encode timing data to JSON: \(error.localizedDescription)")
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
