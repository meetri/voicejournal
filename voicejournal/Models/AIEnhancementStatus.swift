//
//  AIEnhancementStatus.swift
//  voicejournal
//
//  Created on 5/18/25.
//

import Foundation
import SwiftUI

/// Status of AI enhancement process
struct AIEnhancementStatus: Identifiable {
    let id = UUID()
    let feature: TranscriptionFeature
    var status: Status
    var errorMessage: String?
    var startTime: Date?
    var endTime: Date?
    
    var duration: TimeInterval? {
        guard let start = startTime, let end = endTime else { return nil }
        return end.timeIntervalSince(start)
    }
    
    var isActive: Bool {
        return status == .pending || status == .inProgress
    }
    
    enum Status: Equatable {
        case pending
        case inProgress
        case completed
        case failed
        
        var displayName: String {
            switch self {
            case .pending:
                return "Waiting"
            case .inProgress:
                return "Processing"
            case .completed:
                return "Complete"
            case .failed:
                return "Failed"
            }
        }
        
        var color: Color {
            switch self {
            case .pending:
                return .gray
            case .inProgress:
                return .blue
            case .completed:
                return .green
            case .failed:
                return .red
            }
        }
    }
}

/// Result of AI enhancement operation
struct AIEnhancementResult {
    let features: [AIEnhancementStatus]
    let originalText: String
    let enhancedText: String
    let totalDuration: TimeInterval
    
    var successCount: Int {
        features.filter { $0.status == .completed }.count
    }
    
    var failureCount: Int {
        features.filter { $0.status == .failed }.count
    }
    
    var isComplete: Bool {
        features.allSatisfy { !$0.isActive }
    }
    
    var hasErrors: Bool {
        features.contains { $0.status == .failed }
    }
}

