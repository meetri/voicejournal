//
//  PlaybackView.swift
//  voicejournal
//
//  Created on 4/27/25.
//

import SwiftUI
import AVFoundation

/// A view that displays audio playback controls and visualization
struct PlaybackView: View {
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
            EnhancedWaveformView(
                audioLevel: viewModel.visualizationLevel,
                primaryColor: playbackColor,
                secondaryColor: playbackSecondaryColor,
                isActive: viewModel.isPlaying,
                frequencyData: viewModel.frequencyData
            )
            .frame(height: 60)
            .padding(.horizontal)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
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
            .padding(.horizontal)
            
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
            }
            .padding(.horizontal)
            
            // Playback controls
            HStack(spacing: 24) {
                // Skip to previous bookmark or backward 10 seconds
                Button(action: {
                    if !viewModel.bookmarks.isEmpty {
                        viewModel.skipToPreviousBookmark()
                    } else {
                        viewModel.skipBackward()
                    }
                }) {
                    Image(systemName: !viewModel.bookmarks.isEmpty ? "bookmark.fill.backward" : "gobackward.10")
                        .font(.system(size: 24))
                        .foregroundColor(.primary)
                }
                
                // Play/Pause button
                Button(action: {
                    viewModel.togglePlayPause()
                }) {
                    Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(playbackColor)
                }
                
                // Skip to next bookmark or forward 10 seconds
                Button(action: {
                    if !viewModel.bookmarks.isEmpty {
                        viewModel.skipToNextBookmark()
                    } else {
                        viewModel.skipForward()
                    }
                }) {
                    Image(systemName: !viewModel.bookmarks.isEmpty ? "bookmark.fill.forward" : "goforward.10")
                        .font(.system(size: 24))
                        .foregroundColor(.primary)
                }
            }
            .padding(.vertical, 8)
            
            // Additional controls
            HStack(spacing: 20) {
                // Playback rate button
                Button(action: {
                    viewModel.setRate(viewModel.nextRate)
                }) {
                    Text(viewModel.rateString)
                        .font(.system(.footnote, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                }
                
                // Bookmark button
                Button(action: {
                    viewModel.showBookmarkDialog = true
                }) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.blue)
                        .padding(8)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                }
                
                // Bookmark list button
                Button(action: {
                    showBookmarkList.toggle()
                }) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 18))
                        .foregroundColor(.primary)
                        .padding(8)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                }
                
                // Stop button
                Button(action: {
                    viewModel.stop()
                }) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.primary)
                        .padding(8)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                }
            }
            .padding(.bottom, 8)
            // Show bookmark list if enabled
            if showBookmarkList {
                bookmarkListView
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
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
            }
        } message: {
            Text("Add a bookmark at the current position (\(viewModel.formattedCurrentTime))")
        }
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
    
    /// The secondary color for gradient effects
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
    
    /// View showing bookmark indicators
    private var bookmarkIndicators: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.bookmarks, id: \.self) { bookmark in
                    Button(action: {
                        viewModel.seekToBookmark(bookmark)
                    }) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: bookmark.color ?? "#FF5733"))
                                .frame(width: 8, height: 8)
                            
                            Text(bookmark.label ?? bookmark.formattedTimestamp)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: bookmark.color ?? "#FF5733"), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 30)
    }
    
    /// View showing the list of bookmarks
    private var bookmarkListView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bookmarks")
                .font(.headline)
                .padding(.bottom, 4)
            
            if viewModel.bookmarks.isEmpty {
                Text("No bookmarks yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
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
                                }) {
                                    Image(systemName: "play.circle")
                                        .foregroundColor(.blue)
                                }
                                
                                Button(action: {
                                    viewModel.deleteBookmark(bookmark)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(maxHeight: 200)
            }
        }
        .padding()
        .background(Color(.systemGray5))
        .cornerRadius(12)
        .padding(.horizontal, 4)
    }
}

/// A compact version of the playback view for use in lists or smaller spaces
struct CompactPlaybackView: View {
    // MARK: - View Model
    
    @ObservedObject var viewModel: AudioPlaybackViewModel
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 12) {
            // Play/Pause button
            Button(action: {
                viewModel.togglePlayPause()
            }) {
                Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(viewModel.isPlaying ? .blue : .gray)
            }
            
            // Progress and time
            VStack(alignment: .leading, spacing: 4) {
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
                
                // Time display
                HStack {
                    Text(viewModel.formattedCurrentTime)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(viewModel.formattedDuration)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        let playbackService = AudioPlaybackService()
        let viewModel = AudioPlaybackViewModel(playbackService: playbackService)
        
        // Full playback view
        PlaybackView(viewModel: viewModel)
            .padding()
        
        // Compact playback view
        CompactPlaybackView(viewModel: viewModel)
            .padding()
            .background(Color(.systemGray6))
    }
}
