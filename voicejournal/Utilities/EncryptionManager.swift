//
//  EncryptionManager.swift
//  voicejournal
//
//  Created on 4/27/25.
//

import Foundation
import CryptoKit
import LocalAuthentication

class EncryptionManager {
    private static let keychainService = "com.voicejournal.encryption"
    private static let keychainAccount = "encryptionKey"
    
    // Generate a random encryption key
    static func generateEncryptionKey() -> SymmetricKey {
        return SymmetricKey(size: .bits256)
    }
    
    // Save encryption key to keychain
    static func saveEncryptionKey(_ key: SymmetricKey) -> Bool {
        let keyData = key.withUnsafeBytes { Data($0) }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: keyData
        ]
        
        // Delete any existing key
        SecItemDelete(query as CFDictionary)
        
        // Add the new key
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    // Get encryption key from keychain
    static func getEncryptionKey() -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
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
        if saveEncryptionKey(newKey) {
            return newKey
        }
        
        return nil
    }
    
    // Encrypt data
    static func encrypt(_ data: Data) -> Data? {
        guard let key = getEncryptionKey() else {
            return nil
        }
        
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            return sealedBox.combined
        } catch {
            print("Encryption error: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Decrypt data
    static func decrypt(_ encryptedData: Data) -> Data? {
        guard let key = getEncryptionKey() else {
            return nil
        }
        
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            print("Decryption error: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Encrypt string
    static func encrypt(_ string: String) -> Data? {
        guard let data = string.data(using: .utf8) else {
            return nil
        }
        
        return encrypt(data)
    }
    
    // Decrypt to string
    static func decryptToString(_ encryptedData: Data) -> String? {
        guard let decryptedData = decrypt(encryptedData) else {
            return nil
        }
        
        return String(data: decryptedData, encoding: .utf8)
    }
}
