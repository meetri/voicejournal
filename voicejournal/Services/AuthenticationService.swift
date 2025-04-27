//
//  AuthenticationService.swift
//  voicejournal
//
//  Created on 4/27/25.
//

import Foundation
import LocalAuthentication
import Combine

enum AuthenticationError: Error {
    case biometricsFailed
    case pinMismatch
    case pinTooShort
    case noFallbackAvailable
    case biometricsNotAvailable
    case biometricsNotEnrolled
    case unknown(Error)
    
    var localizedDescription: String {
        switch self {
        case .biometricsFailed:
            return "Biometric authentication failed"
        case .pinMismatch:
            return "PIN does not match"
        case .pinTooShort:
            return "PIN must be at least 4 digits"
        case .noFallbackAvailable:
            return "No fallback authentication method available"
        case .biometricsNotAvailable:
            return "Biometric authentication is not available on this device"
        case .biometricsNotEnrolled:
            return "Biometric authentication is not set up on this device"
        case .unknown(let error):
            return "Authentication error: \(error.localizedDescription)"
        }
    }
}

extension AuthenticationError: Equatable {
    static func == (lhs: AuthenticationError, rhs: AuthenticationError) -> Bool {
        switch (lhs, rhs) {
        case (.biometricsFailed, .biometricsFailed),
             (.pinMismatch, .pinMismatch),
             (.pinTooShort, .pinTooShort),
             (.noFallbackAvailable, .noFallbackAvailable),
             (.biometricsNotAvailable, .biometricsNotAvailable),
             (.biometricsNotEnrolled, .biometricsNotEnrolled):
            return true
        case (.unknown(let lhsError), .unknown(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

class AuthenticationService: ObservableObject {
    private let context = LAContext()
    private let keychainService = "com.voicejournal.pin"
    private let keychainAccount = "voicejournal"
    
    @Published var isAuthenticated = false
    @Published var authError: AuthenticationError?
    
    // Check if biometric authentication is available
    var biometricType: LABiometryType {
        var error: NSError?
        let _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        return context.biometryType
    }
    
    var biometricName: String {
        switch biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        default:
            return "Biometric Authentication"
        }
    }
    
    // Check if biometric authentication is available
    func canUseBiometrics() -> Bool {
        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        
        if let error = error {
            switch error.code {
            case LAError.biometryNotEnrolled.rawValue:
                authError = .biometricsNotEnrolled
            case LAError.biometryNotAvailable.rawValue:
                authError = .biometricsNotAvailable
            default:
                authError = .unknown(error)
            }
            return false
        }
        
        return canEvaluate
    }
    
    // Authenticate using biometrics
    func authenticateWithBiometrics(reason: String = "Unlock Voice Journal") async -> Bool {
        guard canUseBiometrics() else {
            return await authenticateWithPIN()
        }
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            
            await MainActor.run {
                self.isAuthenticated = success
                if !success {
                    self.authError = .biometricsFailed
                }
            }
            
            return success
        } catch {
            await MainActor.run {
                self.authError = .unknown(error)
                self.isAuthenticated = false
            }
            return false
        }
    }
    
    // Save PIN to keychain
    func savePin(_ pin: String) -> Bool {
        guard pin.count >= 4 else {
            authError = .pinTooShort
            return false
        }
        
        guard let data = pin.data(using: .utf8) else {
            return false
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data
        ]
        
        // Delete any existing PIN
        SecItemDelete(query as CFDictionary)
        
        // Add the new PIN
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    // Get PIN from keychain
    private func getPin() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        
        return nil
    }
    
    // Authenticate using PIN
    func authenticateWithPIN(enteredPin: String? = nil) async -> Bool {
        guard let storedPin = getPin() else {
            // No PIN set yet
            if let enteredPin = enteredPin, enteredPin.count >= 4 {
                let success = savePin(enteredPin)
                await MainActor.run {
                    self.isAuthenticated = success
                }
                return success
            }
            
            await MainActor.run {
                self.authError = .noFallbackAvailable
                self.isAuthenticated = false
            }
            return false
        }
        
        // If no PIN was entered, we need to prompt the user
        guard let enteredPin = enteredPin else {
            await MainActor.run {
                self.isAuthenticated = false
            }
            return false
        }
        
        let success = enteredPin == storedPin
        
        await MainActor.run {
            self.isAuthenticated = success
            if !success {
                self.authError = .pinMismatch
            }
        }
        
        return success
    }
    
    // Lock the app
    func lock() {
        isAuthenticated = false
    }
    
    // Check if PIN is set
    func isPinSet() -> Bool {
        return getPin() != nil
    }
}
