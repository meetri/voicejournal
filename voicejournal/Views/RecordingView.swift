//
//  RecordingView.swift
//  voicejournal
//
//  Created on 4/27/25.
//

import SwiftUI
import CoreData

/// The main view for recording audio journal entries
struct RecordingView: View {
    // MARK: - Environment
    
    @Environment(\.managedObjectContext) private var viewContext
    
    // MARK: - View Model
    
    @StateObject private var viewModel: AudioRecordingViewModel
    
    // MARK: - State
    
    @State private var showingPermissionSettings = false
    
    // MARK: - Initialization
    
    init(context: NSManagedObjectContext? = nil) {
        let ctx = context ?? PersistenceController.shared.container.viewContext
        // Create the AudioRecordingService on the main actor
        let recordingService = AudioRecordingService()
        _viewModel = StateObject(wrappedValue: AudioRecordingViewModel(context: ctx, recordingService: recordingService))
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("Voice Journal")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            
            Spacer()
            
            // Waveform visualization
            WaveformView(
                audioLevel: viewModel.visualizationLevel,
                color: recordingColor,
                isActive: viewModel.isRecording && !viewModel.isPaused
            )
            .frame(height: 100)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
            
            // Timer display
            Text(viewModel.formattedDuration)
                .font(.system(size: 48, weight: .medium, design: .monospaced))
                .foregroundColor(recordingColor)
                .padding()
            
            Spacer()
            
            // Recording controls
            recordingControls
                .padding(.bottom, 40)
        }
        .padding()
        .background(Color(.systemBackground))
        .alert("Error", isPresented: $viewModel.showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
        .alert("Microphone Access Required", isPresented: $viewModel.showPermissionDeniedAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Settings") {
                showingPermissionSettings = true
            }
        } message: {
            Text("Voice Journal needs access to your microphone to record audio. Please grant permission in Settings.")
        }
        .sheet(isPresented: $showingPermissionSettings) {
            SettingsView()
        }
        .sheet(isPresented: viewModel.hasRecordingSavedBinding) {
            if let entry = viewModel.journalEntry {
                RecordingSavedView(journalEntry: entry)
            }
        }
        .onAppear {
            checkMicrophonePermission()
        }
    }
    
    // MARK: - Subviews
    
    /// The recording controls view
    private var recordingControls: some View {
        HStack(spacing: 40) {
            // Cancel button (only shown when recording)
            if viewModel.isRecording {
                Button(action: {
                    Task {
                        await viewModel.cancelRecording()
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.red)
                }
                .transition(.scale)
            }
            
            // Record/Stop button
            Button(action: {
                if viewModel.isRecording {
                    Task {
                        await viewModel.stopRecording()
                    }
                } else {
                    Task {
                        await viewModel.startRecording()
                    }
                }
            }) {
                ZStack {
                    Circle()
                        .fill(viewModel.isRecording ? Color.red : Color.blue)
                        .frame(width: 80, height: 80)
                    
                    if viewModel.isRecording {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white)
                            .frame(width: 30, height: 30)
                    }
                }
            }
            .shadow(radius: 3)
            
            // Pause/Resume button (only shown when recording)
            if viewModel.isRecording {
                Button(action: {
                    if viewModel.isPaused {
                        Task {
                            await viewModel.resumeRecording()
                        }
                    } else {
                        Task {
                            await viewModel.pauseRecording()
                        }
                    }
                }) {
                    Image(systemName: viewModel.isPaused ? "play.circle.fill" : "pause.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.blue)
                }
                .transition(.scale)
            }
        }
        .animation(.spring(), value: viewModel.isRecording)
        .animation(.spring(), value: viewModel.isPaused)
    }
    
    // MARK: - Computed Properties
    
    /// The color to use for the recording visualization and timer
    private var recordingColor: Color {
        if !viewModel.isRecording {
            return .gray
        } else if viewModel.isPaused {
            return .orange
        } else {
            return .red
        }
    }
    
    // MARK: - Methods
    
    /// Check if microphone permission is granted
    private func checkMicrophonePermission() {
        Task {
            _ = await viewModel.checkMicrophonePermission()
        }
    }
}

/// A view that shows settings for the app
struct SettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            
            Text("To enable microphone access, please go to your device settings.")
                .multilineTextAlignment(.center)
                .padding()
            
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .padding()
            
            Spacer()
        }
        .padding()
    }
}

/// A view that shows when a recording has been saved
struct RecordingSavedView: View {
    let journalEntry: JournalEntry
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                    .padding()
                
                Text("Recording Saved!")
                    .font(.title)
                    .fontWeight(.bold)
                
                if let title = journalEntry.title {
                    Text(title)
                        .font(.headline)
                }
                
                if let recording = journalEntry.audioRecording {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Duration:")
                            Spacer()
                            Text(formatDuration(recording.duration))
                        }
                        
                        HStack {
                            Text("File Size:")
                            Spacer()
                            Text(formatFileSize(recording.fileSize))
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    /// Format duration in seconds to MM:SS
    private func formatDuration(_ duration: Double) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// Format file size in bytes to human-readable string
    private func formatFileSize(_ size: Int64) -> String {
        let byteCountFormatter = ByteCountFormatter()
        byteCountFormatter.allowedUnits = [.useKB, .useMB]
        byteCountFormatter.countStyle = .file
        
        return byteCountFormatter.string(fromByteCount: size)
    }
}

// MARK: - Preview

#Preview {
    RecordingView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
