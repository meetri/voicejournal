//
//  TranscriptionHighlightingTests.swift
//  voicejournalTests
//
//  Created on 4/27/25.
//

import XCTest
import CoreData
@testable import voicejournal

class TranscriptionHighlightingTests: XCTestCase {
    
    // MARK: - TranscriptionSegment Tests
    
    func testTranscriptionSegmentInitialization() {
        // Create a segment with all properties
        let segment = TranscriptionSegment(
            text: "Hello world",
            startTime: 10.5,
            endTime: 12.0,
            range: NSRange(location: 0, length: 11)
        )
        
        // Verify properties
        XCTAssertEqual(segment.text, "Hello world")
        XCTAssertEqual(segment.startTime, 10.5)
        XCTAssertEqual(segment.endTime, 12.0)
        XCTAssertEqual(segment.textRange.location, 0)
        XCTAssertEqual(segment.textRange.length, 11)
    }
    
    func testTranscriptionSegmentCoding() throws {
        // Create a segment
        let originalSegment = TranscriptionSegment(
            text: "Test segment",
            startTime: 5.0,
            endTime: 7.5,
            range: NSRange(location: 20, length: 12)
        )
        
        // Encode to JSON
        let encoder = JSONEncoder()
        let data = try encoder.encode([originalSegment])
        
        // Decode from JSON
        let decoder = JSONDecoder()
        let decodedSegments = try decoder.decode([TranscriptionSegment].self, from: data)
        
        // Verify decoded segment
        XCTAssertEqual(decodedSegments.count, 1)
        let decodedSegment = decodedSegments[0]
        
        XCTAssertEqual(decodedSegment.text, originalSegment.text)
        XCTAssertEqual(decodedSegment.startTime, originalSegment.startTime)
        XCTAssertEqual(decodedSegment.endTime, originalSegment.endTime)
        XCTAssertEqual(decodedSegment.textRange.location, originalSegment.textRange.location)
        XCTAssertEqual(decodedSegment.textRange.length, originalSegment.textRange.length)
    }
    
    // MARK: - SpeechRecognitionService Timing Data Tests
    
    func testGetTimingDataJSON() {
        // Create a mock SpeechRecognitionService
        let service = SpeechRecognitionService()
        
        // Set test timing data using internal method for testing
        let segment1 = TranscriptionSegment(text: "Hello", startTime: 0.0, endTime: 1.0, range: NSRange(location: 0, length: 5))
        let segment2 = TranscriptionSegment(text: "world", startTime: 1.5, endTime: 2.0, range: NSRange(location: 6, length: 5))
        service.setTimingDataForTesting([segment1, segment2])
        
        // Get JSON string
        let jsonString = service.getTimingDataJSON()
        
        // Verify JSON string is not nil
        XCTAssertNotNil(jsonString)
        
        // Verify JSON can be parsed back to segments
        if let jsonData = jsonString?.data(using: .utf8) {
            do {
                let decoder = JSONDecoder()
                let decodedSegments = try decoder.decode([TranscriptionSegment].self, from: jsonData)
                
                // Verify decoded segments
                XCTAssertEqual(decodedSegments.count, 2)
                XCTAssertEqual(decodedSegments[0].text, "Hello")
                XCTAssertEqual(decodedSegments[1].text, "world")
            } catch {
                XCTFail("Failed to decode JSON: \(error)")
            }
        } else {
            XCTFail("Failed to convert JSON string to data")
        }
    }
    
    // MARK: - AudioPlaybackViewModel Highlighting Tests
    
