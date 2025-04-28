//
//  MiniPlayerView.swift
//  voicejournal
//
//  Created on 4/27/25.
//

import SwiftUI
import Combine

/// A mini player view that provides basic playback controls and can be displayed persistently
struct MiniPlayerView: View {
    // MARK: - Environment
    
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - Properties
    
    @ObservedObject var viewModel: AudioPlaybackViewModel
    @Binding var isExpanded: Bool
    
    // MARK: - State
    
    @State private var dragOffset: CGFloat = 0
    
    // MARK: - Constants
    
    private let height: CGFloat = 60
    private let cornerRadius: CGFloat = 16
    private let dragThreshold: CGFloat = 50
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.gray.opacity(0.5))
                .frame(width: 36, height: 4)
                .padding(.top, 6)
                .padding(.bottom, 2)
            
            // Main content
            HStack(spacing: 12) {
                // Play/Pause button
                Button(action: {
                    viewModel.togglePlayPause()
                }) {
                    Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(viewModel.isPlaying ? .blue : .gray)
                }
                .padding(.leading, 8)
                
                // Title and progress
                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    Text(getTitle())
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    // Progress bar and time
                    HStack(spacing: 4) {
                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                Rectangle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: geometry.size.width, height: 3)
                                    .cornerRadius(1.5)
                                
                                // Progress
                                Rectangle()
                                    .fill(viewModel.isPlaying ? Color.blue : Color.gray)
                                    .frame(width: geometry.size.width * CGFloat(viewModel.progress), height: 3)
                                    .cornerRadius(1.5)
                            }
                        }
                        .frame(height: 3)
                        
                        // Time
                        Text(viewModel.formattedCurrentTime)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Skip backward button
                Button(action: {
                    viewModel.skipBackward()
                }) {
                    Image(systemName: "gobackward.10")
                        .font(.system(size: 20))
                        .foregroundColor(.primary)
                }
                
                // Skip forward button
                Button(action: {
                    viewModel.skipForward()
                }) {
                    Image(systemName: "goforward.10")
                        .font(.system(size: 20))
                        .foregroundColor(.primary)
                }
                .padding(.trailing, 16)
            }
            .padding(.bottom, 12)
            .padding(.horizontal, 8)
        }
        .frame(height: height + dragOffset)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: -2)
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Only allow dragging upward
                    let newOffset = max(0, value.translation.height * -1)
                    dragOffset = newOffset
                }
                .onEnded { value in
                    // If dragged up past threshold, expand the player
                    if dragOffset > dragThreshold {
                        isExpanded = true
                    }
                    
                    // Reset drag offset
                    withAnimation(.spring()) {
                        dragOffset = 0
                    }
                }
        )
        .onTapGesture {
            // Expand player on tap
            isExpanded = true
        }
    }
    
    // MARK: - Helper Methods
    
    /// Get the title to display in the mini player
    private func getTitle() -> String {
        if let recording = viewModel.currentRecording,
           let journalEntry = recording.journalEntry,
           let title = journalEntry.title {
            return title
        } else if let url = viewModel.audioFileURL {
            return url.lastPathComponent
        } else {
            return "Now Playing"
        }
    }
}

/// A container view that manages the mini player and full player states
struct PlayerContainerView: View {
    // MARK: - Properties
    
    @ObservedObject var viewModel: AudioPlaybackViewModel
    
    // MARK: - State
    
    @State private var isPlayerExpanded = false
    @State private var isPlayerVisible = false
    
    // MARK: - Body
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Content goes here
            Color.clear
                .frame(height: 0)
            
            // Mini player
            if isPlayerVisible {
                MiniPlayerView(viewModel: viewModel, isExpanded: $isPlayerExpanded)
                    .transition(.move(edge: .bottom))
                    .zIndex(1)
            }
        }
        .sheet(isPresented: $isPlayerExpanded) {
            // Full player sheet
            PlaybackView(viewModel: viewModel)
                .padding()
        }
        .onChange(of: viewModel.isPlaybackInProgress) { isPlaying in
            // Show player when playback starts, hide when stopped
            withAnimation {
                isPlayerVisible = isPlaying
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()
        
        let playbackService = AudioPlaybackService()
        let viewModel = AudioPlaybackViewModel(playbackService: playbackService)
        
        // For preview purposes, set some values
        viewModel.setCurrentTimeForTesting(35)
        
        MiniPlayerView(
            viewModel: viewModel,
            isExpanded: .constant(false)
        )
    }
}

#Preview("Player Container") {
    ZStack {
        Color(.systemGroupedBackground)
            .ignoresSafeArea()
        
        VStack {
            Text("App Content")
                .font(.title)
            
            Spacer()
        }
        
        let playbackService = AudioPlaybackService()
        let viewModel = AudioPlaybackViewModel(playbackService: playbackService)
        
        // For preview purposes, set some values
        viewModel.setCurrentTimeForTesting(35)
        
        PlayerContainerView(viewModel: viewModel)
    }
}
