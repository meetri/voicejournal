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
import CoreData

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
    
    /// Bookmarks for the current audio recording
    @Published private(set) var bookmarks: [Bookmark] = []
    
    /// Currently selected bookmark
    @Published private(set) var selectedBookmark: Bookmark?
    
    /// Whether to show the bookmark creation dialog
    @Published var showBookmarkDialog = false
    
    /// Text for new bookmark label
    @Published var newBookmarkLabel: String = ""
    
    /// Current text highlight range for transcription
    @Published private(set) var currentHighlightRange: NSRange?
    
    /// Current audio recording being played
    private(set) var currentRecording: AudioRecording?
    
    /// Current transcription being displayed
    private(set) var currentTranscription: Transcription?
    
    /// Current journal entry being played
    private(set) var currentJournalEntry: JournalEntry?
    
    /// Timing data for transcription text highlighting
    private var transcriptionTimingData: [TranscriptionSegment] = []
    
    /// Frequency data for spectrum visualization
    @Published private(set) var frequencyData: [Float] = []
    
    /// Whether to show AI analysis view
    @Published var showAIAnalysis = false
    
    /// Whether AI analysis is in progress
    @Published private(set) var isAnalyzing = false
    
    /// Current journal entry (for AI analysis)
    var journalEntry: JournalEntry? {
        currentRecording?.journalEntry
    }
    
    /// Current audio URL (for AI analysis)
    var audioURL: URL {
        audioFileURL ?? URL(fileURLWithPath: currentRecording?.effectiveFilePath ?? "")
    }
    
    // MARK: - Private Properties
    
    private let playbackService: AudioPlaybackService
    private let playbackManager = AudioPlaybackManager.shared
    private let spectrumAnalyzerService: SpectrumAnalyzerService
    private let audioFileAnalyzer = AudioFileAnalyzer()
    private var cancellables = Set<AnyCancellable>()
    private var audioFileURL: URL?
    private var highlightUpdateTimer: Timer?
    private var debugPrintedSegments = false
    
    // MARK: - Initialization
    
    init(playbackService: AudioPlaybackService) {
        self.playbackService = playbackService
        self.spectrumAnalyzerService = SpectrumAnalyzerService()
        
        // Set up the spectrum analyzer delegate
        self.spectrumAnalyzerService.delegate = self
        
        // Set up publishers
        setupPublishers()
        
        // Set up audio spectrum manager for AudioPlaybackManager
        setupSpectrumAnalyzer()
    }
    
    // MARK: - Public Methods
    
    /// Load an audio file for playback
    func loadAudio(from url: URL) async {
        // This method is no longer needed with the new AudioPlaybackManager
        // The manager handles loading internally
        print("⚠️ [AudioPlaybackViewModel] Direct URL loading is deprecated. Use loadAudio(from: AudioRecording) instead.")
    }
    
    /// Load an audio file from an AudioRecording entity
    func loadAudio(from recording: AudioRecording) async {
        print("🎵 [AudioPlaybackViewModel] loadAudio from recording")
        
        // Get the journal entry
        guard let journalEntry = recording.journalEntry else {
            print("❌ [AudioPlaybackViewModel] No journal entry associated with recording")
            handleError(AudioPlaybackError.fileNotFound)
            return
        }
        
        // Store the current recording and entry
        currentRecording = recording
        currentJournalEntry = journalEntry
        
        // Load bookmarks
        loadBookmarks(for: recording)
        
        // Load transcription timing data if available
        if let transcription = journalEntry.transcription {
            currentTranscription = transcription
            loadTranscriptionTimingData(from: transcription)
        } else {
            currentTranscription = nil
            transcriptionTimingData = []
        }
        
        // Use the AudioPlaybackManager to load and prepare audio
        playbackManager.loadAudio(for: journalEntry)
        
        // Subscribe to playback manager updates
        setupPlaybackManagerBindings()
        
        // Update state based on manager state
        isAudioLoaded = playbackManager.duration > 0
        
        // Handle any loading errors
        if let error = playbackManager.playbackError {
            handleError(error)
        }
    }
    
    /// Start or resume playback
    func play() {
        playbackManager.play()
        
        // Start highlight update timer if we have timing data
        if !transcriptionTimingData.isEmpty {
            startHighlightUpdateTimer()
        }
    }
    
    /// Pause playback
    func pause() {
        playbackManager.pause()
        
        // Stop highlight update timer
        stopHighlightUpdateTimer()
    }
    
    /// Stop playback
    func stop() {
        playbackManager.stop()
        
        // Stop highlight update timer
        stopHighlightUpdateTimer()
        
        // Clear highlight
        currentHighlightRange = nil
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
        playbackManager.seek(to: time)
        
        // Update highlight immediately
        updateHighlightedTextRange()
    }
    
    /// Seek to a specific progress position (0.0 to 1.0)
    func seekToProgress(_ progress: Double) {
        let time = progress * duration
        seek(to: time)
    }
    
    /// Set the playback rate
    func setRate(_ newRate: Float) {
        // The AudioPlaybackManager doesn't support rate control yet
        // For now, we'll just update our local state
        self.rate = newRate
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
        playbackManager.stop()
        
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
        
        bookmarks = []
        selectedBookmark = nil
        currentRecording = nil
        currentJournalEntry = nil
        currentTranscription = nil
        transcriptionTimingData = []
        currentHighlightRange = nil
        
        stopHighlightUpdateTimer()
        audioFileAnalyzer.stopAnalysis()
    }
    
    // MARK: - Bookmark Management
    
    /// Load bookmarks for the given audio recording
    private func loadBookmarks(for recording: AudioRecording) {
        bookmarks = recording.allBookmarks
    }
    
    /// Create a new bookmark at the current playback position
    func createBookmark(label: String? = nil, color: String? = nil) {
        guard let recording = currentRecording else { return }
        
        let bookmark = recording.createBookmark(
            at: currentTime,
            label: label,
            color: color
        )
        
        // Reload bookmarks to ensure they're sorted by timestamp
        bookmarks = recording.allBookmarks
        
        // Select the newly created bookmark
        selectedBookmark = bookmark
    }
    
    /// Delete a bookmark
    func deleteBookmark(_ bookmark: Bookmark) {
        guard let recording = currentRecording else { return }
        
        // Clear selection if the deleted bookmark is selected
        if selectedBookmark == bookmark {
            selectedBookmark = nil
        }
        
        recording.deleteBookmark(bookmark)
        
        // Reload bookmarks
        bookmarks = recording.allBookmarks
    }
    
    /// Seek to a specific bookmark
    func seekToBookmark(_ bookmark: Bookmark) {
        seek(to: bookmark.timestamp)
        selectedBookmark = bookmark
    }
    
    /// Find the nearest bookmark to the current playback position
    func findNearestBookmark() -> Bookmark? {
        guard let recording = currentRecording else { return nil }
        return recording.nearestBookmark(to: currentTime)
    }
    
    /// Skip to the next bookmark
    func skipToNextBookmark() {
        guard let recording = currentRecording else { return }
        
        if let nextBookmark = recording.nextBookmark(after: currentTime) {
            seekToBookmark(nextBookmark)
        }
    }
    
    /// Skip to the previous bookmark
    func skipToPreviousBookmark() {
        guard let recording = currentRecording else { return }
        
        if let prevBookmark = recording.previousBookmark(before: currentTime) {
            seekToBookmark(prevBookmark)
        }
    }
    
    // MARK: - Transcription Highlighting
    
    /// Load timing data from a transcription
    private func loadTranscriptionTimingData(from transcription: Transcription) {
        // Reset debug flag when loading new data
        debugPrintedSegments = false
        
        guard let timingDataString = transcription.timingData else {
            transcriptionTimingData = []
            return
        }
        
        do {
            // Parse JSON timing data
            if let data = timingDataString.data(using: .utf8) {
                let decoder = JSONDecoder()
                transcriptionTimingData = try decoder.decode([TranscriptionSegment].self, from: data)
            }
        } catch {
            transcriptionTimingData = []
        }
    }
    
    /// Update the highlighted text range based on current playback position
    private func updateHighlightedTextRange() {
        guard !transcriptionTimingData.isEmpty else {
            currentHighlightRange = nil
            return
        }
        
        
        // Find the segment that corresponds to the current playback time
        let currentSegment = transcriptionTimingData.first { segment in
            return currentTime >= segment.startTime && currentTime <= segment.endTime
        }
        
        if let segment = currentSegment {
            currentHighlightRange = NSRange(location: segment.textRange.location, length: segment.textRange.length)
        } else {
            currentHighlightRange = nil
        }
    }
    
    /// Start the timer for updating text highlighting
    private func startHighlightUpdateTimer() {
        stopHighlightUpdateTimer()
        
        // Only start if we have timing data
        guard !transcriptionTimingData.isEmpty else { return }
        
        highlightUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateHighlightedTextRange()
            }
        }
    }
    
    /// Stop the highlight update timer
    private func stopHighlightUpdateTimer() {
        highlightUpdateTimer?.invalidate()
        highlightUpdateTimer = nil
    }
    
    // MARK: - Private Methods
    
    private func setupPlaybackManagerBindings() {
        // Subscribe to playback manager state changes
        playbackManager.$isPlaying
            .receive(on: RunLoop.main)
            .sink { [weak self] isPlaying in
                self?.isPlaying = isPlaying
                self?.isPaused = !isPlaying && self?.playbackManager.currentTime ?? 0 > 0
            }
            .store(in: &cancellables)
        
        // Subscribe to current time changes
        playbackManager.$currentTime
            .receive(on: RunLoop.main)
            .sink { [weak self] time in
                guard let self = self else { return }
                self.currentTime = time
                self.formattedCurrentTime = self.formatTimeInterval(time)
                
                // Update progress
                if self.duration > 0 {
                    self.progress = time / self.duration
                }
                
                // Update highlighted text range
                self.updateHighlightedTextRange()
            }
            .store(in: &cancellables)
        
        // Subscribe to duration changes
        playbackManager.$duration
            .receive(on: RunLoop.main)
            .sink { [weak self] duration in
                guard let self = self else { return }
                self.duration = duration
                self.formattedDuration = self.formatTimeInterval(duration)
            }
            .store(in: &cancellables)
        
        // Subscribe to error changes
        playbackManager.$playbackError
            .receive(on: RunLoop.main)
            .sink { [weak self] error in
                if let error = error {
                    self?.handleError(error)
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupSpectrumAnalyzer() {
        // When audio file is loaded, set up spectrum analyzer for the file
        NotificationCenter.default.publisher(for: .AudioPlaybackManagerDidLoadAudio)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let url = notification.object as? URL else { return }
                
                // Start spectrum analysis for playback
                self.spectrumAnalyzerService.startPlaybackAnalysis(fileURL: url)
                try? self.spectrumAnalyzerService.start()
                print("🎵 [AudioPlaybackViewModel] Started spectrum analyzer for: \(url.lastPathComponent)")
            }
            .store(in: &cancellables)
        
        // When playback stops, stop the spectrum analyzer
        NotificationCenter.default.publisher(for: .AudioPlaybackManagerDidStop)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.spectrumAnalyzerService.stop()
                print("🎵 [AudioPlaybackViewModel] Stopped spectrum analyzer")
            }
            .store(in: &cancellables)
    }
    
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
                
                // Update highlighted text range
                self.updateHighlightedTextRange()
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

extension AudioPlaybackViewModel: AudioSpectrumDelegate, SpectrumAnalyzerDelegate {
    /// Implements AudioSpectrumDelegate to receive frequency data
    nonisolated func didUpdateSpectrum(_ bars: [Float]) {
        Task { @MainActor in
            self.frequencyData = bars
        }
    }
    
    /// Implements SpectrumAnalyzerDelegate to receive frequency data
    nonisolated func didUpdateFrequencyData(_ frequencyData: [Float]) {
        Task { @MainActor in
            self.frequencyData = frequencyData
        }
    }
}

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

// MARK: - Testing Support

extension AudioPlaybackViewModel {
    /// Set current time for testing
    @MainActor
    func setCurrentTimeForTesting(_ time: TimeInterval) {
        self.currentTime = time
    }
    
    /// Set transcription timing data for testing
    @MainActor
    func setTranscriptionTimingDataForTesting(_ segments: [TranscriptionSegment]) {
        self.transcriptionTimingData = segments
    }
    
    /// Update highlighted text range for testing
    @MainActor
    func updateHighlightedTextRangeForTesting() {
        self.updateHighlightedTextRange()
    }
}
