//
//  SpeechRecognitionServiceTests.swift
//  voicejournalTests
//
//  Created on 4/27/25.
//

import XCTest
import Speech
@testable import voicejournal

final class SpeechRecognitionServiceTests: XCTestCase {
    
    var speechRecognitionService: SpeechRecognitionService!
    
    override func setUpWithError() throws {
        speechRecognitionService = SpeechRecognitionService()
    }
    
    override func tearDownWithError() throws {
        speechRecognitionService = nil
    }
    
    func testInitialState() {
        // Test initial state of the service
        XCTAssertEqual(speechRecognitionService.transcription, "")
        XCTAssertEqual(speechRecognitionService.interimTranscription, "")
        XCTAssertEqual(speechRecognitionService.progress, 0.0)
    }
    
    func testCurrentTranscription() {
        // Test with only final transcription
        speechRecognitionService.setTranscriptionForTesting("Hello world")
        XCTAssertEqual(speechRecognitionService.currentTranscription, "Hello world")
        
        // Test with only interim transcription
        speechRecognitionService.setTranscriptionForTesting("")
        speechRecognitionService.setInterimTranscriptionForTesting("Testing")
        XCTAssertEqual(speechRecognitionService.currentTranscription, "Testing")
        
        // Test with both final and interim transcription
        speechRecognitionService.setTranscriptionForTesting("Hello")
        speechRecognitionService.setInterimTranscriptionForTesting(" world")
        XCTAssertEqual(speechRecognitionService.currentTranscription, "Hello world")
    }
    
    func testReset() {
        // Set some values
        speechRecognitionService.setTranscriptionForTesting("Hello world")
        speechRecognitionService.setInterimTranscriptionForTesting("Testing")
        speechRecognitionService.setProgressForTesting(0.5)
        speechRecognitionService.setStateForTesting(.recognizing)
        
        // Reset the service
        speechRecognitionService.reset()
        
        // Verify reset state
        XCTAssertEqual(speechRecognitionService.transcription, "")
        XCTAssertEqual(speechRecognitionService.interimTranscription, "")
        XCTAssertEqual(speechRecognitionService.progress, 0.0)
        
        // Check if state is reset to ready
        // We need to use a different approach since state is private
        // For this test, we'll just verify that it's not in recognizing state anymore
        switch speechRecognitionService.state {
        case .recognizing:
            XCTFail("State should not be recognizing after reset")
        default:
            break
        }
    }
    
    func testCheckAuthorization() {
        // This test depends on the current authorization status
        // We can only verify that it returns a valid permission value
        let permission = speechRecognitionService.checkAuthorization()
        XCTAssertTrue(
            permission == .granted ||
            permission == .denied ||
            permission == .restricted ||
            permission == .notDetermined
        )
    }
    
    func testSpeechRecognitionError() {
        // Test error descriptions
        let authError = SpeechRecognitionError.authorizationFailed
        XCTAssertEqual(authError.localizedDescription, "Speech recognition authorization failed")
        
        let recognitionError = SpeechRecognitionError.recognitionFailed
        XCTAssertEqual(recognitionError.localizedDescription, "Speech recognition failed")
        
        let formatError = SpeechRecognitionError.audioFormatNotSupported
        XCTAssertEqual(formatError.localizedDescription, "Audio format not supported for speech recognition")
        
        let availabilityError = SpeechRecognitionError.noRecognitionAvailable
        XCTAssertEqual(availabilityError.localizedDescription, "Speech recognition is not available on this device")
        
        let fileError = SpeechRecognitionError.fileNotFound
        XCTAssertEqual(fileError.localizedDescription, "Audio file not found")
        
        let testError = NSError(domain: "test", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        let unknownError = SpeechRecognitionError.unknown(testError)
        XCTAssertEqual(unknownError.localizedDescription, "Unknown error: Test error")
    }
    
    // Note: We can't easily test the actual speech recognition functionality in unit tests
    // because it requires real audio input and authorization. Those would be better tested
    // in UI tests or manual testing.
}
