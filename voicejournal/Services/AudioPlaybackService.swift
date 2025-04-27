//
//  AudioPlaybackService.swift
//  voicejournal
//
//  Created on 4/27/25.
//

import Foundation
import AVFoundation
import Combine

/// Enum representing the possible states of audio playback
enum PlaybackState {
    case ready
    case playing
    case paused
    case stopped
    case error(Error)
}

// Add Equatable conformance to PlaybackState
extension PlaybackState: Equatable {
    static func == (lhs: PlaybackState, rhs: PlaybackState) -> Bool {
        switch (lhs, rhs) {
        case (.ready, .ready), (.playing, .playing), (.paused, .paused), (.stopped, .stopped):
            return true
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

/// Enum representing errors that can occur during audio playback
enum AudioPlaybackError: Error {
    case audioSessionSetupFailed
    case playerInitializationFailed
    case fileNotFound
    case invalidFileFormat
    case playbackFailed
    case noPlaybackInProgress
    case unknown(Error)
    
    var localizedDescription: String {
        switch self {
        case .audioSessionSetupFailed:
            return "Failed to set up audio session"
        case .playerInitializationFailed:
            return "Failed to initialize audio player"
        case .fileNotFound:
            return "Audio file not found"
        case .invalidFileFormat:
            return "Invalid audio file format"
        case .playbackFailed:
            return "Playback failed"
        case .noPlaybackInProgress:
            return "No playback is in progress"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}

// Add Equatable conformance to AudioPlaybackError
extension AudioPlaybackError: Equatable {
    static func == (lhs: AudioPlaybackError, rhs: AudioPlaybackError) -> Bool {
        switch (lhs, rhs) {
        case (.audioSessionSetupFailed, .audioSessionSetupFailed),
             (.playerInitializationFailed, .playerInitializationFailed),
             (.fileNotFound, .fileNotFound),
             (.invalidFileFormat, .invalidFileFormat),
             (.playbackFailed, .playbackFailed),
             (.noPlaybackInProgress, .noPlaybackInProgress):
            return true
        case (.unknown(let lhsError), .unknown(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

/// Service responsible for handling audio playback functionality
@MainActor
class AudioPlaybackService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    // MARK: - Published Properties
    
    /// Current state of the playback
    @Published private(set) var state: PlaybackState = .ready
    
    /// Current playback position in seconds
    @Published private(set) var currentTime: TimeInterval = 0.0
    
    /// Total duration of the audio file in seconds
    @Published private(set) var duration: TimeInterval = 0.0
    
    /// Current audio level (0.0 to 1.0)
    @Published private(set) var audioLevel: Float = 0.0
    
    /// Current playback rate (0.5 to 2.0)
    @Published private(set) var rate: Float = 1.0
    
    /// URL of the audio file being played
    @Published private(set) var audioFileURL: URL?
    
    // MARK: - Private Properties
    
    nonisolated(unsafe) private var audioPlayer: AVAudioPlayer?
    nonisolated(unsafe) private var progressTimer: Timer?
    nonisolated(unsafe) private var levelUpdateTimer: Timer?
    private let audioSession = AVAudioSession.sharedInstance()
    
    // MARK: - Initialization
    
    override init() {
        super.init()
    }
    
    deinit {
        stopProgressTimer()
        stopLevelUpdateTimer()
    }
    
    // MARK: - Public Methods
    
    /// Load an audio file for playback
    func loadAudio(from url: URL) async throws {
        // Reset current state
        reset()
        
        // Set up audio session
        do {
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
        } catch {
            throw AudioPlaybackError.audioSessionSetupFailed
        }
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AudioPlaybackError.fileNotFound
        }
        
        // Initialize audio player
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            // Update properties
            audioFileURL = url
            duration = audioPlayer?.duration ?? 0.0
            state = .ready
            
            return
        } catch {
            throw AudioPlaybackError.playerInitializationFailed
        }
    }
    
    /// Start or resume playback
    func play() throws {
        guard let player = audioPlayer else {
            throw AudioPlaybackError.noPlaybackInProgress
        }
        
        // Start playback
        if !player.play() {
            throw AudioPlaybackError.playbackFailed
        }
        
        // Update state
        state = .playing
        
        // Start timers
        startProgressTimer()
        startLevelUpdateTimer()
    }
    
    /// Pause playback
    func pause() throws {
        guard let player = audioPlayer, state == .playing else {
            throw AudioPlaybackError.noPlaybackInProgress
        }
        
        // Pause playback
        player.pause()
        
        // Update state
        state = .paused
        
        // Stop timers
        stopProgressTimer()
        stopLevelUpdateTimer()
    }
    
    /// Stop playback
    func stop() throws {
        guard let player = audioPlayer else {
            throw AudioPlaybackError.noPlaybackInProgress
        }
        
        // Stop playback
        player.stop()
        player.currentTime = 0
        
        // Update state
        state = .stopped
        currentTime = 0
        
        // Stop timers
        stopProgressTimer()
        stopLevelUpdateTimer()
    }
    
    /// Seek to a specific position in the audio file
    func seek(to time: TimeInterval) throws {
        guard let player = audioPlayer else {
            throw AudioPlaybackError.noPlaybackInProgress
        }
        
        // Ensure time is within valid range
        let seekTime = max(0, min(time, duration))
        
        // Set player position
        player.currentTime = seekTime
        
        // Update current time
        currentTime = seekTime
    }
    
    /// Set the playback rate
    func setRate(_ newRate: Float) throws {
        guard let player = audioPlayer else {
            throw AudioPlaybackError.noPlaybackInProgress
        }
        
        // Ensure rate is within valid range (0.5 to 2.0)
        let clampedRate = max(0.5, min(newRate, 2.0))
        
        // Set player rate
        player.rate = clampedRate
        
        // Update rate
        rate = clampedRate
    }
    
    /// Reset the service state
    func reset() {
        // Stop playback if in progress
        audioPlayer?.stop()
        
        // Stop timers
        stopProgressTimer()
        stopLevelUpdateTimer()
        
        // Reset properties
        audioPlayer = nil
        audioFileURL = nil
        state = .ready
        currentTime = 0
        duration = 0
        audioLevel = 0
        rate = 1.0
        
        // Deactivate audio session
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Error deactivating audio session: \(error.localizedDescription)")
        }
    }
    
    // MARK: - AVAudioPlayerDelegate
    
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            if flag {
                // Playback completed successfully
                state = .stopped
                currentTime = duration
            } else {
                // Playback failed
                state = .error(AudioPlaybackError.playbackFailed)
            }
            
            // Stop timers
            stopProgressTimer()
            stopLevelUpdateTimer()
        }
    }
    
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            if let error = error {
                state = .error(AudioPlaybackError.unknown(error))
            } else {
                state = .error(AudioPlaybackError.playbackFailed)
            }
            
            // Stop timers
            stopProgressTimer()
            stopLevelUpdateTimer()
        }
    }
    
    // MARK: - Private Methods
    
    private func startProgressTimer() {
        // Stop existing timer if any
        stopProgressTimer()
        
        // Create new timer that updates every 0.1 seconds
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let player = self.audioPlayer else { return }
                self.currentTime = player.currentTime
            }
        }
    }
    
