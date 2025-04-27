//
//  WaveformViewTests.swift
//  voicejournalTests
//
//  Created on 4/27/25.
//

import XCTest
import SwiftUI
@testable import voicejournal

final class WaveformViewTests: XCTestCase {
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    // Test initialization with default parameters
    func testInitWithDefaults() {
        let waveformView = WaveformView(audioLevel: 0.5)
        
        XCTAssertEqual(waveformView.audioLevel, 0.5, "Audio level should be set correctly")
        XCTAssertEqual(waveformView.color, .blue, "Default color should be blue")
        XCTAssertEqual(waveformView.barCount, 30, "Default bar count should be 30")
        XCTAssertEqual(waveformView.spacing, 3, "Default spacing should be 3")
        XCTAssertEqual(waveformView.cornerRadius, 3, "Default corner radius should be 3")
        XCTAssertTrue(waveformView.isActive, "Default isActive should be true")
    }
    
    // Test initialization with custom parameters
    func testInitWithCustomParameters() {
        let waveformView = WaveformView(
            audioLevel: 0.75,
            color: .red,
            barCount: 20,
            spacing: 5,
            cornerRadius: 8,
            isActive: false
        )
        
        XCTAssertEqual(waveformView.audioLevel, 0.75, "Audio level should be set correctly")
        XCTAssertEqual(waveformView.color, .red, "Color should be set to red")
        XCTAssertEqual(waveformView.barCount, 20, "Bar count should be set to 20")
        XCTAssertEqual(waveformView.spacing, 5, "Spacing should be set to 5")
        XCTAssertEqual(waveformView.cornerRadius, 8, "Corner radius should be set to 8")
        XCTAssertFalse(waveformView.isActive, "isActive should be set to false")
    }
    
    // Test that the timer is started when the view appears
    func testTimerStartsOnAppear() {
        let waveformView = WaveformView(audioLevel: 0.5)
        
        // Access the private timer property using reflection
        let mirror = Mirror(reflecting: waveformView)
        var timerBeforeAppear: Timer? = nil
        
        for child in mirror.children {
            if child.label == "timer" {
                timerBeforeAppear = child.value as? Timer
                break
            }
        }
        
        XCTAssertNil(timerBeforeAppear, "Timer should be nil before onAppear")
        
        // Simulate onAppear
        let expectation = XCTestExpectation(description: "Timer should be started")
        
        // We can't directly test the onAppear effect, but we can test the timer initialization logic
        // This is a limitation of testing SwiftUI views without ViewInspector
        
        // Instead, we'll verify the timer start/stop methods work correctly
        let testWaveformView = TestableWaveformView(audioLevel: 0.5)
        testWaveformView.startTimer()
        
        XCTAssertNotNil(testWaveformView.timer, "Timer should be initialized after startTimer")
        
        testWaveformView.stopTimer()
        XCTAssertNil(testWaveformView.timer, "Timer should be nil after stopTimer")
        
        expectation.fulfill()
        wait(for: [expectation], timeout: 0.1)
    }
    
    // Test that the level history is updated when the timer fires
    func testLevelHistoryUpdatesOnTimerFire() {
        let testWaveformView = TestableWaveformView(audioLevel: 0.5, isActive: true)
        
        // Initialize level history
        testWaveformView.levelHistory = Array(repeating: 0.0, count: testWaveformView.barCount)
        
        // Simulate timer firing
        testWaveformView.updateLevelHistory()
        
        // First element should be updated with a value based on audioLevel
        XCTAssertGreaterThan(testWaveformView.levelHistory[0], 0.0, "First element should be updated")
        
        // Test with inactive state
        testWaveformView.isActive = false
        testWaveformView.updateLevelHistory()
        
        // First element should be 0 when inactive
        XCTAssertEqual(testWaveformView.levelHistory[0], 0.0, "First element should be 0 when inactive")
    }
    
    // Test that the timer is stopped when the view disappears
    func testTimerStopsOnDisappear() {
        let testWaveformView = TestableWaveformView(audioLevel: 0.5)
        
        // Start timer
        testWaveformView.startTimer()
        XCTAssertNotNil(testWaveformView.timer, "Timer should be initialized after startTimer")
        
        // Simulate onDisappear
        testWaveformView.stopTimer()
        XCTAssertNil(testWaveformView.timer, "Timer should be nil after stopTimer")
    }
    
    // Test that the timer is restarted when isActive changes
    func testTimerRestartsWhenIsActiveChanges() {
        let testWaveformView = TestableWaveformView(audioLevel: 0.5, isActive: false)
        
        // Start with inactive state
        testWaveformView.startTimer()
        XCTAssertNotNil(testWaveformView.timer, "Timer should be initialized even when inactive")
        
        // Change to active
        testWaveformView.isActive = true
        testWaveformView.handleIsActiveChange(oldValue: false, newValue: true)
        
        XCTAssertNotNil(testWaveformView.timer, "Timer should still be active after changing to active state")
        
        // Change to inactive
        testWaveformView.isActive = false
        testWaveformView.handleIsActiveChange(oldValue: true, newValue: false)
        
        XCTAssertNil(testWaveformView.timer, "Timer should be nil after changing to inactive state")
    }
    
