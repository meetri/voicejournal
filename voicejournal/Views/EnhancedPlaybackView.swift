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
    @State private var waveformStyle: WaveformStyle = .bars
    @State private var showingStylePicker = false
    
    // MARK: - Initialization
    
    init(viewModel: AudioPlaybackViewModel) {
        self.viewModel = viewModel
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 16) {
            // Waveform visualization with style picker
            ZStack(alignment: .topTrailing) {
                EnhancedWaveformView(
                    audioLevel: viewModel.visualizationLevel,
                    primaryColor: playbackColor,
                    secondaryColor: playbackSecondaryColor,
                    isActive: viewModel.isPlaying,
                    style: waveformStyle
                )
                .frame(height: 70)
                .contentShape(Rectangle())
                .onTapGesture {
                    showingStylePicker = true
                }
                
                // Style picker button
                Button(action: {
                    showingStylePicker = true
                }) {
                    Image(systemName: "waveform.circle")
                        .font(.system(size: 20))
                        .foregroundColor(playbackColor)
                        .padding(8)
                        .background(Color(.systemBackground).opacity(0.7))
                        .clipShape(Circle())
                }
                .padding(8)
            }
            .popover(isPresented: $showingStylePicker) {
                waveformStylePicker
            }
            
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
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    // Playback rate button
                    Button(action: {
                        viewModel.setRate(viewModel.nextRate)
                        
                        // Add haptic feedback
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }) {
                        Text(viewModel.rateString)
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(playbackColor.opacity(0.15))
                            .foregroundColor(playbackColor)
                            .cornerRadius(16)
                    }
                    
                    // Bookmark button
                    Button(action: {
                        viewModel.showBookmarkDialog = true
                        
                        // Add haptic feedback
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }) {
                        Label("Bookmark", systemImage: "bookmark.fill")
                            .font(.system(.subheadline))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.15))
                            .foregroundColor(.blue)
                            .cornerRadius(16)
                    }
                    
                    // Bookmark list button
                    Button(action: {
                        withAnimation(.spring()) {
                            showBookmarkList.toggle()
                        }
                        
                        // Add haptic feedback
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }) {
                        Label("Bookmarks", systemImage: "list.bullet")
                            .font(.system(.subheadline))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.purple.opacity(0.15))
                            .foregroundColor(.purple)
                            .cornerRadius(16)
                    }
                    
                    // Stop button
                    Button(action: {
                        viewModel.stop()
                        
                        // Add haptic feedback
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }) {
                        Label("Stop", systemImage: "stop.fill")
                            .font(.system(.subheadline))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.15))
                            .foregroundColor(.red)
                            .cornerRadius(16)
                    }
                }
                .padding(.horizontal, 4)
            }
            
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
    }
    
    // MARK: - Subviews
    
    /// Waveform style picker
    private var waveformStylePicker: some View {
        VStack(spacing: 16) {
            Text("Waveform Style")
                .font(.headline)
                .padding(.top)
            
            VStack(spacing: 12) {
                Button(action: {
                    waveformStyle = .bars
                    showingStylePicker = false
                }) {
                    VStack {
                        EnhancedWaveformView(
                            audioLevel: 0.5,
                            primaryColor: playbackColor,
                            secondaryColor: playbackSecondaryColor,
                            isActive: true,
                            style: .bars
                        )
                        .frame(width: 200, height: 40)
                        
                        Text("Bars")
                            .font(.subheadline)
                            .foregroundColor(waveformStyle == .bars ? playbackColor : .primary)
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(waveformStyle == .bars ? playbackColor : Color.clear, lineWidth: 2)
                    )
                }
                
                Button(action: {
                    waveformStyle = .curve
                    showingStylePicker = false
                }) {
                    VStack {
                        EnhancedWaveformView(
                            audioLevel: 0.5,
                            primaryColor: playbackColor,
                            secondaryColor: playbackSecondaryColor,
                            isActive: true,
                            style: .curve
                        )
                        .frame(width: 200, height: 40)
                        
                        Text("Curve")
                            .font(.subheadline)
                            .foregroundColor(waveformStyle == .curve ? playbackColor : .primary)
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(waveformStyle == .curve ? playbackColor : Color.clear, lineWidth: 2)
                    )
                }
                
                Button(action: {
                    waveformStyle = .circles
                    showingStylePicker = false
                }) {
                    VStack {
                        EnhancedWaveformView(
                            audioLevel: 0.5,
                            primaryColor: playbackColor,
                            secondaryColor: playbackSecondaryColor,
                            isActive: true,
                            style: .circles
                        )
                        .frame(width: 200, height: 40)
                        
                        Text("Circles")
                            .font(.subheadline)
                            .foregroundColor(waveformStyle == .circles ? playbackColor : .primary)
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(waveformStyle == .circles ? playbackColor : Color.clear, lineWidth: 2)
                    )
                }
                
                Button(action: {
                    waveformStyle = .spectrum
                    showingStylePicker = false
                }) {
                    VStack {
                        EnhancedWaveformView(
                            audioLevel: 0.5,
                            primaryColor: playbackColor,
                            secondaryColor: playbackSecondaryColor,
                            isActive: true,
                            style: .spectrum
                        )
                        .frame(width: 200, height: 40)
                        
                        Text("Spectrum")
                            .font(.subheadline)
                            .foregroundColor(waveformStyle == .spectrum ? playbackColor : .primary)
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(waveformStyle == .spectrum ? playbackColor : Color.clear, lineWidth: 2)
                    )
                }
            }
            .padding()
        }
        .frame(width: 250)
        .padding(.bottom)
    }
    
    /// View showing bookmark indicators
    private var bookmarkIndicators: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.bookmarks, id: \.self) { bookmark in
                    Button(action: {
                        viewModel.seekToBookmark(bookmark)
                        
                        // Add haptic feedback
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: bookmark.color ?? "#FF5733"))
                                .frame(width: 8, height: 8)
                            
                            Text(bookmark.label ?? bookmark.formattedTimestamp)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 30)
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
    
    @State private var waveformStyle: WaveformStyle = .bars
    
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
                
                // Mini waveform
                EnhancedWaveformView(
                    audioLevel: viewModel.visualizationLevel,
                    primaryColor: viewModel.isPlaying ? .blue : .gray,
                    secondaryColor: viewModel.isPlaying ? .purple : .gray.opacity(0.6),
                    barCount: 20,
                    spacing: 2,
                    isActive: viewModel.isPlaying,
                    style: waveformStyle
                )
                .frame(height: 30)
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
