//
//  AIEnhancementNotification.swift
//  voicejournal
//
//  Created on 5/18/25.
//

import Foundation

/// Notification for AI enhancement status updates
extension Notification.Name {
    static let aiEnhancementStarted = Notification.Name("aiEnhancementStarted")
    static let aiEnhancementProgress = Notification.Name("aiEnhancementProgress")
    static let aiEnhancementCompleted = Notification.Name("aiEnhancementCompleted")
}

/// Notification info keys
struct AIEnhancementNotificationKeys {
    static let journalEntryID = "journalEntryID"
    static let enhancementStatuses = "enhancementStatuses"
    static let isEnhancing = "isEnhancing"
    static let enhancementResult = "enhancementResult"
}

/// AI Enhancement Manager to track enhancement across views
class AIEnhancementManager: ObservableObject {
    static let shared = AIEnhancementManager()
    
    @Published var enhancementStatuses: [String: [AIEnhancementStatus]] = [:]
    @Published var activeEnhancements: Set<String> = []
    
    private init() {}
    
    func startEnhancement(for entryID: String, statuses: [AIEnhancementStatus]) {
        DispatchQueue.main.async {
            self.enhancementStatuses[entryID] = statuses
            self.activeEnhancements.insert(entryID)
        }
    }
    
    func updateStatuses(for entryID: String, statuses: [AIEnhancementStatus]) {
        DispatchQueue.main.async {
            self.enhancementStatuses[entryID] = statuses
        }
    }
    
    func completeEnhancement(for entryID: String, result: AIEnhancementResult) {
        DispatchQueue.main.async {
            self.activeEnhancements.remove(entryID)
            // Keep the final statuses for display
            self.enhancementStatuses[entryID] = result.features
        }
    }
    
    func clearEnhancement(for entryID: String) {
        DispatchQueue.main.async {
            self.enhancementStatuses.removeValue(forKey: entryID)
            self.activeEnhancements.remove(entryID)
        }
    }
}