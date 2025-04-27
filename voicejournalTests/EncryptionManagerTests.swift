//
//  EncryptionManagerTests.swift
//  voicejournalTests
//
//  Created on 4/27/25.
//

import XCTest
import CryptoKit
@testable import voicejournal

final class EncryptionManagerTests: XCTestCase {
    
    override func setUpWithError() throws {
        // Clean up any existing encryption key for testing
        // Note: In a real app, we would use a test-specific keychain or mock
    }
    
    override func tearDownWithError() throws {
        // Clean up after tests
    }
    
    // Test encryption key generation and storage
    func testEncryptionKeyGeneration() {
        // Generate a key
        let key = EncryptionManager.generateEncryptionKey()
        XCTAssertNotNil(key, "Should generate an encryption key")
        
        // Save the key
        let saveResult = EncryptionManager.saveEncryptionKey(key)
        XCTAssertTrue(saveResult, "Should successfully save the encryption key")
        
        // Retrieve the key
        let retrievedKey = EncryptionManager.getEncryptionKey()
        XCTAssertNotNil(retrievedKey, "Should retrieve the encryption key")
    }
    
    // Test string encryption and decryption
    func testStringEncryptionDecryption() {
        // Test string
        let originalString = "This is a secret message that needs to be encrypted."
        
        // Encrypt the string
        let encryptedData = EncryptionManager.encrypt(originalString)
        XCTAssertNotNil(encryptedData, "Should encrypt the string")
        
        // Decrypt the string
        let decryptedString = EncryptionManager.decryptToString(encryptedData!)
        XCTAssertNotNil(decryptedString, "Should decrypt the data")
        XCTAssertEqual(decryptedString, originalString, "Decrypted string should match the original")
    }
    
    // Test data encryption and decryption
    func testDataEncryptionDecryption() {
        // Test data
        let originalData = "Binary data for testing".data(using: .utf8)!
        
        // Encrypt the data
        let encryptedData = EncryptionManager.encrypt(originalData)
        XCTAssertNotNil(encryptedData, "Should encrypt the data")
        
        // Decrypt the data
        let decryptedData = EncryptionManager.decrypt(encryptedData!)
        XCTAssertNotNil(decryptedData, "Should decrypt the data")
        XCTAssertEqual(decryptedData, originalData, "Decrypted data should match the original")
    }
    
    // Test that encrypted data is different from original
    func testEncryptionChangesData() {
        // Test string
        let originalString = "This is a secret message."
        let originalData = originalString.data(using: .utf8)!
        
        // Encrypt the string
        let encryptedData = EncryptionManager.encrypt(originalString)!
        
        // Verify encrypted data is different
        XCTAssertNotEqual(encryptedData, originalData, "Encrypted data should be different from original data")
    }
    
    // Test encryption of empty string
    func testEncryptEmptyString() {
        // Empty string
        let emptyString = ""
        
        // Encrypt the empty string
        let encryptedData = EncryptionManager.encrypt(emptyString)
        XCTAssertNotNil(encryptedData, "Should encrypt an empty string")
        
        // Decrypt the string
        let decryptedString = EncryptionManager.decryptToString(encryptedData!)
        XCTAssertNotNil(decryptedString, "Should decrypt the data")
        XCTAssertEqual(decryptedString, emptyString, "Decrypted string should be empty")
    }
    
    // Test encryption of large data
    func testEncryptLargeData() {
        // Generate a large string (100KB)
        var largeString = ""
        for _ in 0..<100000 {
            largeString.append("A")
        }
        
        // Encrypt the large string
        let encryptedData = EncryptionManager.encrypt(largeString)
        XCTAssertNotNil(encryptedData, "Should encrypt a large string")
        
        // Decrypt the string
        let decryptedString = EncryptionManager.decryptToString(encryptedData!)
        XCTAssertNotNil(decryptedString, "Should decrypt the data")
        XCTAssertEqual(decryptedString, largeString, "Decrypted string should match the original large string")
    }
}
