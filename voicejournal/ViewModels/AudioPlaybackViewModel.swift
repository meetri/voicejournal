//
//  AudioPlaybackViewModel.swift
//  voicejournal
//
//  Created on 4/27/25.
//

import Foundation
import SwiftUI
import Combine
import AVFoundation

/// ViewModel for handling audio playback functionality
@MainActor
class AudioPlaybackViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Whether audio is currently playing
    @Published private(set) var isPlaying = false
    
    /// Whether audio is currently paused
    @Published private(set) var isPaused = false
    
    /// Current playback position in seconds
    @Published private(set) var currentTime: TimeInterval = 0.0
    
    /// Total duration of the audio file in seconds
    @Published private(set) var duration: TimeInterval = 0.0
    
    /// Formatted current time string (MM:SS)
    @Published private(set) var formattedCurrentTime: String = "00:00"
    
    /// Formatted duration string (MM:SS)
    @Published private(set) var formattedDuration: String = "00:00"
    
    /// Current audio level (0.0 to 1.0)
    @Published private(set) var audioLevel: Float = 0.0
    
    /// Playback progress (0.0 to 1.0)
    @Published private(set) var progress: Double = 0.0
    
    /// Current playback rate (0.5 to 2.0)
    @Published private(set) var rate: Float = 1.0
    
    /// Error message to display
    @Published var errorMessage: String?
    
    /// Whether to show the error alert
    @Published var showErrorAlert = false
    
    /// Whether audio is loaded and ready to play
    @Published private(set) var isAudioLoaded = false
    
    // MARK: - Private Properties
    
    private let playbackService: AudioPlaybackService
    private var cancellables = Set<AnyCancellable>()
    private var audioFileURL: URL?
    
    // MARK: - Initialization
    
    init(playbackService: AudioPlaybackService) {
        self.playbackService = playbackService
        
        // Set up publishers
        setupPublishers()
    }
    
    // MARK: - Public Methods
    
    /// Load an audio file for playback
    func loadAudio(from url: URL) async {
        do {
            try await playbackService.loadAudio(from: url)
            audioFileURL = url
            isAudioLoaded = true
        } catch {
            handleError(error)
            isAudioLoaded = false
        }
    }
    
    /// Load an audio file from an AudioRecording entity
    func loadAudio(from recording: AudioRecording) async {
        guard let filePath = recording.filePath else {
            handleError(AudioPlaybackError.fileNotFound)
            return
        }
        
        let url = URL(fileURLWithPath: filePath)
        await loadAudio(from: url)
    }
    
    /// Start or resume playback
    func play() {
        do {
            try playbackService.play()
            isPlaying = true
            isPaused = false
        } catch {
            handleError(error)
        }
    }
    
    /// Pause playback
    func pause() {
        do {
            try playbackService.pause()
            isPlaying = false
            isPaused = true
        } catch {
            handleError(error)
        }
    }
    
    /// Stop playback
    func stop() {
        do {
            try playbackService.stop()
            isPlaying = false
            isPaused = false
        } catch {
            handleError(error)
        }
    }
    
    /// Toggle between play and pause
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    /// Seek to a specific position in the audio file
    func seek(to time: TimeInterval) {
        do {
            try playbackService.seek(to: time)
        } catch {
            handleError(error)
        }
    }
    
    /// Seek to a specific progress position (0.0 to 1.0)
    func seekToProgress(_ progress: Double) {
        let time = progress * duration
        seek(to: time)
    }
    
    /// Set the playback rate
    func setRate(_ newRate: Float) {
        do {
            try playbackService.setRate(newRate)
        } catch {
            handleError(error)
        }
    }
    
    /// Skip forward by a specified number of seconds
    func skipForward(seconds: TimeInterval = 10) {
        let newTime = currentTime + seconds
        seek(to: newTime)
    }
    
    /// Skip backward by a specified number of seconds
    func skipBackward(seconds: TimeInterval = 10) {
        let newTime = max(0, currentTime - seconds)
        seek(to: newTime)
    }
    
    /// Reset the view model state
    func reset() {
        playbackService.reset()
        
        isPlaying = false
        isPaused = false
        currentTime = 0
        duration = 0
        formattedCurrentTime = "00:00"
        formattedDuration = "00:00"
        audioLevel = 0
        progress = 0
        rate = 1.0
        errorMessage = nil
        showErrorAlert = false
        isAudioLoaded = false
        audioFileURL = nil
    }
    
    // MARK: - Private Methods
    
    private func setupPublishers() {
        // Subscribe to playback state changes
        playbackService.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self = self else { return }
                
                switch state {
                case .ready:
                    self.isPlaying = false
                    self.isPaused = false
                case .playing:
                    self.isPlaying = true
                    self.isPaused = false
                case .paused:
                    self.isPlaying = false
                    self.isPaused = true
                case .stopped:
                    self.isPlaying = false
                    self.isPaused = false
                case .error(let error):
                    self.handleError(error)
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to current time changes
        playbackService.$currentTime
            .receive(on: RunLoop.main)
            .sink { [weak self] time in
                guard let self = self else { return }
                self.currentTime = time
                self.formattedCurrentTime = self.formatTimeInterval(time)
                
                // Update progress
                if self.duration > 0 {
                    self.progress = time / self.duration
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to duration changes
        playbackService.$duration
            .receive(on: RunLoop.main)
            .sink { [weak self] duration in
                guard let self = self else { return }
                self.duration = duration
                self.formattedDuration = self.formatTimeInterval(duration)
            }
            .store(in: &cancellables)
        
        // Subscribe to audio level changes
        playbackService.$audioLevel
            .receive(on: RunLoop.main)
            .sink { [weak self] level in
                self?.audioLevel = level
            }
            .store(in: &cancellables)
        
        // Subscribe to rate changes
        playbackService.$rate
            .receive(on: RunLoop.main)
            .sink { [weak self] rate in
                self?.rate = rate
            }
            .store(in: &cancellables)
    }
    
    private func handleError(_ error: Error) {
        if let playbackError = error as? AudioPlaybackError {
            errorMessage = playbackError.localizedDescription
        } else {
            errorMessage = "An error occurred: \(error.localizedDescription)"
        }
        
        showErrorAlert = true
        
        // Reset playback state if needed
        if isPlaying {
            isPlaying = false
            isPaused = false
        }
    }
    
    private func formatTimeInterval(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Extensions

extension AudioPlaybackViewModel {
    /// Get audio level for visualization (0.0 to 1.0)
    var visualizationLevel: CGFloat {
        return CGFloat(audioLevel)
    }
    
    /// Check if playback is in progress (either playing or paused)
    var isPlaybackInProgress: Bool {
        return isPlaying || isPaused
    }
    
    /// Get the current playback rate as a string
    var rateString: String {
        switch rate {
        case 0.5:
            return "0.5x"
        case 1.0:
            return "1.0x"
        case 1.5:
            return "1.5x"
        case 2.0:
            return "2.0x"
        default:
            return String(format: "%.1fx", rate)
        }
    }
    
    /// Get the next playback rate in the sequence
    var nextRate: Float {
        switch rate {
        case 0.5:
            return 1.0
        case 1.0:
            return 1.5
        case 1.5:
            return 2.0
        case 2.0:
            return 0.5
        default:
            return 1.0
        }
    }
}
