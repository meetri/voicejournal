//
//  WaveformViewModel.swift
//  voicejournal
//
//  Created on 4/27/25.
//

import Foundation
import SwiftUI
import Combine

/// ViewModel for managing waveform visualization state
class WaveformViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// The history of audio levels for animation
    @Published var levelHistory: [CGFloat] = []
    
    // MARK: - Private Properties
    
    /// The current audio level (0.0 to 1.0)
    private var audioLevel: CGFloat = 0.0
    
    /// Whether the waveform is active (recording)
    private var isActive: Bool = false
    
    /// The number of bars to display in the waveform
    private let barCount: Int
    
    /// Timer for updating the waveform
    private var timer: Timer? = nil
    
    /// Smoothing factor for audio level changes (0.0 to 1.0)
    /// Lower values make the waveform more responsive, higher values make it smoother
    private let smoothingFactor: CGFloat = 0.3
    
    /// The last processed audio level (for smoothing)
    private var lastProcessedLevel: CGFloat = 0.0
    
    /// The scaling factor to apply to the audio level
    private let scalingFactor: CGFloat = 1.5
    
    // MARK: - Initialization
    
    init(barCount: Int = 20) {
        self.barCount = barCount
        self.levelHistory = Array(repeating: 0, count: barCount)
    }
    
    // MARK: - Public Methods
    
    /// Update the audio level and active state
    func update(audioLevel: CGFloat, isActive: Bool) {
        let oldIsActive = self.isActive
        
        self.audioLevel = audioLevel
        self.isActive = isActive
        
        // Handle state changes
        if oldIsActive != isActive {
            handleActiveStateChange(isActive: isActive)
        }
    }
    
    /// Start the timer for waveform animation
    func startTimer() {
        // Stop existing timer if any
        stopTimer()
        
        // Create new timer with balanced frequency (0.05s → 0.1s)
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateLevelHistory()
        }
    }
    
    /// Stop the animation timer
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Private Methods
    
    /// Handle changes to the active state
    private func handleActiveStateChange(isActive: Bool) {
        if isActive {
            // Ensure level history is initialized when becoming active
            if levelHistory.isEmpty || levelHistory.count != barCount {
                levelHistory = Array(repeating: 0, count: barCount)
            }
            
            // Start the timer
            startTimer()
        } else {
            // Stop the timer
            stopTimer()
            
            // Reset the level history when becoming inactive
            levelHistory = Array(repeating: 0, count: barCount)
        }
    }
    
    /// Update the level history for animation
    private func updateLevelHistory() {
        // Memory optimization: Create a new array only when necessary
        // and reuse the existing array when possible
        var newLevels = [CGFloat]()
        newLevels.reserveCapacity(barCount)
        
        if isActive {
            // Apply exponential smoothing to the audio level
            let smoothedLevel = (smoothingFactor * lastProcessedLevel) + ((1 - smoothingFactor) * audioLevel)
            lastProcessedLevel = smoothedLevel
            
            // Apply scaling and ensure we have a visible level
            let scaledLevel = min(1.0, smoothedLevel * scalingFactor)
            
            // Add the new level at the beginning
            newLevels.append(scaledLevel)
            
            // Copy existing levels (up to barCount-1)
            let existingLevelsToKeep = min(barCount - 1, levelHistory.count)
            if existingLevelsToKeep > 0 {
                newLevels.append(contentsOf: levelHistory[0..<existingLevelsToKeep])
            }
        } else {
            // When inactive, gradually reduce levels
            newLevels.append(0)
            
            // Copy existing levels (up to barCount-1)
            let existingLevelsToKeep = min(barCount - 1, levelHistory.count)
            if existingLevelsToKeep > 0 {
                newLevels.append(contentsOf: levelHistory[0..<existingLevelsToKeep])
            }
        }
        
        // Update state on the main thread
        DispatchQueue.main.async {
            self.levelHistory = newLevels
        }
    }
}
