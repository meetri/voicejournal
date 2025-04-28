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
    private let smoothingFactor: CGFloat = 0.0
    
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
        
        print("DEBUG: WaveformViewModel - Updated with audioLevel: \(audioLevel), isActive: \(isActive)")
    }
    
    /// Start the timer for waveform animation
    func startTimer() {
        // Stop existing timer if any
        stopTimer()
        
        // Create new timer
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.updateLevelHistory()
        }
        
        print("DEBUG: WaveformViewModel - Timer started")
    }
    
    /// Stop the animation timer
    func stopTimer() {
        timer?.invalidate()
        timer = nil
        print("DEBUG: WaveformViewModel - Timer stopped")
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
        // Add new level at the beginning
        var newHistory = levelHistory
        
        if isActive {
            // Apply exponential smoothing to the audio level
            let smoothedLevel = (smoothingFactor * lastProcessedLevel) + ((1 - smoothingFactor) * audioLevel)
            lastProcessedLevel = smoothedLevel
            
            print("DEBUG: WaveformViewModel - Raw audioLevel: \(audioLevel), Smoothed: \(smoothedLevel)")
            
            // Apply scaling and ensure we have a visible level
            let scaledLevel = min(1.0, smoothedLevel * scalingFactor)
            
            // For playback, ensure we always have some visible activity
            if audioLevel > 0.01 {
                // Use the actual level when it's significant
                newHistory.insert(scaledLevel, at: 0)
                print("DEBUG: WaveformViewModel - Inserted new level: \(scaledLevel)")
            } else if isActive {
                // If audio level is very low but we're active, use a random small value to show some activity
                // This creates a more natural-looking waveform during quiet parts
                newHistory.insert(scaledLevel, at: 0)

                // let minLevel: CGFloat = 0.05
                // let maxLevel: CGFloat = 0.15
                // let randomLevel = minLevel + CGFloat.random(in: 0...1) * (maxLevel - minLevel)
                // newHistory.insert(randomLevel, at: 0)
                // print("DEBUG: WaveformViewModel - Using random level: \(randomLevel)")
            } else {
                // When inactive, use zero
                newHistory.insert(0, at: 0)
            }
        } else {
            // When inactive, gradually reduce levels
            newHistory.insert(0, at: 0)
        }
        
        // Remove last element to maintain fixed size
        if !newHistory.isEmpty && newHistory.count > barCount {
            newHistory.removeLast()
        }
        
        // Update state on the main thread
        DispatchQueue.main.async {
            self.levelHistory = newHistory
        }
    }
}
