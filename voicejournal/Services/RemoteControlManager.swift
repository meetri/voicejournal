//
//  RemoteControlManager.swift
//  voicejournal
//
//  Created on 4/27/25.
//

import Foundation
import MediaPlayer
import UIKit
import Combine

/// Manager for handling remote control events and now playing information
@MainActor
class RemoteControlManager: NSObject {
    // MARK: - Singleton
    
    /// Shared instance of the RemoteControlManager
    static let shared = RemoteControlManager()
    
    // MARK: - Properties
    
    /// The command center for handling remote control events
    private let commandCenter = MPRemoteCommandCenter.shared()
    
    /// The now playing info center for displaying metadata
    private let nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()
    
    /// The current audio playback service
    private weak var playbackService: AudioPlaybackService?
    
    /// The current journal entry title
    private var currentTitle: String = "Voice Journal"
    
    /// The current journal entry artwork
    private var currentArtwork: UIImage?
    
    /// Set of cancellables for managing subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        
        // Disable commands initially
        disableRemoteCommands()
    }
    
    // MARK: - Public Methods
    
    /// Set up remote control commands for the given playback service
    func setupRemoteControls(for playbackService: AudioPlaybackService, title: String, artwork: UIImage? = nil) {
        self.playbackService = playbackService
        self.currentTitle = title
        self.currentArtwork = artwork
        
        // Enable remote commands
        enableRemoteCommands()
        
        // Set up publishers
        setupPublishers()
        
        // Update initial now playing info
        updateNowPlayingInfo(
            title: currentTitle,
            duration: playbackService.duration,
            currentTime: playbackService.currentTime,
            rate: playbackService.rate,
            artwork: currentArtwork
        )
    }
    
    /// Clear remote control commands and now playing info
    func clearRemoteControls() {
        // Disable remote commands
        disableRemoteCommands()
        
        // Clear now playing info
        nowPlayingInfoCenter.nowPlayingInfo = nil
        
        // Clear references
        playbackService = nil
        currentTitle = "Voice Journal"
        currentArtwork = nil
        
        // Cancel subscriptions
        cancellables.removeAll()
    }
    
    /// Update the now playing info with the given metadata
    func updateNowPlayingInfo(title: String, duration: TimeInterval, currentTime: TimeInterval, rate: Float, artwork: UIImage? = nil) {
        // Create now playing info dictionary
        var nowPlayingInfo = [String: Any]()
        
        // Set metadata
        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = rate
        
        // Set artwork if available
        if let artwork = artwork {
            let mpArtwork = MPMediaItemArtwork(boundsSize: artwork.size) { _ in artwork }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = mpArtwork
        }
        
        // Update now playing info center
        nowPlayingInfoCenter.nowPlayingInfo = nowPlayingInfo
    }
    
    // MARK: - Private Methods
    
    /// Set up publishers to monitor playback state changes
    private func setupPublishers() {
        guard let playbackService = playbackService else { return }
        
        // Monitor current time changes
        playbackService.$currentTime
            .receive(on: RunLoop.main)
            .sink { [weak self] currentTime in
                guard let self = self else { return }
                self.updateNowPlayingInfoTime(currentTime: currentTime)
            }
            .store(in: &cancellables)
        
        // Monitor playback state changes
        playbackService.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self = self else { return }
                
                // Update playback rate based on state
                let rate: Float
                switch state {
                case .playing:
                    rate = playbackService.rate
                case .paused, .stopped, .ready, .error:
                    rate = 0.0
                }
                
                self.updateNowPlayingInfoRate(rate: rate)
            }
            .store(in: &cancellables)
        
        // Monitor rate changes
        playbackService.$rate
            .receive(on: RunLoop.main)
            .sink { [weak self] rate in
                guard let self = self, case .playing = playbackService.state else { return }
                self.updateNowPlayingInfoRate(rate: rate)
            }
            .store(in: &cancellables)
    }
    
    /// Update just the time in the now playing info
    private func updateNowPlayingInfoTime(currentTime: TimeInterval) {
        // Get current now playing info
        guard var nowPlayingInfo = nowPlayingInfoCenter.nowPlayingInfo else { return }
        
        // Update current time
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        
        // Update now playing info center
        nowPlayingInfoCenter.nowPlayingInfo = nowPlayingInfo
    }
    
    /// Update just the playback rate in the now playing info
    private func updateNowPlayingInfoRate(rate: Float) {
        // Get current now playing info
        guard var nowPlayingInfo = nowPlayingInfoCenter.nowPlayingInfo else { return }
        
        // Update playback rate
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = rate
        
        // Update now playing info center
        nowPlayingInfoCenter.nowPlayingInfo = nowPlayingInfo
    }
    
    /// Enable remote control commands
    private func enableRemoteCommands() {
        // Play command
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self = self, let playbackService = self.playbackService else {
                return .commandFailed
            }
            
            do {
                try playbackService.play()
                return .success
            } catch {
                print("ERROR: RemoteControlManager - Failed to play: \(error.localizedDescription)")
                return .commandFailed
            }
        }
        
        // Pause command
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self = self, let playbackService = self.playbackService else {
                return .commandFailed
            }
            
            do {
                try playbackService.pause()
                return .success
            } catch {
                print("ERROR: RemoteControlManager - Failed to pause: \(error.localizedDescription)")
                return .commandFailed
            }
        }
        
        // Toggle play/pause command
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self = self, let playbackService = self.playbackService else {
                return .commandFailed
            }
            
            do {
                if case .playing = playbackService.state {
                    try playbackService.pause()
                } else {
                    try playbackService.play()
                }
                return .success
            } catch {
                print("ERROR: RemoteControlManager - Failed to toggle play/pause: \(error.localizedDescription)")
                return .commandFailed
            }
        }
        
        // Stop command
        commandCenter.stopCommand.isEnabled = true
        commandCenter.stopCommand.addTarget { [weak self] _ in
            guard let self = self, let playbackService = self.playbackService else {
                return .commandFailed
            }
            
            do {
                try playbackService.stop()
                return .success
            } catch {
                print("ERROR: RemoteControlManager - Failed to stop: \(error.localizedDescription)")
                return .commandFailed
            }
        }
        
        // Seek command
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self,
                  let playbackService = self.playbackService,
                  let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            
            do {
                try playbackService.seek(to: event.positionTime)
                return .success
            } catch {
                print("ERROR: RemoteControlManager - Failed to seek: \(error.localizedDescription)")
                return .commandFailed
            }
        }
        
        // Skip forward command (10 seconds)
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [NSNumber(value: 10)]
        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            guard let self = self,
                  let playbackService = self.playbackService,
                  let event = event as? MPSkipIntervalCommandEvent else {
                return .commandFailed
            }
            
            do {
                let newTime = playbackService.currentTime + event.interval
                try playbackService.seek(to: newTime)
                return .success
            } catch {
                print("ERROR: RemoteControlManager - Failed to skip forward: \(error.localizedDescription)")
                return .commandFailed
            }
        }
        
        // Skip backward command (10 seconds)
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [NSNumber(value: 10)]
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            guard let self = self,
                  let playbackService = self.playbackService,
                  let event = event as? MPSkipIntervalCommandEvent else {
                return .commandFailed
            }
            
            do {
                let newTime = max(0, playbackService.currentTime - event.interval)
                try playbackService.seek(to: newTime)
                return .success
            } catch {
                print("ERROR: RemoteControlManager - Failed to skip backward: \(error.localizedDescription)")
                return .commandFailed
            }
        }
        
        // Change playback rate command
        commandCenter.changePlaybackRateCommand.isEnabled = true
        commandCenter.changePlaybackRateCommand.supportedPlaybackRates = [0.5, 1.0, 1.5, 2.0]
        commandCenter.changePlaybackRateCommand.addTarget { [weak self] event in
            guard let self = self,
                  let playbackService = self.playbackService,
                  let event = event as? MPChangePlaybackRateCommandEvent else {
                return .commandFailed
            }
            
            do {
                try playbackService.setRate(event.playbackRate)
                return .success
            } catch {
                print("ERROR: RemoteControlManager - Failed to change playback rate: \(error.localizedDescription)")
                return .commandFailed
            }
        }
    }
    
    /// Disable remote control commands
    private func disableRemoteCommands() {
        // Disable all commands
        commandCenter.playCommand.isEnabled = false
        commandCenter.pauseCommand.isEnabled = false
        commandCenter.togglePlayPauseCommand.isEnabled = false
        commandCenter.stopCommand.isEnabled = false
        commandCenter.changePlaybackPositionCommand.isEnabled = false
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false
        commandCenter.changePlaybackRateCommand.isEnabled = false
        
        // Remove all targets
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.stopCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)
        commandCenter.skipForwardCommand.removeTarget(nil)
        commandCenter.skipBackwardCommand.removeTarget(nil)
        commandCenter.changePlaybackRateCommand.removeTarget(nil)
    }
}
