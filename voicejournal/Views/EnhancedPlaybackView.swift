//
//  EnhancedPlaybackView.swift
//  voicejournal
//
//  Created on 4/28/25.
//

import SwiftUI
import AVFoundation

/// An enhanced view that displays audio playback controls and visualization
struct EnhancedPlaybackView: View {
    // MARK: - View Model
    
    @ObservedObject var viewModel: AudioPlaybackViewModel
    
    // MARK: - State
    
    @State private var isEditingSlider = false
    @State private var sliderValue: Double = 0.0
    @State private var showBookmarkList = false
    @State private var newBookmarkLabel = ""
    
    // MARK: - Initialization
    
    init(viewModel: AudioPlaybackViewModel) {
        self.viewModel = viewModel
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 16) {
            // Spectrum analyzer visualization
            AudioVisualizationView(
                audioLevel: viewModel.visualizationLevel,
                primaryColor: playbackColor,
                secondaryColor: playbackSecondaryColor,
                isActive: viewModel.isPlaying,
                frequencyData: viewModel.frequencyData,
                height: 70
            )
            
            // Bookmarks indicator
            if !viewModel.bookmarks.isEmpty {
                bookmarkIndicators
            }
            
            // Time and progress
            HStack {
                Text(viewModel.formattedCurrentTime)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(viewModel.formattedDuration)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
            
            // Progress slider with bookmark indicators
            ZStack(alignment: .bottom) {
                // Bookmark indicators
                if !viewModel.bookmarks.isEmpty {
                    GeometryReader { geometry in
                        ForEach(viewModel.bookmarks, id: \.self) { bookmark in
                            let position = bookmark.timestamp / viewModel.duration
                            let xPosition = geometry.size.width * CGFloat(position)
                            
                            Rectangle()
                                .fill(Color(hex: bookmark.color ?? "#FF5733"))
                                .frame(width: 2, height: 12)
                                .position(x: xPosition, y: 0)
                        }
                    }
                    .frame(height: 12)
                }
                
                // Progress slider
                Slider(
                    value: $sliderValue,
                    in: 0...1,
                    onEditingChanged: { editing in
                        isEditingSlider = editing
                        
                        if editing {
                            // When user starts dragging, store the current value
                            sliderValue = viewModel.progress
                        } else {
                            // When user finishes dragging, seek to the new position
                            viewModel.seekToProgress(sliderValue)
                        }
                    }
                )
                .onReceive(viewModel.$progress) { newProgress in
                    // Only update the slider value when not being edited
                    if !isEditingSlider {
                        sliderValue = newProgress
                    }
                }
                .accentColor(playbackColor)
                .padding(.horizontal, 2)
            }
            
            // Playback controls
            HStack(spacing: 24) {
                // Skip to previous bookmark or backward 10 seconds
                Button(action: {
                    if !viewModel.bookmarks.isEmpty {
                        viewModel.skipToPreviousBookmark()
                    } else {
                        viewModel.skipBackward()
                    }
                    
                    // Add haptic feedback
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }) {
                    Image(systemName: !viewModel.bookmarks.isEmpty ? "bookmark.fill.backward" : "gobackward.10")
                        .font(.system(size: 24))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                        .background(Color(.systemGray6).opacity(0.5))
                        .clipShape(Circle())
                }
                
                // Play/Pause button
                Button(action: {
                    viewModel.togglePlayPause()
                    
                    // Add haptic feedback
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }) {
                    ZStack {
                        Circle()
                            .fill(playbackColor.opacity(0.2))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 28))
                            .foregroundColor(playbackColor)
                    }
                }
                
                // Skip to next bookmark or forward 10 seconds
                Button(action: {
                    if !viewModel.bookmarks.isEmpty {
                        viewModel.skipToNextBookmark()
                    } else {
                        viewModel.skipForward()
                    }
                    
                    // Add haptic feedback
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }) {
                    Image(systemName: !viewModel.bookmarks.isEmpty ? "bookmark.fill.forward" : "goforward.10")
                        .font(.system(size: 24))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                        .background(Color(.systemGray6).opacity(0.5))
                        .clipShape(Circle())
                }
            }
            .padding(.vertical, 8)
            
