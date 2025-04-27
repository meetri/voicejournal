//
//  AuthenticationView.swift
//  voicejournal
//
//  Created on 4/27/25.
//

import SwiftUI
import LocalAuthentication

struct AuthenticationView: View {
    @EnvironmentObject private var authService: AuthenticationService
    @State private var pin = ""
    @State private var confirmPin = ""
    @State private var isSettingPin = false
    @State private var showPinInput = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()
                
                Image(systemName: "lock.shield")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .foregroundColor(.blue)
                
                Text("Voice Journal")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Your secure audio journaling app")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if showPinInput {
                    pinInputView
                } else {
                    biometricButton
                }
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.callout)
                }
                
                Spacer()
            }
            .padding()
            .navigationBarHidden(true)
            .onAppear {
                checkAuthentication()
            }
        }
    }
    
    private var biometricButton: some View {
        Button(action: {
            authenticate()
        }) {
            HStack {
                Image(systemName: authService.biometricType == .faceID ? "faceid" : "touchid")
                Text("Unlock with \(authService.biometricName)")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding(.horizontal)
        .padding(.bottom)
        .buttonStyle(PlainButtonStyle())
        .overlay(
            Button("Use PIN") {
                showPinInput = true
            }
            .padding(.top, 60)
            .font(.caption)
            .foregroundColor(.blue)
        )
    }
    
    private var pinInputView: some View {
        VStack(spacing: 20) {
            if isSettingPin {
                Text("Create a PIN")
                    .font(.headline)
                
                SecureField("Enter PIN (minimum 4 digits)", text: $pin)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                
                SecureField("Confirm PIN", text: $confirmPin)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                
                Button("Set PIN") {
                    setPin()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(pin.count < 4 || pin != confirmPin)
            } else {
                Text("Enter PIN")
                    .font(.headline)
                
                SecureField("PIN", text: $pin)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                
                Button("Unlock") {
                    verifyPin()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(pin.count < 4)
            }
            
            Button(isSettingPin ? "Cancel" : "Use \(authService.biometricName)") {
                if isSettingPin {
                    isSettingPin = false
                    pin = ""
                    confirmPin = ""
                } else {
                    showPinInput = false
                    pin = ""
                }
            }
            .foregroundColor(.blue)
        }
        .padding(.horizontal)
    }
    
    private func checkAuthentication() {
        Task {
            if !authService.isPinSet() {
                isSettingPin = true
                showPinInput = true
            } else if authService.canUseBiometrics() {
                // Show biometric button by default
                showPinInput = false
            } else {
                // Fall back to PIN
                showPinInput = true
            }
        }
    }
    
    private func authenticate() {
        errorMessage = ""
        
        Task {
            if await authService.authenticateWithBiometrics() {
                // Authentication successful, proceed to main app
                // This will be handled by the app's navigation
            } else if let error = authService.authError {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func setPin() {
        guard pin.count >= 4 else {
            errorMessage = "PIN must be at least 4 digits"
            return
        }
        
        guard pin == confirmPin else {
            errorMessage = "PINs do not match"
            return
        }
        
        if authService.savePin(pin) {
            isSettingPin = false
            pin = ""
            confirmPin = ""
            errorMessage = ""
            
            // Authenticate with the newly set PIN
            Task {
                _ = await authService.authenticateWithPIN()
            }
        } else {
            errorMessage = "Failed to save PIN"
        }
    }
    
    private func verifyPin() {
        Task {
            if await authService.authenticateWithPIN(enteredPin: pin) {
                // Authentication successful, proceed to main app
                // This will be handled by the app's navigation
            } else if let error = authService.authError {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(AuthenticationService())
}