    nonisolated private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    private func startLevelUpdateTimer() {
        // Stop existing timer if any
        stopLevelUpdateTimer()
        
        // Create new timer that updates every 0.1 seconds
        levelUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let player = self.audioPlayer else { return }
                
                // Update audio level
                player.updateMeters()
                let level = player.averagePower(forChannel: 0)
                
                // Convert from dB to linear scale (0.0 to 1.0)
                // dB range is typically -160 to 0, where -160 is silence and 0 is max volume
                let normalizedLevel = max(0, min(1, (level + 60) / 60))
                self.audioLevel = normalizedLevel
            }
        }
    }
    
    nonisolated private func stopLevelUpdateTimer() {
        levelUpdateTimer?.invalidate()
        levelUpdateTimer = nil
    }
}

// MARK: - Extensions

extension AudioPlaybackService {
    /// Get formatted current time string (MM:SS)
    var formattedCurrentTime: String {
        return formatTimeInterval(currentTime)
    }
    
    /// Get formatted duration string (MM:SS)
    var formattedDuration: String {
        return formatTimeInterval(duration)
    }
    
    /// Format a time interval as MM:SS
    private func formatTimeInterval(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// Get playback progress as a value between 0.0 and 1.0
    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }
}

// MARK: - Testing Support

extension AudioPlaybackService {
    /// Internal method to set state (for testing)
    @MainActor
    internal func setStateForTesting(_ newState: PlaybackState) {
        state = newState
    }
    
    /// Internal method to set currentTime (for testing)
    @MainActor
    internal func setCurrentTimeForTesting(_ time: TimeInterval) {
        currentTime = time
    }
    
    /// Internal method to set duration (for testing)
    @MainActor
    internal func setDurationForTesting(_ newDuration: TimeInterval) {
        duration = newDuration
    }
    
    /// Internal method to set audioLevel (for testing)
    @MainActor
    internal func setAudioLevelForTesting(_ level: Float) {
        audioLevel = level
    }
}
