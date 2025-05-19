//
//  AIEnhancementStatusView.swift
//  voicejournal
//
//  Created on 5/18/25.
//

import SwiftUI
import CoreData

struct AIEnhancementStatusView: View {
    @ObservedObject var viewModel: AudioRecordingViewModel
    @Environment(\.themeManager) var themeManager
    
    var body: some View {
        if viewModel.showAIEnhancementStatus {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(themeManager.theme.accent)
                    Text("AI Enhancement")
                        .font(.headline)
                        .foregroundColor(themeManager.theme.text)
                    Spacer()
                    if viewModel.isEnhancing {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                
                // Feature list
                ForEach(viewModel.enhancementStatuses) { status in
                    FeatureStatusRow(status: status)
                        .environment(\.themeManager, themeManager)
                }
                
                // Result summary
                if let result = viewModel.enhancementResult, result.isComplete {
                    ResultSummaryView(result: result)
                        .environment(\.themeManager, themeManager)
                        .transition(.opacity)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(themeManager.theme.background.opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(themeManager.theme.cellBorder, lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
            .padding()
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.3), value: viewModel.showAIEnhancementStatus)
        }
    }
}

struct FeatureStatusRow: View {
    let status: AIEnhancementStatus
    @Environment(\.themeManager) var themeManager
    
    var body: some View {
        HStack {
            // Status icon
            statusIcon
                .frame(width: 20)
            
            // Feature name
            Text(status.feature.displayName)
                .font(.subheadline)
                .foregroundColor(themeManager.theme.text)
            
            Spacer()
            
            // Duration or status
            if let duration = status.duration {
                Text("\(String(format: "%.1f", duration))s")
                    .font(.caption)
                    .foregroundColor(themeManager.theme.textSecondary)
            } else if status.status == .inProgress {
                ProgressView()
                    .scaleEffect(0.6)
            }
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch status.status {
        case .pending:
            Image(systemName: "circle")
                .foregroundColor(themeManager.theme.textSecondary)
        case .inProgress:
            Image(systemName: "circle.fill")
                .foregroundColor(.orange)
                .overlay(
                    ProgressView()
                        .scaleEffect(0.5)
                )
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
        }
    }
}

struct ResultSummaryView: View {
    let result: AIEnhancementResult
    @Environment(\.themeManager) var themeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .background(themeManager.theme.cellBorder)
            
            // Summary statistics
            HStack {
                VStack(alignment: .leading) {
                    Text("Summary")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(themeManager.theme.text)
                    
                    HStack(spacing: 16) {
                        Label("\(result.successCount) succeeded", systemImage: "checkmark.circle")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        if result.failureCount > 0 {
                            Label("\(result.failureCount) failed", systemImage: "xmark.circle")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Spacer()
                
                Text("Total: \(String(format: "%.1f", result.totalDuration))s")
                    .font(.caption)
                    .foregroundColor(themeManager.theme.textSecondary)
            }
            
            // Character count change
            let charDiff = result.enhancedText.count - result.originalText.count
            if charDiff != 0 {
                Text("\(charDiff > 0 ? "+" : "")\(charDiff) characters")
                    .font(.caption)
                    .foregroundColor(charDiff > 0 ? .green : .orange)
            }
        }
        .padding(.top, 8)
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let recordingService = AudioRecordingService()
    let viewModel = AudioRecordingViewModel(
        context: context,
        recordingService: recordingService
    )
    
    return AIEnhancementStatusView(viewModel: viewModel)
        .environmentObject(ThemeManager())
        .onAppear {
            viewModel.showAIEnhancementStatus = true
        }
}