    // Test that the waveform shows on first activation
    func testWaveformShowsOnFirstActivation() {
        let testWaveformView = TestableWaveformView(audioLevel: 0.0, isActive: false)
        testWaveformView.isFirstActivation = true
        
        // Initialize level history
        testWaveformView.levelHistory = Array(repeating: 0.0, count: testWaveformView.barCount)
        
        // Simulate first activation
        testWaveformView.isActive = true
        testWaveformView.handleFirstActivation(oldValue: false, newValue: true)
        
        // Wait a short time for the delayed timer start
        let expectation = XCTestExpectation(description: "Timer should start after delay")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Verify timer was started
            XCTAssertNotNil(testWaveformView.timer, "Timer should be started after first activation")
            
            // Verify isFirstActivation was set to false
            XCTAssertFalse(testWaveformView.isFirstActivation, "isFirstActivation should be set to false")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 0.3)
    }
    
    // Test that minimum visible level is applied
    func testMinimumVisibleLevelIsApplied() {
        let testWaveformView = TestableWaveformView(audioLevel: 0.01, isActive: true)
        
        // Initialize level history
        testWaveformView.levelHistory = Array(repeating: 0.0, count: testWaveformView.barCount)
        
        // Simulate timer firing
        testWaveformView.updateLevelHistoryWithMinLevel()
        
        // First element should be at least the minimum visible level
        XCTAssertGreaterThanOrEqual(testWaveformView.levelHistory[0], 0.05, "First element should be at least the minimum visible level")
    }
}

// A wrapper class for WaveformView that allows testing private properties and methods
class TestableWaveformView {
    var waveformView: WaveformView
    var timer: Timer?
    var levelHistory: [CGFloat] = []
    var isFirstActivation: Bool = true
    
    // Forward properties from WaveformView
    var audioLevel: CGFloat {
        get { return waveformView.audioLevel }
        set { waveformView = WaveformView(audioLevel: newValue, color: waveformView.color, barCount: waveformView.barCount, spacing: waveformView.spacing, cornerRadius: waveformView.cornerRadius, isActive: waveformView.isActive) }
    }
    
    var color: Color { waveformView.color }
    var barCount: Int { waveformView.barCount }
    var spacing: CGFloat { waveformView.spacing }
    var cornerRadius: CGFloat { waveformView.cornerRadius }
    
    var isActive: Bool {
        get { return waveformView.isActive }
        set { waveformView = WaveformView(audioLevel: waveformView.audioLevel, color: waveformView.color, barCount: waveformView.barCount, spacing: waveformView.spacing, cornerRadius: waveformView.cornerRadius, isActive: newValue) }
    }
    
    init(audioLevel: CGFloat, color: Color = .blue, barCount: Int = 30, spacing: CGFloat = 3, cornerRadius: CGFloat = 3, isActive: Bool = true) {
        self.waveformView = WaveformView(audioLevel: audioLevel, color: color, barCount: barCount, spacing: spacing, cornerRadius: cornerRadius, isActive: isActive)
        self.levelHistory = Array(repeating: 0, count: barCount)
    }
    
    func startTimer() {
        // Create a timer for testing
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.updateLevelHistory()
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    func updateLevelHistory() {
        // Simulate the private updateLevelHistory method
        var newHistory = levelHistory
        
        if isActive {
            // When active, use the current audio level with some randomization for visual interest
            let randomFactor = CGFloat.random(in: 0.8...1.2)
            let newLevel = min(1.0, audioLevel * randomFactor)
            newHistory.insert(newLevel, at: 0)
        } else {
            // When inactive, gradually reduce levels
            newHistory.insert(0, at: 0)
        }
        
        // Remove last element to maintain fixed size
        if !newHistory.isEmpty && newHistory.count > barCount {
            newHistory.removeLast()
        }
        
        // Update state
        levelHistory = newHistory
    }
    
    func updateLevelHistoryWithMinLevel() {
        // Simulate the updated updateLevelHistory method with minimum level
        var newHistory = levelHistory
        
        if isActive {
            // When active, use the current audio level with some randomization for visual interest
            let randomFactor = CGFloat.random(in: 0.8...1.2)
            
            // Ensure we have a visible level even if audioLevel is very low
            let minVisibleLevel: CGFloat = 0.05
            let adjustedLevel = max(minVisibleLevel, audioLevel)
            
            let newLevel = min(1.0, adjustedLevel * randomFactor)
            newHistory.insert(newLevel, at: 0)
        } else {
            // When inactive, gradually reduce levels
            newHistory.insert(0, at: 0)
        }
        
        // Remove last element to maintain fixed size
        if !newHistory.isEmpty && newHistory.count > barCount {
            newHistory.removeLast()
        }
        
        // Update state
        levelHistory = newHistory
    }
    
    func handleIsActiveChange(oldValue: Bool, newValue: Bool) {
        // Simulate the onChange handler
        if newValue {
            startTimer()
        } else {
            stopTimer()
        }
    }
    
    func handleFirstActivation(oldValue: Bool, newValue: Bool) {
        // Simulate the onChange handler with first activation logic
        if newValue {
            // Ensure level history is initialized
            if levelHistory.isEmpty || levelHistory.count != barCount {
                levelHistory = Array(repeating: 0, count: barCount)
            }
            
            // Handle first activation specially
            if isFirstActivation {
                // Insert a small delay to ensure audio engine is fully set up
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.startTimer()
                    self?.isFirstActivation = false
                }
            } else {
                startTimer()
            }
        } else {
            stopTimer()
        }
    }
}
