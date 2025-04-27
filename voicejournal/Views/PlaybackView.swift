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
    
    // MARK: - Initialization
    
    init(viewModel: AudioPlaybackViewModel) {
        self.viewModel = viewModel
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 16) {
            // Waveform visualization
            WaveformView(
                audioLevel: viewModel.visualizationLevel,
                color: playbackColor,
                isActive: viewModel.isPlaying
            )
            .frame(height: 60)
            .padding(.horizontal)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
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
            .padding(.horizontal)
            
            // Playback controls
            HStack(spacing: 24) {
                // Skip backward button
                Button(action: {
                    viewModel.skipBackward()
                }) {
                    Image(systemName: "gobackward.10")
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
                
                // Skip forward button
                Button(action: {
                    viewModel.skipForward()
                }) {
                    Image(systemName: "goforward.10")
                        .font(.system(size: 24))
                        .foregroundColor(.primary)
                }
            }
            .padding(.vertical, 8)
            
            // Additional controls
            HStack(spacing: 32) {
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
