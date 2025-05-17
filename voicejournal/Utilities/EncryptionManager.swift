//
//  EncryptionManager.swift
//  voicejournal
//
//  Created on 4/27/25.
//

import Foundation
import CryptoKit
import LocalAuthentication
import CommonCrypto

class EncryptionManager {
    // MARK: - Constants
    
    private static let keychainService = "com.voicejournal.encryption"
    private static let keychainAccount = "encryptionKey"
    private static let rootKeyAccount = "rootEncryptionKey"
    private static let tagKeychainPrefix = "tagEncryptionKey_"
    
    // MARK: - Default Encryption Key Methods
    
    /// Generate a random encryption key
    static func generateEncryptionKey() -> SymmetricKey {
        return SymmetricKey(size: .bits256)
    }
    
    /// Save the app's default encryption key to keychain (legacy - use saveRootEncryptionKey instead)
    static func saveEncryptionKey(_ key: SymmetricKey) -> Bool {
        return saveRootEncryptionKey(key)
    }
    
    /// Get the app's default encryption key from keychain (legacy - use getRootEncryptionKey instead)
    static func getEncryptionKey() -> SymmetricKey? {
        return getRootEncryptionKey()
    }
    
    /// Save the app's root encryption key to keychain
    static func saveRootEncryptionKey(_ key: SymmetricKey) -> Bool {
        let keyData = key.withUnsafeBytes { Data($0) }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: rootKeyAccount,
            kSecValueData as String: keyData
        ]
        
        // Delete any existing key
        SecItemDelete(query as CFDictionary)
        
        // Add the new key
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Get the app's root encryption key from keychain
    static func getRootEncryptionKey() -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: rootKeyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let keyData = dataTypeRef as? Data {
            return SymmetricKey(data: keyData)
        }
        
        // If no key exists, generate and save a new one
        let newKey = generateEncryptionKey()
        if saveRootEncryptionKey(newKey) {
            return newKey
        }
        
        return nil
    }
    
    /// Get the app's root encryption key with biometric authentication
    static func getRootEncryptionKeyWithBiometrics(completion: @escaping (SymmetricKey?) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        // Check if biometric authentication is available
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Unlock your journal entries"
            
            // Request biometric authentication
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authError in
                DispatchQueue.main.async {
                    if success {
                        // Return the root key on successful authentication
                        completion(getRootEncryptionKey())
                    } else {
                        // Error occurred)")
                        completion(nil)
                    }
                }
            }
        } else {
            // Error occurred)")
            // Fall back to getting the key without biometrics
            completion(getRootEncryptionKey())
        }
    }
    
    // MARK: - Tag-specific Encryption Key Methods
    
    /// Generate a key identifier for a tag
    static func generateKeyIdentifier(for tagID: String) -> String {
        return "\(tagKeychainPrefix)\(tagID)"
    }
    
    /// Generate an encryption key for a tag based on the PIN
    static func generateEncryptionKey(from pin: String, salt: Data) -> SymmetricKey {
        guard let pinData = pin.data(using: .utf8) else {
            // Fallback to a random key if PIN conversion fails
            return generateEncryptionKey()
        }
        
        // Derive a key from the PIN using PBKDF2
        let keyLength = 32 // 256 bits
        var derivedKeyData = Data(repeating: 0, count: keyLength)
        
        _ = derivedKeyData.withUnsafeMutableBytes { derivedKeyBytes in
            pinData.withUnsafeBytes { pinBytes in
                salt.withUnsafeBytes { saltBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        pinBytes.baseAddress, pinBytes.count,
                        saltBytes.baseAddress, saltBytes.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        10000, // Iterations
                        derivedKeyBytes.baseAddress, derivedKeyBytes.count
                    )
                }
            }
        }
        
        return SymmetricKey(data: derivedKeyData)
    }
    
    /// Save a tag's encryption key to keychain
    static func saveTagEncryptionKey(_ key: SymmetricKey, for keyIdentifier: String) -> Bool {
        let keyData = key.withUnsafeBytes { Data($0) }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keyIdentifier,
            kSecValueData as String: keyData
        ]
        
        // Delete any existing key
        SecItemDelete(query as CFDictionary)
        
        // Add the new key
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Get a tag's encryption key from keychain
    static func getTagEncryptionKey(for keyIdentifier: String) -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keyIdentifier,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let keyData = dataTypeRef as? Data {
            return SymmetricKey(data: keyData)
        }
        
        return nil
    }
    
    /// Delete a tag's encryption key from keychain
    static func deleteTagEncryptionKey(for keyIdentifier: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keyIdentifier
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - PIN Hashing and Verification
    
    /// Generate a random salt for PIN hashing
    static func generateSalt() -> Data {
        var randomBytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        return Data(randomBytes)
    }
    
    /// Hash the PIN with a provided salt
    static func hashPin(_ pin: String, salt: Data) -> String? {
        guard let pinData = pin.data(using: .utf8) else {
            return nil
        }
        
        var hashData = Data(repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        var saltedPinData = pinData
        saltedPinData.append(salt)
        
        _ = hashData.withUnsafeMutableBytes { hashBytes in
            saltedPinData.withUnsafeBytes { saltedPinBytes in
                CC_SHA256(saltedPinBytes.baseAddress, CC_LONG(saltedPinData.count), hashBytes.baseAddress?.assumingMemoryBound(to: UInt8.self))
            }
        }
        
        return hashData.base64EncodedString()
    }
    
    /// Verify if a PIN matches the stored hash
    static func verifyPin(_ pin: String, against hashedPin: String, salt: Data) -> Bool {
        guard let calculatedHash = hashPin(pin, salt: salt) else {
            return false
        }
        
        return calculatedHash == hashedPin
    }
    
    // MARK: - Encryption / Decryption Methods
    
    /// Encrypt data with the app's default key
    static func encrypt(_ data: Data) -> Data? {
        guard let key = getEncryptionKey() else {
            return nil
        }
        
        return encrypt(data, using: key)
    }
    
    /// Encrypt data with a specific key
    static func encrypt(_ data: Data, using key: SymmetricKey) -> Data? {
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            return sealedBox.combined
        } catch {
            // Error occurred")
            return nil
        }
    }
    
    /// Decrypt data with the app's default key
    static func decrypt(_ encryptedData: Data) -> Data? {
        guard let key = getEncryptionKey() else {
            return nil
        }
        
        return decrypt(encryptedData, using: key)
    }
    
    /// Decrypt data with a specific key
    static func decrypt(_ encryptedData: Data, using key: SymmetricKey) -> Data? {
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            // Error occurred")
            return nil
        }
    }
    
    /// Encrypt a string using the app's default key
    static func encrypt(_ string: String) -> Data? {
        guard let data = string.data(using: .utf8) else {
            return nil
        }
        
        return encrypt(data)
    }
    
    /// Encrypt a string using a specific key
    static func encrypt(_ string: String, using key: SymmetricKey) -> Data? {
        guard let data = string.data(using: .utf8) else {
            return nil
        }
        
        return encrypt(data, using: key)
    }
    
    /// Decrypt data to a string using the app's default key
    static func decryptToString(_ encryptedData: Data) -> String? {
        guard let decryptedData = decrypt(encryptedData) else {
            return nil
        }
        
        return String(data: decryptedData, encoding: .utf8)
    }
    
    /// Decrypt data to a string using a specific key
    static func decryptToString(_ encryptedData: Data, using key: SymmetricKey) -> String? {
        guard let decryptedData = decrypt(encryptedData, using: key) else {
            return nil
        }
        
        return String(data: decryptedData, encoding: .utf8)
    }
}