            // Additional controls
            VStack(spacing: 12) {
                // Primary controls row
                HStack(spacing: 12) {
                    // Playback rate button
                    Button(action: {
                        viewModel.setRate(viewModel.nextRate)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "speedometer")
                                .font(.system(size: 14))
                            Text(viewModel.rateString)
                                .font(.system(.footnote, design: .rounded))
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(playbackColor.opacity(0.1))
                        .foregroundColor(playbackColor)
                        .cornerRadius(10)
                    }
                    
                    // Bookmark button
                    Button(action: {
                        viewModel.showBookmarkDialog = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "bookmark.fill")
                                .font(.system(size: 14))
                            Text("Add")
                                .font(.system(.footnote))
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(10)
                    }
                }
                
                // Secondary controls row
                HStack(spacing: 12) {
                    // Bookmark list button
                    Button(action: {
                        withAnimation(.spring()) {
                            showBookmarkList.toggle()
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: showBookmarkList ? "list.bullet.indent" : "list.bullet")
                                .font(.system(size: 14))
                            Text("Bookmarks")
                                .font(.system(.footnote))
                                .fontWeight(.medium)
                            if !viewModel.bookmarks.isEmpty {
                                Text("(\(viewModel.bookmarks.count))")
                                    .font(.system(.caption2))
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color.purple.opacity(0.1))
                        .foregroundColor(.purple)
                        .cornerRadius(10)
                    }
                    
                    // Stop button
                    Button(action: {
                        viewModel.stop()
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 14))
                            Text("Stop")
                                .font(.system(.footnote))
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(10)
                    }
                }
                
                // AI Analysis row
                HStack(spacing: 12) {
                    // AI Analyze button
                    Button(action: {
                        viewModel.showAIAnalysis = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14))
                            Text("AI Analysis")
                                .font(.system(.footnote))
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color(hex: "#34C759").opacity(0.1))
                        .foregroundColor(Color(hex: "#34C759"))
                        .cornerRadius(10)
                    }
                    .disabled(viewModel.isAnalyzing)
                }
            }
            .padding(.horizontal)
            
            // Show bookmark list if enabled
            if showBookmarkList {
                bookmarkListView
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .alert("Playback Error", isPresented: $viewModel.showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
        .alert("Add Bookmark", isPresented: $viewModel.showBookmarkDialog) {
            TextField("Bookmark Label", text: $newBookmarkLabel)
            Button("Cancel", role: .cancel) {
                newBookmarkLabel = ""
            }
            Button("Add") {
                viewModel.createBookmark(label: newBookmarkLabel.isEmpty ? nil : newBookmarkLabel)
                newBookmarkLabel = ""
                
                // Add haptic feedback
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        } message: {
            Text("Add a bookmark at the current position (\(viewModel.formattedCurrentTime))")
        }
        .sheet(isPresented: $viewModel.showAIAnalysis) {
            if let journalEntry = viewModel.journalEntry {
                AIAnalysisView(
                    journalEntry: journalEntry,
                    audioURL: viewModel.audioURL,
                    isPresented: $viewModel.showAIAnalysis
                )
            }
        }
    }
    
    // MARK: - Subviews
    
    /// View showing bookmark indicators
    private var bookmarkIndicators: some View {
        HStack(spacing: 4) {
            // Show up to 5 bookmarks inline with "more" indicator
            let visibleBookmarks = Array(viewModel.bookmarks.prefix(5))
            let remainingCount = max(0, viewModel.bookmarks.count - 5)
            
            ForEach(visibleBookmarks, id: \.self) { bookmark in
                Button(action: {
                    viewModel.seekToBookmark(bookmark)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }) {
                    HStack(spacing: 2) {
                        Circle()
                            .fill(Color(hex: bookmark.color ?? "#FF5733"))
                            .frame(width: 6, height: 6)
                            
                        Text(bookmark.label ?? bookmark.formattedTimestamp)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            if remainingCount > 0 {
                Text("+\(remainingCount)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6))
                    )
            }
            
            Spacer()
        }
        .padding(.horizontal)
    }
    
    /// View showing the list of bookmarks
    private var bookmarkListView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Bookmarks")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring()) {
                        showBookmarkList = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
            
            if viewModel.bookmarks.isEmpty {
                Text("No bookmarks yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(viewModel.bookmarks, id: \.self) { bookmark in
                            HStack {
                                Circle()
                                    .fill(Color(hex: bookmark.color ?? "#FF5733"))
                                    .frame(width: 12, height: 12)
                                
                                Text(bookmark.label ?? "Bookmark")
                                    .font(.subheadline)
                                
                                Spacer()
                                
                                Text(bookmark.formattedTimestamp)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Button(action: {
                                    viewModel.seekToBookmark(bookmark)
                                    
                                    // Add haptic feedback
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }) {
                                    Image(systemName: "play.circle")
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                                
                                Button(action: {
                                    viewModel.deleteBookmark(bookmark)
                                    
                                    // Add haptic feedback
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.systemGray6))
                            )
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(maxHeight: 200)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
        )
        .padding(.horizontal, 4)
    }
    
    // MARK: - Computed Properties
    
    /// The color to use for the playback visualization and controls
    private var playbackColor: Color {
        if !viewModel.isAudioLoaded {
            return .gray
        } else if viewModel.isPaused {
            return .orange
        } else if viewModel.isPlaying {
            return .blue
        } else {
            return .blue.opacity(0.7)
        }
    }
    
    /// The secondary color for gradients
    private var playbackSecondaryColor: Color {
        if !viewModel.isAudioLoaded {
            return .gray.opacity(0.6)
        } else if viewModel.isPaused {
            return .yellow
        } else if viewModel.isPlaying {
            return .purple
        } else {
            return .purple.opacity(0.7)
        }
    }
}

/// A compact version of the playback view for use in lists or smaller spaces
struct CompactEnhancedPlaybackView: View {
    // MARK: - View Model
    
    @ObservedObject var viewModel: AudioPlaybackViewModel
    
    // MARK: - State
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 8) {
            // Waveform and controls
            HStack(spacing: 12) {
                // Play/Pause button
                Button(action: {
                    viewModel.togglePlayPause()
                    
                    // Add haptic feedback
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }) {
                    Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(viewModel.isPlaying ? .blue : .gray)
                }
                
                // Mini spectrum analyzer
                AudioVisualizationView(
                    audioLevel: viewModel.visualizationLevel,
                    primaryColor: viewModel.isPlaying ? .blue : .gray,
                    secondaryColor: viewModel.isPlaying ? .purple : .gray.opacity(0.6),
                    isActive: viewModel.isPlaying,
                    frequencyData: viewModel.frequencyData,
                    height: 30
                )
            }
            
            // Progress and time
            HStack {
                Text(viewModel.formattedCurrentTime)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(width: geometry.size.width, height: 4)
                            .cornerRadius(2)
                        
                        // Progress
                        Rectangle()
                            .fill(viewModel.isPlaying ? Color.blue : Color.gray)
                            .frame(width: geometry.size.width * CGFloat(viewModel.progress), height: 4)
                            .cornerRadius(2)
                    }
                }
                .frame(height: 4)
                
                Text(viewModel.formattedDuration)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        let playbackService = AudioPlaybackService()
        let viewModel = AudioPlaybackViewModel(playbackService: playbackService)
        
        // Full playback view
        EnhancedPlaybackView(viewModel: viewModel)
            .padding()
        
        // Compact playback view
        CompactEnhancedPlaybackView(viewModel: viewModel)
            .padding()
    }
    .background(Color(.systemGroupedBackground))
}
