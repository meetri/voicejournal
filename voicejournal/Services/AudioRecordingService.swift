//
//  AudioRecordingService.swift
//  voicejournal
//
//  Created on 4/27/25.
//

import Foundation
import AVFoundation
import Combine

/// Enum representing the possible states of the audio recording
enum RecordingState {
    case ready
    case recording
    case paused
    case stopped
    case error(Error)
}

// Add Equatable conformance to RecordingState
extension RecordingState: Equatable {
    static func == (lhs: RecordingState, rhs: RecordingState) -> Bool {
        switch (lhs, rhs) {
        case (.ready, .ready), (.recording, .recording), (.paused, .paused), (.stopped, .stopped):
            return true
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

/// Enum representing recording permission states
enum RecordingPermission {
    case granted
    case denied
    case undetermined
}

/// Enum representing errors that can occur during audio recording
enum AudioRecordingError: Error {
    case audioSessionSetupFailed
    case audioEngineSetupFailed
    case recordingInProgress
    case noRecordingInProgress
    case fileCreationFailed
    case permissionDenied
    case unknown(Error)
    
    var localizedDescription: String {
        switch self {
        case .audioSessionSetupFailed:
            return "Failed to set up audio session"
        case .audioEngineSetupFailed:
            return "Failed to set up audio engine"
        case .recordingInProgress:
            return "Recording is already in progress"
        case .noRecordingInProgress:
            return "No recording is in progress"
        case .fileCreationFailed:
            return "Failed to create audio file"
        case .permissionDenied:
            return "Microphone permission denied"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}

// Add Equatable conformance to AudioRecordingError
extension AudioRecordingError: Equatable {
    static func == (lhs: AudioRecordingError, rhs: AudioRecordingError) -> Bool {
        switch (lhs, rhs) {
        case (.audioSessionSetupFailed, .audioSessionSetupFailed),
             (.audioEngineSetupFailed, .audioEngineSetupFailed),
             (.recordingInProgress, .recordingInProgress),
             (.noRecordingInProgress, .noRecordingInProgress),
             (.fileCreationFailed, .fileCreationFailed),
             (.permissionDenied, .permissionDenied):
            return true
        case (.unknown(let lhsError), .unknown(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

/// Service responsible for handling audio recording functionality
@MainActor
class AudioRecordingService: ObservableObject {
    // MARK: - Published Properties
    
    /// Current state of the recording
    @Published private(set) var state: RecordingState = .ready
    
    /// Current audio level (0.0 to 1.0)
    @Published private(set) var audioLevel: Float = 0.0
    
    /// Duration of the current recording in seconds
    @Published private(set) var duration: TimeInterval = 0.0
    
    /// URL of the recorded audio file
    @Published private(set) var recordingURL: URL?
    
    // MARK: - Private Properties
    
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var audioInputNode: AVAudioInputNode?
    private var audioInputFormat: AVAudioFormat?
    
    private var recordingStartTime: Date?
    private var recordingPausedTime: TimeInterval = 0
    private var durationTimer: Timer?
    private var levelUpdateTimer: Timer?
    
    private let audioSession = AVAudioSession.sharedInstance()
    private let processingQueue = DispatchQueue(label: "com.voicejournal.audioprocessing", qos: .userInitiated)
    
    // Changed from private to internal for testing purposes
    internal var recordingsDirectory: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("Recordings", isDirectory: true)
    }
    
    // MARK: - Initialization
    
    init() {
        createRecordingsDirectoryIfNeeded()
    }
    
    // MARK: - Public Methods
    
    /// Request microphone permission
    func requestPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    /// Check if microphone permission is granted
    func checkPermission() async -> RecordingPermission {
        return await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                // For iOS 17+, map from AVAudioApplication's permission
                switch AVAudioApplication.shared.recordPermission {
                case .granted:
                    continuation.resume(returning: .granted)
                case .denied:
                    continuation.resume(returning: .denied)
                case .undetermined:
                    continuation.resume(returning: .undetermined)
                @unknown default:
                    continuation.resume(returning: .undetermined)
                }
            } else {
                // For iOS versions before 17.0, map from AVAudioSession's permission
                switch AVAudioSession.sharedInstance().recordPermission {
                case .granted:
                    continuation.resume(returning: .granted)
                case .denied:
                    continuation.resume(returning: .denied)
                case .undetermined:
                    continuation.resume(returning: .undetermined)
                @unknown default:
                    continuation.resume(returning: .undetermined)
                }
            }
        }
    }
    
    /// Start recording audio
    func startRecording() async throws {
        // Check if already recording
        guard state != .recording else {
            throw AudioRecordingError.recordingInProgress
        }
        
        // Check permission
        let permission = await checkPermission()
        guard permission == .granted else {
            throw AudioRecordingError.permissionDenied
        }
        
        // Set up audio session
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw AudioRecordingError.audioSessionSetupFailed
        }
        
        // Create audio engine if needed
        if audioEngine == nil {
            audioEngine = AVAudioEngine()
        }
        
        guard let audioEngine = audioEngine else {
            throw AudioRecordingError.audioEngineSetupFailed
        }
        
        // Get the audio input node
        audioInputNode = audioEngine.inputNode
        audioInputFormat = audioInputNode?.outputFormat(forBus: 0)
        
        guard let audioInputNode = audioInputNode, let audioInputFormat = audioInputFormat else {
            throw AudioRecordingError.audioEngineSetupFailed
        }
        
        // Create recording file
        let filename = "recording_\(Date().timeIntervalSince1970).m4a"
        let fileURL = recordingsDirectory.appendingPathComponent(filename)
        
        guard let audioFile = try? AVAudioFile(
            forWriting: fileURL,
            settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: audioInputFormat.sampleRate,
                AVNumberOfChannelsKey: audioInputFormat.channelCount,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
        ) else {
            throw AudioRecordingError.fileCreationFailed
        }
        
        self.audioFile = audioFile
        self.recordingURL = fileURL
        
        // Install tap on input node to get audio data
        audioInputNode.installTap(onBus: 0, bufferSize: 1024, format: audioInputFormat) { [weak self] buffer, time in
            guard let self = self else { return }
            
            // Write buffer to file
            do {
                try self.audioFile?.write(from: buffer)
            } catch {
                print("Error writing buffer to file: \(error.localizedDescription)")
            }
            
            // Calculate audio level
            Task { [buffer] in
                await self.calculateAudioLevel(buffer: buffer)
            }
        }
        
        // Start audio engine
        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            throw AudioRecordingError.audioEngineSetupFailed
        }
        
        // Update state and start timers
        recordingStartTime = Date()
        recordingPausedTime = 0
        
        // Set an initial audio level to ensure waveform is visible immediately
        audioLevel = 0.05
        
        startTimers()
        
        state = .recording
    }
    
    /// Pause the current recording
    func pauseRecording() async throws {
        guard state == .recording, let audioEngine = audioEngine else {
            throw AudioRecordingError.noRecordingInProgress
        }
        
        // Stop audio engine but keep file open
        audioEngine.pause()
        
        // Update paused time
        if let startTime = recordingStartTime {
            recordingPausedTime += Date().timeIntervalSince(startTime)
        }
        
        // Stop timers
        stopTimers()
        
        state = .paused
    }
    
    /// Resume a paused recording
    func resumeRecording() async throws {
        guard state == .paused, let audioEngine = audioEngine else {
            throw AudioRecordingError.noRecordingInProgress
        }
        
        // Start audio engine again
        do {
            try audioEngine.start()
        } catch {
            throw AudioRecordingError.audioEngineSetupFailed
        }
        
        // Update start time
        recordingStartTime = Date()
        
        // Start timers
        startTimers()
        
        state = .recording
    }
    
    /// Stop and finalize the current recording
    func stopRecording() async throws -> URL? {
        guard state == .recording || state == .paused, let audioEngine = audioEngine else {
            throw AudioRecordingError.noRecordingInProgress
        }
        
        // Stop audio engine
        audioEngine.stop()
        audioInputNode?.removeTap(onBus: 0)
        
        // Stop timers
        stopTimers()
        
        // Update final duration
        if let startTime = recordingStartTime {
            duration = recordingPausedTime + Date().timeIntervalSince(startTime)
        }
        
        // Clean up - properly handle optionals
        let recordingURLCopy = recordingURL
        
        self.audioEngine = nil
        self.audioFile = nil
        self.audioInputNode = nil
        self.audioInputFormat = nil
        
        // Deactivate audio session
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Error deactivating audio session: \(error.localizedDescription)")
        }
        
        // Update state
        state = .stopped
        
        return recordingURLCopy
    }
    
    /// Delete the current recording file
    func deleteRecording() async {
        guard let url = recordingURL else { return }
        
        do {
            try FileManager.default.removeItem(at: url)
            recordingURL = nil
        } catch {
            print("Error deleting recording: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Methods
    
    private func createRecordingsDirectoryIfNeeded() {
        do {
            try FileManager.default.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)
        } catch {
            print("Error creating recordings directory: \(error.localizedDescription)")
        }
    }
    
    private func startTimers() {
        // Timer for updating duration
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let startTime = self.recordingStartTime else { return }
                self.duration = self.recordingPausedTime + Date().timeIntervalSince(startTime)
            }
        }
        
        // Timer for updating audio level (in case there's no audio)
        levelUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.audioLevel > 0 {
                    // Gradually decrease audio level if no new audio is detected
                    self.audioLevel = max(0, self.audioLevel - 0.05)
                }
            }
        }
    }
    
    private func stopTimers() {
        durationTimer?.invalidate()
        durationTimer = nil
        
        levelUpdateTimer?.invalidate()
        levelUpdateTimer = nil
    }
    
    // Make this function properly handle actor isolation
    private func calculateAudioLevel(buffer: AVAudioPCMBuffer) async {
        guard let channelData = buffer.floatChannelData else { return }
        
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        
        // Calculate RMS (root mean square) for audio level
        var rms: Float = 0.0
        
        for channel in 0..<channelCount {
            let data = channelData[channel]
            
            for frame in 0..<frameLength {
                let sample = data[frame]
                rms += sample * sample
            }
        }
        
        rms = sqrt(rms / Float(frameLength * channelCount))
        
        // Convert to decibels and normalize to 0-1 range
        var decibels: Float = 0.0
        if rms > 0 {
            decibels = 20 * log10(rms)
        } else {
            decibels = -160 // Silence
        }
        
        // Normalize to 0-1 range (assuming typical values between -60dB and 0dB)
        let normalizedLevel = max(0, min(1, (decibels + 60) / 60))
        
        // Update audio level on main thread
        await MainActor.run {
            self.audioLevel = normalizedLevel
        }
    }
}

// MARK: - Testing Support
    
// These methods are for testing purposes only
extension AudioRecordingService {
    /// Internal method to set state (for testing)
    @MainActor
    internal func setStateForTesting(_ newState: RecordingState) {
        state = newState
    }
    
    /// Internal method to set recordingURL (for testing)
    @MainActor
    internal func setRecordingURLForTesting(_ url: URL?) {
        recordingURL = url
    }
    
    /// Internal method to set audioLevel (for testing)
    @MainActor
    internal func setAudioLevelForTesting(_ level: Float) {
        audioLevel = level
    }
    
    /// Internal method to set duration (for testing)
    @MainActor
    internal func setDurationForTesting(_ newDuration: TimeInterval) {
        duration = newDuration
    }
}

// MARK: - Extensions

extension AudioRecordingService {
    /// Get formatted duration string (MM:SS)
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// Get file size of the recording in bytes
    var fileSize: Int64? {
        guard let url = recordingURL else { return nil }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64
        } catch {
            print("Error getting file size: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Get formatted file size string
    var formattedFileSize: String {
        guard let size = fileSize else { return "Unknown size" }
        
        let byteCountFormatter = ByteCountFormatter()
        byteCountFormatter.allowedUnits = [.useKB, .useMB]
        byteCountFormatter.countStyle = .file
        
        return byteCountFormatter.string(fromByteCount: size)
    }
}
