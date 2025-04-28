//
//  PlayerManager.swift
//  voicejournal
//
//  Created on 4/27/25.
//

import Foundation
import SwiftUI
import Combine

/// A singleton manager for handling global audio playback state
@MainActor
class PlayerManager: ObservableObject {
    // MARK: - Singleton
    
    /// Shared instance of the PlayerManager
    static let shared = PlayerManager()
    
    // MARK: - Published Properties
    
    /// The current audio playback view model
    @Published private(set) var playbackViewModel: AudioPlaybackViewModel
    
    /// Whether the player is currently active
    @Published private(set) var isPlayerActive = false
    
    /// Whether the player is expanded to full screen
    @Published var isPlayerExpanded = false
    
    /// The current journal entry being played
    @Published private(set) var currentJournalEntry: JournalEntry?
    
    // MARK: - Private Properties
    
    private let playbackService = AudioPlaybackService()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        // Initialize playback view model
        self.playbackViewModel = AudioPlaybackViewModel(playbackService: playbackService)
        
        // Set up publishers
        setupPublishers()
    }
    
    // MARK: - Public Methods
    
    /// Play audio from a journal entry
    func playAudio(from journalEntry: JournalEntry) async {
        guard let recording = journalEntry.audioRecording else {
            print("ERROR: PlayerManager - Journal entry has no audio recording")
            return
        }
        
        // Set current journal entry
        currentJournalEntry = journalEntry
        
        // Load and play audio
        await playbackViewModel.loadAudio(from: recording)
        playbackViewModel.play()
        
        // Update player state
        isPlayerActive = true
    }
    
    /// Stop playback and clear the current entry
    func stopPlayback() {
        playbackViewModel.stop()
        playbackViewModel.reset()
        
        // Clear current journal entry
        currentJournalEntry = nil
        
        // Update player state
        isPlayerActive = false
        isPlayerExpanded = false
    }
    
    /// Toggle between play and pause
    func togglePlayPause() {
        playbackViewModel.togglePlayPause()
    }
    
    /// Expand the player to full screen
    func expandPlayer() {
        isPlayerExpanded = true
    }
    
    /// Collapse the player to mini player
    func collapsePlayer() {
        isPlayerExpanded = false
    }
    
    // MARK: - Private Methods
    
    /// Set up publishers to monitor playback state changes
    private func setupPublishers() {
        // Monitor playback state
        playbackViewModel.$isPlaying
            .combineLatest(playbackViewModel.$isPaused)
            .map { isPlaying, isPaused in
                return isPlaying || isPaused
            }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] isActive in
                self?.isPlayerActive = isActive
            }
            .store(in: &cancellables)
    }
}

// MARK: - View Modifier

/// A view modifier that adds the player container to a view
struct PlayerContainerModifier: ViewModifier {
    @ObservedObject var playerManager = PlayerManager.shared
    
    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            // Original content
            content
            
            // Mini player
            if playerManager.isPlayerActive && !playerManager.isPlayerExpanded {
                MiniPlayerView(
                    viewModel: playerManager.playbackViewModel,
                    isExpanded: $playerManager.isPlayerExpanded
                )
                .transition(.move(edge: .bottom))
                .zIndex(1)
                .padding(.bottom, 8)
                .padding(.horizontal, 8)
            }
        }
        .sheet(isPresented: $playerManager.isPlayerExpanded) {
            // Full player sheet
            VStack {
                // Header with close button
                HStack {
                    Button(action: {
                        playerManager.collapsePlayer()
                    }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    if let entry = playerManager.currentJournalEntry {
                        Text(entry.title ?? "Voice Journal Entry")
                            .font(.headline)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        playerManager.stopPlayback()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
                .padding()
                
                // Playback view
                PlaybackView(viewModel: playerManager.playbackViewModel)
                    .padding()
                
                Spacer()
            }
            .background(Color(.systemGroupedBackground))
        }
    }
}

// MARK: - View Extension

extension View {
    /// Add the player container to a view
    func withPlayerContainer() -> some View {
        self.modifier(PlayerContainerModifier())
    }
}