    func testUpdateHighlightedTextRange() {
        // Create a mock AudioPlaybackViewModel
        let playbackService = AudioPlaybackService()
        let viewModel = AudioPlaybackViewModel(playbackService: playbackService)
        
        // Set up test timing data
        let segment1 = TranscriptionSegment(text: "First segment", startTime: 0.0, endTime: 5.0, range: NSRange(location: 0, length: 13))
        let segment2 = TranscriptionSegment(text: "Second segment", startTime: 5.5, endTime: 10.0, range: NSRange(location: 14, length: 14))
        let segment3 = TranscriptionSegment(text: "Third segment", startTime: 11.0, endTime: 15.0, range: NSRange(location: 29, length: 13))
        
        // Set timing data using internal method for testing
        viewModel.setTranscriptionTimingDataForTesting([segment1, segment2, segment3])
        
        // Test with current time in first segment
        viewModel.setCurrentTimeForTesting(3.0)
        viewModel.updateHighlightedTextRangeForTesting()
        XCTAssertNotNil(viewModel.currentHighlightRange)
        XCTAssertEqual(viewModel.currentHighlightRange?.location, 0)
        XCTAssertEqual(viewModel.currentHighlightRange?.length, 13)
        
        // Test with current time in second segment
        viewModel.setCurrentTimeForTesting(7.5)
        viewModel.updateHighlightedTextRangeForTesting()
        XCTAssertNotNil(viewModel.currentHighlightRange)
        XCTAssertEqual(viewModel.currentHighlightRange?.location, 14)
        XCTAssertEqual(viewModel.currentHighlightRange?.length, 14)
        
        // Test with current time between segments (should return nil)
        viewModel.setCurrentTimeForTesting(10.5)
        viewModel.updateHighlightedTextRangeForTesting()
        XCTAssertNil(viewModel.currentHighlightRange)
        
        // Test with current time after all segments
        viewModel.setCurrentTimeForTesting(20.0)
        viewModel.updateHighlightedTextRangeForTesting()
        XCTAssertNil(viewModel.currentHighlightRange)
    }
    
    // MARK: - HighlightableText Tests
    
    func testHighlightableTextValidation() {
        // Create a test string
        let text = "This is a test string for highlighting"
        
        // Test with valid range
        let validRange = NSRange(location: 10, length: 4)
        let validResult = validateHighlightRange(validRange, in: text)
        XCTAssertEqual(validResult.location, 10)
        XCTAssertEqual(validResult.length, 4)
        
        // Test with range extending beyond text length
        let overflowRange = NSRange(location: 30, length: 10)
        let overflowResult = validateHighlightRange(overflowRange, in: text)
        XCTAssertEqual(overflowResult.location, 30)
        XCTAssertEqual(overflowResult.length, 5) // Should be truncated to text length
        
        // Test with invalid location
        let invalidRange = NSRange(location: 50, length: 5)
        let invalidResult = validateHighlightRange(invalidRange, in: text)
        XCTAssertEqual(invalidResult.location, 0)
        XCTAssertEqual(invalidResult.length, 0) // Should return empty range
        
        // Test with NSNotFound
        let notFoundRange = NSRange(location: NSNotFound, length: 5)
        let notFoundResult = validateHighlightRange(notFoundRange, in: text)
        XCTAssertEqual(notFoundResult.location, 0)
        XCTAssertEqual(notFoundResult.length, 0) // Should return empty range
    }
    
    // Helper function to simulate HighlightableText's range validation
    private func validateHighlightRange(_ range: NSRange, in text: String) -> NSRange {
        let nsText = text as NSString
        
        // If the range is invalid or out of bounds, return an empty range
        if range.location == NSNotFound || range.location >= nsText.length {
            return NSRange(location: 0, length: 0)
        }
        
        // Ensure the range doesn't extend beyond the text length
        let maxLength = nsText.length - range.location
        let validLength = min(range.length, maxLength)
        
        return NSRange(location: range.location, length: validLength)
    }
}

// MARK: - Extensions for Testing

extension SpeechRecognitionService {
    /// Set timing data for testing
    @MainActor
    func setTimingDataForTesting(_ segments: [TranscriptionSegment]) {
        self.timingData = segments
    }
}

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
