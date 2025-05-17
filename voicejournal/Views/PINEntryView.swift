//
//  PINEntryView.swift
//  voicejournal
//
//  Created on 5/4/25.
//

import SwiftUI

/// A view for entering PIN codes with visual feedback and validation
/// Used for encrypted tag PIN entry, verification, and changing
struct PINEntryView: View {
    // MARK: - Properties
    
    /// The action to perform when PIN is submitted
    var onSubmit: (String) -> Void
    
    /// The title of the view
    var title: String
    
    /// The message to display below the title
    var message: String
    
    /// The action to perform when cancel is pressed
    var onCancel: () -> Void
    
    /// The minimum PIN length (default is 4)
    var minPINLength: Int = 4
    
    /// Display a confirmation field for new PINs
    var requireConfirmation: Bool = false
    
    /// The action button text (default is "Submit")
    var actionButtonText: String = "Submit"
    
    // MARK: - State
    
    @State private var pin: String = ""
    @State private var confirmPin: String = ""
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var isSecure: Bool = true
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text(title)
                .font(.headline)
                .padding(.top)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Error message
            if showError {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .padding(.horizontal)
                    .transition(.opacity)
            }
            
            // PIN Fields
            VStack(spacing: 16) {
                pinField(pin: $pin, label: "Enter PIN", placeholder: "• • • •")
                
                if requireConfirmation {
                    pinField(pin: $confirmPin, label: "Confirm PIN", placeholder: "• • • •")
                }
            }
            .padding(.horizontal)
            
            // Action Buttons
            HStack(spacing: 16) {
                Button(role: .cancel) {
                    onCancel()
                } label: {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button {
                    validateAndSubmit()
                } label: {
                    Text(actionButtonText)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isInputValid)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 300)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
        .padding()
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func pinField(pin: Binding<String>, label: String, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                if isSecure {
                    SecureField(placeholder, text: pin)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)  // For auto-fill
                } else {
                    TextField(placeholder, text: pin)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)  // For auto-fill
                }
                
                Button {
                    isSecure.toggle()
                } label: {
                    Image(systemName: isSecure ? "eye.slash" : "eye")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Computed Properties
    
    /// Whether the input is valid for submission
    private var isInputValid: Bool {
        if pin.count < minPINLength {
            return false
        }
        
        if requireConfirmation && pin != confirmPin {
            return false
        }
        
        // Ensure PIN is numeric
        return pin.allSatisfy { $0.isNumber }
    }
    
    // MARK: - Methods
    
    /// Validate and submit the PIN
    private func validateAndSubmit() {
        // Clear previous errors
        showError = false
        
        // Input length check
        if pin.count < minPINLength {
            errorMessage = "PIN must be at least \(minPINLength) digits"
            showError = true
            return
        }
        
        // Numeric check
        if !pin.allSatisfy({ $0.isNumber }) {
            errorMessage = "PIN must contain only numbers"
            showError = true
            return
        }
        
        // Confirmation check
        if requireConfirmation && pin != confirmPin {
            errorMessage = "PINs do not match"
            showError = true
            return
        }
        
        // All checks passed, submit the PIN
        onSubmit(pin)
    }
}

struct PINEntryDialog: ViewModifier {
    @Binding var isPresented: Bool
    var title: String
    var message: String
    var onSubmit: (String) -> Void
    var minPINLength: Int = 4
    var requireConfirmation: Bool = false
    var actionButtonText: String = "Submit"
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .blur(radius: isPresented ? 3 : 0)
                .disabled(isPresented)
            
            if isPresented {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .animation(.easeInOut, value: isPresented)
                    .transition(.opacity)
                
                PINEntryView(
                    onSubmit: { pin in
                        // First call the original onSubmit function
                        onSubmit(pin)
                        
                        // Then dismiss the dialog
                        withAnimation {
                            isPresented = false
                        }
                    },
                    title: title,
                    message: message,
                    onCancel: {
                        withAnimation {
                            isPresented = false
                        }
                    },
                    minPINLength: minPINLength,
                    requireConfirmation: requireConfirmation,
                    actionButtonText: actionButtonText
                )
                .transition(.scale)
                .animation(.spring(), value: isPresented)
            }
        }
    }
}

extension View {
    /// Presents a PIN entry dialog using a custom view modifier
    func pinEntryDialog(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        onSubmit: @escaping (String) -> Void,
        minPINLength: Int = 4,
        requireConfirmation: Bool = false,
        actionButtonText: String = "Submit"
    ) -> some View {
        self.modifier(
            PINEntryDialog(
                isPresented: isPresented,
                title: title,
                message: message,
                onSubmit: onSubmit,
                minPINLength: minPINLength,
                requireConfirmation: requireConfirmation,
                actionButtonText: actionButtonText
            )
        )
    }
}

#Preview {
    VStack {
        Text("PIN Entry View Preview")
    }
    .pinEntryDialog(
        isPresented: .constant(true),
        title: "Enter PIN",
        message: "Please enter your PIN to access encrypted content",
        onSubmit: { pin in
            // PIN submitted
        }
    )
}

#Preview("Confirmation PIN") {
    PINEntryView(
        onSubmit: { _ in },
        title: "Create PIN",
        message: "Please create a secure PIN for your encrypted tag",
        onCancel: {},
        requireConfirmation: true,
        actionButtonText: "Create"
    )
}