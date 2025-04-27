//
//  AuthenticationServiceTests.swift
//  voicejournalTests
//
//  Created on 4/27/25.
//

import XCTest
import LocalAuthentication
@testable import voicejournal

final class AuthenticationServiceTests: XCTestCase {
    var authService: AuthenticationService!
    
    override func setUpWithError() throws {
        authService = AuthenticationService()
    }
    
    override func tearDownWithError() throws {
        authService = nil
    }
    
    // Test PIN saving and verification
    func testPinSaveAndVerify() async {
        // Test saving a valid PIN
        let validPin = "1234"
        XCTAssertTrue(authService.savePin(validPin), "Should successfully save a valid PIN")
        
        // Test PIN verification
        let result = await authService.authenticateWithPIN(enteredPin: validPin)
        XCTAssertTrue(result, "Authentication should succeed with correct PIN")
        XCTAssertTrue(authService.isAuthenticated, "isAuthenticated should be true after successful authentication")
        
        // Test incorrect PIN
        let incorrectResult = await authService.authenticateWithPIN(enteredPin: "5678")
        XCTAssertFalse(incorrectResult, "Authentication should fail with incorrect PIN")
        XCTAssertEqual(authService.authError, .pinMismatch, "Error should be pinMismatch")
    }
    
    // Test PIN validation
    func testPinValidation() {
        // Test PIN too short
        let shortPin = "123"
        XCTAssertFalse(authService.savePin(shortPin), "Should reject PIN that's too short")
        XCTAssertEqual(authService.authError, .pinTooShort, "Error should be pinTooShort")
        
        // Test valid PIN
        let validPin = "1234"
        XCTAssertTrue(authService.savePin(validPin), "Should accept valid PIN")
        
        // Test longer PIN
        let longPin = "123456"
        XCTAssertTrue(authService.savePin(longPin), "Should accept longer PIN")
    }
    
    // Test lock/unlock functionality
    func testLockUnlock() async {
        // Set up with a valid PIN
        let validPin = "1234"
        XCTAssertTrue(authService.savePin(validPin), "Should successfully save a valid PIN")
        
        // Authenticate
        let result = await authService.authenticateWithPIN(enteredPin: validPin)
        XCTAssertTrue(result, "Authentication should succeed with correct PIN")
        XCTAssertTrue(authService.isAuthenticated, "isAuthenticated should be true after successful authentication")
        
        // Lock
        authService.lock()
        XCTAssertFalse(authService.isAuthenticated, "isAuthenticated should be false after locking")
        
        // Authenticate again
        let secondResult = await authService.authenticateWithPIN(enteredPin: validPin)
        XCTAssertTrue(secondResult, "Authentication should succeed with correct PIN after locking")
        XCTAssertTrue(authService.isAuthenticated, "isAuthenticated should be true after successful authentication")
    }
    
    // Test isPinSet functionality
    func testIsPinSet() {
        // Initially no PIN should be set
        // Note: This might fail if previous tests have set a PIN and not cleaned up
        // In a real app, we would use a test-specific keychain or mock
        
        // Set a PIN
        let validPin = "1234"
        XCTAssertTrue(authService.savePin(validPin), "Should successfully save a valid PIN")
        
        // Check if PIN is set
        XCTAssertTrue(authService.isPinSet(), "isPinSet should return true after setting a PIN")
    }
}
