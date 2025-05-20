//
//  Transcription+Extensions.swift
//  voicejournal
//
//  Created on 5/19/25.
//

import Foundation
import CoreData
import CryptoKit

extension Transcription {
    
    // MARK: - Core Data Lifecycle Hooks
    
    /// Override willSave to ensure content is encrypted when necessary
    override public func willSave() {
        super.willSave()
        
        // Only process if we have changes
        guard self.hasChanges else { return }
        
        print("🔐 [Transcription.willSave] Called with changes")
        
        // Check if the journal entry has encrypted content
        guard let entry = journalEntry,
              entry.hasEncryptedContent,
              let encryptedTag = entry.encryptedTag else {
            print("  - No encrypted tag, skipping encryption hook")
            return
        }
        
        print("  - Entry has encrypted tag: \(encryptedTag.name ?? "Unknown")")
        
        // Check if we have the encryption key available
        guard let key = EncryptedTagsAccessManager.shared.getEncryptionKey(for: encryptedTag) else {
            // Only warn if we actually have unencrypted content
            if self.hasUnencryptedContent {
                print("⚠️ [Transcription] No encryption key available during save - content may remain unencrypted")
            }
            return
        }
        
        // Check for unencrypted enhanced text
        if let enhancedText = self.enhancedText,
           self.encryptedEnhancedText == nil {
            print("🔐 [Transcription.willSave] Encrypting enhanced text on save (\(enhancedText.count) characters)")
            if let encryptedData = EncryptionManager.encrypt(enhancedText, using: key) {
                self.encryptedEnhancedText = encryptedData
                self.enhancedText = nil
                print("✅ [Transcription.willSave] Enhanced text encrypted successfully (\(encryptedData.count) bytes)")
            } else {
                print("❌ [Transcription.willSave] Failed to encrypt enhanced text")
            }
        } else {
            print("  - Enhanced text: \(self.enhancedText?.count ?? 0) chars, encrypted: \(self.encryptedEnhancedText?.count ?? 0) bytes")
        }
        
        // Check for unencrypted AI analysis - use async encryption with semaphore to wait
        if let aiAnalysis = self.aiAnalysis,
           self.encryptedAIAnalysis == nil,
           !aiAnalysis.isEmpty {
            print("🔐 [Transcription] Encrypting AI analysis on save (\(aiAnalysis.count) characters)")
            
            // For large AI analysis content, use async encryption
            let semaphore = DispatchSemaphore(value: 0)
            
            EncryptionManager.encryptAsync(aiAnalysis, using: key) { encryptedData in
                defer { semaphore.signal() }
                
                if let encryptedData = encryptedData {
                    self.encryptedAIAnalysis = encryptedData
                    self.aiAnalysis = nil
                    print("✅ [Transcription] AI analysis encrypted successfully (\(encryptedData.count) bytes)")
                } else {
                    print("❌ [Transcription] Failed to encrypt AI analysis")
                }
            }
            
            // Wait with timeout (3 seconds should be enough for any reasonable analysis)
            _ = semaphore.wait(timeout: .now() + 3.0)
        }
        
        // Check for unencrypted main text
        if let text = self.text,
           self.encryptedText == nil {
            print("🔐 [Transcription] Encrypting main text on save")
            if let encryptedData = EncryptionManager.encrypt(text, using: key) {
                self.encryptedText = encryptedData
                self.text = nil
                print("✅ [Transcription] Main text encrypted successfully")
            } else {
                print("❌ [Transcription] Failed to encrypt main text")
            }
        }
        
        // Check for unencrypted raw text
        if let rawText = self.rawText,
           self.encryptedRawText == nil {
            print("🔐 [Transcription] Encrypting raw text on save")
            if let encryptedData = EncryptionManager.encrypt(rawText, using: key) {
                self.encryptedRawText = encryptedData
                self.rawText = nil
                print("✅ [Transcription] Raw text encrypted successfully")
            } else {
                print("❌ [Transcription] Failed to encrypt raw text")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Check if the transcription has any unencrypted content when encryption is required
    var hasUnencryptedContent: Bool {
        guard let entry = journalEntry,
              entry.hasEncryptedContent else {
            return false
        }
        
        return enhancedText != nil ||
               aiAnalysis != nil ||
               text != nil ||
               rawText != nil
    }
    
    /// Ensure all content is properly encrypted based on the journal entry's encryption status
    func ensureEncryption() {
        guard let entry = journalEntry else { return }
        
        if entry.hasEncryptedContent {
            // Use tag encryption
            if let encryptedTag = entry.encryptedTag,
               let key = EncryptedTagsAccessManager.shared.getEncryptionKey(for: encryptedTag) {
                print("🔐 [Transcription] Ensuring tag encryption for all content")
                encryptContentWithKey(key)
            }
        } else if entry.isBaseEncrypted {
            // Use base encryption
            print("🔐 [Transcription] Ensuring base encryption for all content")
            _ = entry.applyBaseEncryption()
        }
    }
    
    /// Encrypt all unencrypted content with the provided key
    private func encryptContentWithKey(_ key: SymmetricKey) {
        // Encrypt enhanced text if unencrypted
        if let enhancedText = self.enhancedText, !enhancedText.isEmpty {
            // For potentially large enhanced text, use async encryption
            let semaphore = DispatchSemaphore(value: 0)
            
            EncryptionManager.encryptAsync(enhancedText, using: key) { encryptedData in
                defer { semaphore.signal() }
                
                if let encryptedData = encryptedData {
                    self.encryptedEnhancedText = encryptedData
                    self.enhancedText = nil
                    print("✅ [Transcription] Enhanced text encrypted: \(encryptedData.count) bytes")
                }
            }
            
            _ = semaphore.wait(timeout: .now() + 3.0)
        }
        
        // Encrypt AI analysis if unencrypted (usually the largest content)
        if let aiAnalysis = self.aiAnalysis, !aiAnalysis.isEmpty {
            let semaphore = DispatchSemaphore(value: 0)
            
            EncryptionManager.encryptAsync(aiAnalysis, using: key) { encryptedData in
                defer { semaphore.signal() }
                
                if let encryptedData = encryptedData {
                    self.encryptedAIAnalysis = encryptedData
                    self.aiAnalysis = nil
                    print("✅ [Transcription] AI analysis encrypted: \(encryptedData.count) bytes")
                }
            }
            
            _ = semaphore.wait(timeout: .now() + 3.0)
        }
        
        // Encrypt main text if unencrypted
        if let text = self.text, !text.isEmpty {
            if let encryptedData = EncryptionManager.encrypt(text, using: key) {
                self.encryptedText = encryptedData
                self.text = nil
                print("✅ [Transcription] Main text encrypted: \(encryptedData.count) bytes")
            }
        }
        
        // Encrypt raw text if unencrypted
        if let rawText = self.rawText, !rawText.isEmpty {
            if let encryptedData = EncryptionManager.encrypt(rawText, using: key) {
                self.encryptedRawText = encryptedData
                self.rawText = nil
                print("✅ [Transcription] Raw text encrypted: \(encryptedData.count) bytes")
            }
        }
    }
}