import SwiftUI
import CoreData
import Combine

/// Helper to check AI Analysis status 
/// For debugging the "Start Analysis Button" issue
class AIAnalysisStatusChecker {
    
    static func logStatus(for journalEntry: JournalEntry) {
        print("🔍 [AIAnalysisStatusChecker] Checking AI analysis status:")
        
        if let transcription = journalEntry.transcription {
            print("  - Raw text: \(transcription.rawText?.count ?? 0) characters")
            print("  - Enhanced text: \(transcription.enhancedText?.count ?? 0) characters")
            print("  - AI analysis: \(transcription.aiAnalysis?.count ?? 0) characters")
            print("  - Encrypted enhanced: \(transcription.encryptedEnhancedText?.count ?? 0) bytes")
            print("  - Encrypted AI: \(transcription.encryptedAIAnalysis?.count ?? 0) bytes")
            print("  - Entry has encrypted content: \(journalEntry.hasEncryptedContent)")
            print("  - Entry is decrypted: \(journalEntry.isDecrypted)")
            print("  - Entry is base encrypted: \(journalEntry.isBaseEncrypted)")
            print("  - Entry is base decrypted: \(journalEntry.isBaseDecrypted)")
            
            let hasAnalysis = (transcription.aiAnalysis != nil) || 
                              (transcription.encryptedAIAnalysis != nil)
            
            print("  - Has any AI analysis: \(hasAnalysis)")
            print("  - Notification name used: \(Notification.Name.aiEnhancementCompleted)")
        } else {
            print("  - No transcription available")
        }
    }

    static func attachNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name.aiEnhancementCompleted,
            object: nil,
            queue: .main
        ) { notification in
            print("📢 [AIAnalysisStatusChecker] Received aiEnhancementCompleted notification")
            if let entry = notification.object as? JournalEntry {
                print("  - For entry: \(entry.title ?? "Untitled")")
                self.logStatus(for: entry)
            } else {
                print("  - No entry object found in notification")
            }
        }
    }
}