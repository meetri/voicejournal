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
    
    // MARK: - Concurrency
    
    /// Background queue for cryptographic operations
    private static let cryptoQueue = DispatchQueue(
        label: "com.voicejournal.crypto-operations",
        qos: .userInitiated,
        attributes: .concurrent
    )
    
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
    
    // MARK: - Synchronous Methods (legacy)
    
    /// Encrypt data with the app's default key (synchronous)
    static func encrypt(_ data: Data) -> Data? {
        guard let key = getEncryptionKey() else {
            return nil
        }
        
        return encrypt(data, using: key)
    }
    
    /// Encrypt data with a specific key (synchronous)
    static func encrypt(_ data: Data, using key: SymmetricKey) -> Data? {
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            return sealedBox.combined
        } catch {
            // Error occurred")
            return nil
        }
    }
    
    /// Decrypt data with the app's default key (synchronous)
    static func decrypt(_ encryptedData: Data) -> Data? {
        guard let key = getEncryptionKey() else {
            return nil
        }
        
        return decrypt(encryptedData, using: key)
    }
    
    /// Decrypt data with a specific key (synchronous)
    static func decrypt(_ encryptedData: Data, using key: SymmetricKey) -> Data? {
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            // Error occurred")
            return nil
        }
    }
    
    /// Encrypt a string using the app's default key (synchronous)
    static func encrypt(_ string: String) -> Data? {
        guard let data = string.data(using: .utf8) else {
            return nil
        }
        
        return encrypt(data)
    }
    
    /// Encrypt a string using a specific key (synchronous)
    static func encrypt(_ string: String, using key: SymmetricKey) -> Data? {
        guard let data = string.data(using: .utf8) else {
            return nil
        }
        
        return encrypt(data, using: key)
    }
    
    /// Decrypt data to a string using the app's default key (synchronous)
    static func decryptToString(_ encryptedData: Data) -> String? {
        guard let decryptedData = decrypt(encryptedData) else {
            return nil
        }
        
        return String(data: decryptedData, encoding: .utf8)
    }
    
    /// Decrypt data to a string using a specific key (synchronous)
    static func decryptToString(_ encryptedData: Data, using key: SymmetricKey) -> String? {
        guard let decryptedData = decrypt(encryptedData, using: key) else {
            return nil
        }
        
        return String(data: decryptedData, encoding: .utf8)
    }
    
    // MARK: - Asynchronous Methods with Completion Handlers
    
    /// Encrypt data with the app's default key (asynchronous)
    static func encryptAsync(_ data: Data, completion: @escaping (Data?) -> Void) {
        cryptoQueue.async {
            let encryptedData = encrypt(data)
            DispatchQueue.main.async {
                completion(encryptedData)
            }
        }
    }
    
    /// Encrypt data with a specific key (asynchronous)
    static func encryptAsync(_ data: Data, using key: SymmetricKey, completion: @escaping (Data?) -> Void) {
        cryptoQueue.async {
            let encryptedData = encrypt(data, using: key)
            DispatchQueue.main.async {
                completion(encryptedData)
            }
        }
    }
    
    /// Decrypt data with the app's default key (asynchronous)
    static func decryptAsync(_ encryptedData: Data, completion: @escaping (Data?) -> Void) {
        cryptoQueue.async {
            let decryptedData = decrypt(encryptedData)
            DispatchQueue.main.async {
                completion(decryptedData)
            }
        }
    }
    
    /// Decrypt data with a specific key (asynchronous)
    static func decryptAsync(_ encryptedData: Data, using key: SymmetricKey, completion: @escaping (Data?) -> Void) {
        cryptoQueue.async {
            do {
                let startTime = Date()
                let decryptedData = decrypt(encryptedData, using: key)
                let duration = Date().timeIntervalSince(startTime)
                
                if let decryptedData = decryptedData {
                    print("✅ [EncryptionManager.decryptAsync] Successfully decrypted \(encryptedData.count) bytes in \(String(format: "%.2f", duration))s - result: \(decryptedData.count) bytes")
                } else {
                    print("❌ [EncryptionManager.decryptAsync] Failed to decrypt \(encryptedData.count) bytes after \(String(format: "%.2f", duration))s")
                }
                
                DispatchQueue.main.async {
                    completion(decryptedData)
                }
            } catch {
                print("❌ [EncryptionManager.decryptAsync] Error during decryption: \(error)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    /// Encrypt a string using the app's default key (asynchronous)
    static func encryptAsync(_ string: String, completion: @escaping (Data?) -> Void) {
        guard let data = string.data(using: .utf8) else {
            completion(nil)
            return
        }
        
        encryptAsync(data, completion: completion)
    }
    
    /// Encrypt a string using a specific key (asynchronous)
    static func encryptAsync(_ string: String, using key: SymmetricKey, completion: @escaping (Data?) -> Void) {
        guard let data = string.data(using: .utf8) else {
            completion(nil)
            return
        }
        
        encryptAsync(data, using: key, completion: completion)
    }
    
    /// Decrypt data to a string using the app's default key (asynchronous)
    static func decryptToStringAsync(_ encryptedData: Data, completion: @escaping (String?) -> Void) {
        decryptAsync(encryptedData) { decryptedData in
            guard let data = decryptedData else {
                completion(nil)
                return
            }
            
            let string = String(data: data, encoding: .utf8)
            completion(string)
        }
    }
    
    /// Decrypt data to a string using a specific key (asynchronous)
    static func decryptToStringAsync(_ encryptedData: Data, using key: SymmetricKey, completion: @escaping (String?) -> Void) {
        decryptAsync(encryptedData, using: key) { decryptedData in
            guard let data = decryptedData else {
                completion(nil)
                return
            }
            
            let string = String(data: data, encoding: .utf8)
            completion(string)
        }
    }
    
    // MARK: - Swift Concurrency (async/await)
    
    /// Encrypt data with the app's default key (async/await)
    static func encryptAsync(_ data: Data) async -> Data? {
        await withCheckedContinuation { continuation in
            encryptAsync(data) { result in
                continuation.resume(returning: result)
            }
        }
    }
    
    /// Encrypt data with a specific key (async/await)
    static func encryptAsync(_ data: Data, using key: SymmetricKey) async -> Data? {
        await withCheckedContinuation { continuation in
            encryptAsync(data, using: key) { result in
                continuation.resume(returning: result)
            }
        }
    }
    
    /// Decrypt data with the app's default key (async/await)
    static func decryptAsync(_ encryptedData: Data) async -> Data? {
        await withCheckedContinuation { continuation in
            decryptAsync(encryptedData) { result in
                continuation.resume(returning: result)
            }
        }
    }
    
    /// Decrypt data with a specific key (async/await)
    static func decryptAsync(_ encryptedData: Data, using key: SymmetricKey) async -> Data? {
        await withCheckedContinuation { continuation in
            decryptAsync(encryptedData, using: key) { result in
                continuation.resume(returning: result)
            }
        }
    }
    
    /// Encrypt a string using the app's default key (async/await)
    static func encryptAsync(_ string: String) async -> Data? {
        guard let data = string.data(using: .utf8) else {
            return nil
        }
        
        return await encryptAsync(data)
    }
    
    /// Encrypt a string using a specific key (async/await)
    static func encryptAsync(_ string: String, using key: SymmetricKey) async -> Data? {
        guard let data = string.data(using: .utf8) else {
            return nil
        }
        
        return await encryptAsync(data, using: key)
    }
    
    /// Decrypt data to a string using the app's default key (async/await)
    static func decryptToStringAsync(_ encryptedData: Data) async -> String? {
        guard let decryptedData = await decryptAsync(encryptedData) else {
            return nil
        }
        
        return String(data: decryptedData, encoding: .utf8)
    }
    
    /// Decrypt data to a string using a specific key (async/await)
    static func decryptToStringAsync(_ encryptedData: Data, using key: SymmetricKey) async -> String? {
        guard let decryptedData = await decryptAsync(encryptedData, using: key) else {
            return nil
        }
        
        return String(data: decryptedData, encoding: .utf8)
    }
}