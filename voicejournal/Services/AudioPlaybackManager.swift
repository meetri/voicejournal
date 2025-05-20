//
//  AudioPlaybackManager.swift
//  voicejournal
//
//  Created on 5/19/25.
//

import Foundation
import AVFoundation
import CoreData
import CryptoKit

/// Manages audio playback with integrated decryption support
/// This singleton handles all audio playback operations independently of Core Data state
class AudioPlaybackManager: NSObject, ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = AudioPlaybackManager()
    
    // MARK: - Properties
    
    /// Audio player instance
    private var audioPlayer: AVAudioPlayer?
    
    /// Audio engine for spectrum analysis
    private let audioEngine = AVAudioEngine()
    private var playerNode: AVAudioPlayerNode?
    private var audioFile: AVAudioFile?
    
    /// Spectrum analyzer service reference
    private weak var spectrumAnalyzerService: SpectrumAnalyzerService?
    
    /// Cache of decrypted audio paths mapped by entry object ID
    private var decryptedPathCache: [NSManagedObjectID: String] = [:]
    
    /// Currently playing entry ID
    private var currentlyPlayingEntryID: NSManagedObjectID?
    
    /// Temporary directory for decrypted files
    private let tempDirectory: URL
    
    /// Cleanup timer
    private var cleanupTimer: Timer?
    
    // MARK: - Published Properties
    
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playbackError: Error?
    
    // MARK: - Initialization
    
    private override init() {
        // Create temp directory for decrypted files
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.tempDirectory = documentsDirectory.appendingPathComponent("AudioPlaybackCache", isDirectory: true)
        
        super.init()
        
        // Ensure temp directory exists
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // Setup cleanup timer
        setupCleanupTimer()
        
        // Setup audio session
        setupAudioSession()
    }
    
    // MARK: - Audio Session Setup
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ [AudioPlaybackManager] Failed to setup audio session: \(error)")
        }
    }
    
    // MARK: - Playback Methods
    
    /// Set the spectrum analyzer service
    func setSpectrumAnalyzerService(_ service: SpectrumAnalyzerService) {
        spectrumAnalyzerService = service
        print("🔊 [AudioPlaybackManager] SpectrumAnalyzerService registered")
    }
    
    /// Load and prepare audio for a journal entry
    func loadAudio(for entry: JournalEntry) {
        print("🎵 [AudioPlaybackManager] Loading audio for entry: \(entry.objectID)")
        
        // Clear any previous error
        playbackError = nil
        
        // Clean up previous decrypted file if we're loading a different entry
        if let currentID = currentlyPlayingEntryID, currentID != entry.objectID {
            // Use a background queue for file cleanup
            DispatchQueue.global(qos: .utility).async { [weak self] in
                guard let self = self else { return }
                self.clearCache(for: currentID)
                print("🧹 [AudioPlaybackManager] Cleaned up previous entry's audio file")
            }
        }
        
        // Get audio recording
        guard let audioRecording = entry.audioRecording else {
            print("❌ [AudioPlaybackManager] No audio recording found")
            playbackError = AudioManagerError.noAudioRecording
            return
        }
        
        // Get the audio file URL
        if let audioURL = getAudioURL(for: entry, recording: audioRecording) {
            print("✅ [AudioPlaybackManager] Audio URL obtained: \(audioURL.path)")
            loadAudioFile(at: audioURL, for: entry.objectID)
            
            // Set up engine and player node for spectrum analysis
            setupSpectrumAnalysis(fileURL: audioURL)
        } else {
            print("❌ [AudioPlaybackManager] Failed to get audio URL")
            playbackError = AudioManagerError.failedToGetAudioURL
        }
    }
    
    /// Set up engine and player node for spectrum analysis
    private func setupSpectrumAnalysis(fileURL: URL) {
        print("📊 [AudioPlaybackManager] Setting up spectrum analysis for: \(fileURL.lastPathComponent)")
        
        // Clean up any existing engine setup
        cleanupSpectrumAnalysis()
        
        do {
            // Create audio file for spectrum analysis
            audioFile = try AVAudioFile(forReading: fileURL)
            
            // Create player node
            let player = AVAudioPlayerNode()
            audioEngine.attach(player)
            self.playerNode = player
            
            if let file = audioFile {
                // Connect player to main mixer (required for AVAudioEngine to work)
                audioEngine.connect(player, to: audioEngine.mainMixerNode, format: file.processingFormat)
                
                // Set player volume to 0 to prevent audio output
                player.volume = 0.0
                
                // Install tap on the player node to capture audio data
                let bufferSize = AVAudioFrameCount(1024) // Use appropriate buffer size for FFT
                player.installTap(onBus: 0, bufferSize: bufferSize, format: file.processingFormat) { [weak self] buffer, _ in
                    // Forward the buffer to spectrum analyzer service
                    self?.spectrumAnalyzerService?.processAudioBuffer(buffer)
                }
                
                // Start the engine but don't start playing yet
                // That will happen when play() is called
                try audioEngine.start()
                
                print("🎵 [AudioPlaybackManager] Audio engine setup complete for spectrum analysis")
                print("📊 [AudioPlaybackManager] Audio file format: \(file.processingFormat), length: \(file.length) frames")
            }
        } catch {
            print("❌ [AudioPlaybackManager] Failed to set up spectrum analysis: \(error)")
        }
    }
    
    /// Clean up spectrum analysis resources
    private func cleanupSpectrumAnalysis() {
        // Stop the engine first to prevent any race conditions
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        // Clean up player node
        if let player = playerNode {
            player.removeTap(onBus: 0)
            player.stop()
            audioEngine.detach(player)
            playerNode = nil
        }
        
        audioFile = nil
        print("🧹 [AudioPlaybackManager] Cleaned up spectrum analysis resources")
    }
    
    /// Play the loaded audio
    func play() {
        guard let player = audioPlayer else {
            print("❌ [AudioPlaybackManager] No audio player available")
            return
        }
        
        // Get current time for synchronized playback
        let currentTimePosition = player.currentTime
        let wasAlreadyPlaying = isPlaying
        
        player.play()
        isPlaying = true
        startPlaybackTimer()
        print("▶️ [AudioPlaybackManager] Playback started")
        
        // Handling spectrum analysis playback
        if let playerNode = playerNode, let audioFile = audioFile {
            // Only restart playback if we weren't already playing
            // or if current time is at the beginning
            if !wasAlreadyPlaying {
                playerNode.stop()
                
                // If resuming from a paused state (non-zero position)
                if currentTimePosition > 0.01 {
                    // Calculate frame position for synchronized resume
                    let framePosition = AVAudioFramePosition(currentTimePosition * audioFile.processingFormat.sampleRate)
                    let frameCount = AVAudioFrameCount(audioFile.length - framePosition)
                    
                    // Schedule file from current position
                    playerNode.scheduleSegment(
                        audioFile,
                        startingFrame: framePosition,
                        frameCount: frameCount,
                        at: nil
                    )
                    print("🎵 [AudioPlaybackManager] Resumed player node from position: \(currentTimePosition)")
                } else {
                    // Start from beginning
                    playerNode.scheduleFile(audioFile, at: nil)
                    print("🎵 [AudioPlaybackManager] Started player node from beginning")
                }
                
                playerNode.play()
            }
        }
        
        // Post notification for other listeners
        NotificationCenter.default.post(
            name: .AudioPlaybackManagerDidPlay,
            object: audioPlayer?.url
        )
    }
    
    /// Pause playback
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopPlaybackTimer()
        print("⏸ [AudioPlaybackManager] Playback paused")
        
        // Pause the player node for spectrum analysis
        playerNode?.pause()
        
        // Post notification for other listeners
        NotificationCenter.default.post(
            name: .AudioPlaybackManagerDidPause,
            object: nil
        )
    }
    
    /// Stop playback
    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        isPlaying = false
        currentTime = 0
        stopPlaybackTimer()
        print("⏹ [AudioPlaybackManager] Playback stopped")
        
        // Stop the player node for spectrum analysis and reset it
        if let playerNode = playerNode {
            playerNode.stop()
            print("🎵 [AudioPlaybackManager] Stopped player node for spectrum analysis")
        }
        
        // Post notification for other listeners
        NotificationCenter.default.post(
            name: .AudioPlaybackManagerDidStop,
            object: nil
        )
    }
    
    /// Seek to specific time
    func seek(to time: TimeInterval) {
        // Set time on main audio player
        audioPlayer?.currentTime = time
        currentTime = time
        
        // Synchronize the player node for spectrum analysis
        if let playerNode = playerNode, let audioFile = audioFile {
            let wasPlaying = playerNode.isPlaying
            
            // Calculate frame position
            let framePosition = AVAudioFramePosition(time * audioFile.processingFormat.sampleRate)
            
            // Stop current playback
            playerNode.stop()
            
            // Validate frame position to ensure it's within bounds
            let safeFramePosition = max(0, min(framePosition, audioFile.length - 1))
            
            // Calculate remaining frames
            let frameCount = AVAudioFrameCount(audioFile.length - safeFramePosition)
            
            // Schedule file from the new position
            playerNode.scheduleSegment(
                audioFile,
                startingFrame: safeFramePosition,
                frameCount: frameCount,
                at: nil
            )
            
            // Resume if it was playing
            if wasPlaying {
                playerNode.play()
            }
            
            print("🎵 [AudioPlaybackManager] Seeked player node to position: \(time)")
        }
    }
    
    // MARK: - Private Methods
    
    private func getAudioURL(for entry: JournalEntry, recording: AudioRecording) -> URL? {
        let entryID = entry.objectID
        
        // Check our internal cache first
        if let cachedPath = decryptedPathCache[entryID],
           FileManager.default.fileExists(atPath: cachedPath) {
            print("🎯 [AudioPlaybackManager] Using cached decrypted path: \(cachedPath)")
            return URL(fileURLWithPath: cachedPath)
        }
        
        // Check if recording has a temporary decrypted path from JournalEntry decryption
        if let tempPath = recording.tempDecryptedPath,
           FileManager.default.fileExists(atPath: tempPath) {
            print("🎯 [AudioPlaybackManager] Using existing decrypted file from JournalEntry: \(tempPath)")
            // Store in our cache too for consistency
            decryptedPathCache[entryID] = tempPath
            return URL(fileURLWithPath: tempPath)
        }
        
        // If encrypted and no decrypted file exists yet, decrypt the file
        if recording.isEncrypted {
            print("🔐 [AudioPlaybackManager] Audio is encrypted, attempting decryption")
            
            if let decryptedURL = decryptAudioFile(for: entry, recording: recording) {
                print("✅ [AudioPlaybackManager] Audio decrypted successfully")
                return decryptedURL
            } else {
                print("❌ [AudioPlaybackManager] Failed to decrypt audio")
                return nil
            }
        }
        
        // For unencrypted files, use the direct path
        if let filePath = recording.filePath {
            let absoluteURL = FilePathUtility.toAbsolutePath(from: filePath)
            print("📁 [AudioPlaybackManager] Using unencrypted file: \(absoluteURL.path)")
            return absoluteURL
        }
        
        return nil
    }
    
    private func decryptAudioFile(for entry: JournalEntry, recording: AudioRecording) -> URL? {
        guard let filePath = recording.filePath else {
            print("❌ [AudioPlaybackManager] No file path available")
            return nil
        }
        
        // Determine which key to use
        var decryptionKey: SymmetricKey?
        
        if entry.hasEncryptedContent,
           let encryptedTag = entry.encryptedTag {
            // Try to get tag encryption key
            decryptionKey = EncryptedTagsAccessManager.shared.getEncryptionKey(for: encryptedTag)
            if decryptionKey != nil {
                print("🔑 [AudioPlaybackManager] Using tag encryption key for \(encryptedTag.name ?? "unnamed tag")")
            } else {
                print("❌ [AudioPlaybackManager] No encryption key available for tag \(encryptedTag.name ?? "unnamed tag")")
                print("⚠️ [AudioPlaybackManager] This usually means the tag is encrypted but no PIN has been entered")
                print("⚠️ [AudioPlaybackManager] Or the PIN was entered but the entry view hasn't been fully decrypted yet")
            }
        }
        
        if decryptionKey == nil && entry.isBaseEncrypted {
            // Fall back to base encryption key
            decryptionKey = EncryptionManager.getEncryptionKey()
            if decryptionKey != nil {
                print("🔑 [AudioPlaybackManager] Using base encryption key")
            }
        }
        
        guard let key = decryptionKey else {
            print("❌ [AudioPlaybackManager] No decryption key available")
            return nil
        }
        
        // Read encrypted file
        let encryptedURL = FilePathUtility.toAbsolutePath(from: filePath)
        
        // Create a semaphore to wait for async decryption
        let semaphore = DispatchSemaphore(value: 0)
        var decryptedURL: URL?
        
        do {
            let encryptedData = try Data(contentsOf: encryptedURL)
            print("📖 [AudioPlaybackManager] Read encrypted data: \(encryptedData.count) bytes")
            
            // Decrypt the data asynchronously but wait for completion
            EncryptionManager.decryptAsync(encryptedData, using: key) { decryptedData in
                defer { semaphore.signal() }
                
                guard let decryptedData = decryptedData else {
                    print("❌ [AudioPlaybackManager] Failed to decrypt data")
                    return
                }
                
                do {
                    // Generate unique filename for this entry
                    let filename = "\(entry.objectID.uriRepresentation().lastPathComponent).m4a"
                    let tempURL = self.tempDirectory.appendingPathComponent(filename)
                    
                    // Write decrypted data
                    try decryptedData.write(to: tempURL)
                    print("💾 [AudioPlaybackManager] Wrote decrypted file: \(tempURL.path)")
                    
                    // Cache the path
                    self.decryptedPathCache[entry.objectID] = tempURL.path
                    
                    // Set the result
                    decryptedURL = tempURL
                } catch {
                    print("❌ [AudioPlaybackManager] Error writing decrypted file: \(error)")
                }
            }
            
            // Wait for decryption to complete with a timeout
            // Increase timeout from 10s to 30s to ensure enough time for large files
            _ = semaphore.wait(timeout: .now() + 30.0) // 30 second timeout
            
            return decryptedURL
            
        } catch {
            print("❌ [AudioPlaybackManager] Decryption error: \(error)")
            return nil
        }
    }
    
    /// Asynchronous version of decryptAudioFile for use with async/await
    private func decryptAudioFileAsync(for entry: JournalEntry, recording: AudioRecording) async -> URL? {
        guard let filePath = recording.filePath else {
            print("❌ [AudioPlaybackManager] No file path available")
            return nil
        }
        
        // Determine which key to use
        var decryptionKey: SymmetricKey?
        
        if entry.hasEncryptedContent,
           let encryptedTag = entry.encryptedTag {
            // Try to get tag encryption key
            decryptionKey = EncryptedTagsAccessManager.shared.getEncryptionKey(for: encryptedTag)
            if decryptionKey != nil {
                print("🔑 [AudioPlaybackManager] Using tag encryption key for \(encryptedTag.name ?? "unnamed tag")")
            } else {
                print("❌ [AudioPlaybackManager] No encryption key available for tag \(encryptedTag.name ?? "unnamed tag")")
                print("⚠️ [AudioPlaybackManager] This usually means the tag is encrypted but no PIN has been entered")
                print("⚠️ [AudioPlaybackManager] Or the PIN was entered but the entry view hasn't been fully decrypted yet")
            }
        }
        
        if decryptionKey == nil && entry.isBaseEncrypted {
            // Fall back to base encryption key
            decryptionKey = EncryptionManager.getEncryptionKey()
            if decryptionKey != nil {
                print("🔑 [AudioPlaybackManager] Using base encryption key")
            }
        }
        
        guard let key = decryptionKey else {
            print("❌ [AudioPlaybackManager] No decryption key available")
            return nil
        }
        
        // Read encrypted file
        let encryptedURL = FilePathUtility.toAbsolutePath(from: filePath)
        
        do {
            let encryptedData = try Data(contentsOf: encryptedURL)
            print("📖 [AudioPlaybackManager] Read encrypted data: \(encryptedData.count) bytes")
            
            // Decrypt the data asynchronously
            guard let decryptedData = await EncryptionManager.decryptAsync(encryptedData, using: key) else {
                print("❌ [AudioPlaybackManager] Failed to decrypt data")
                return nil
            }
            
            // Generate unique filename for this entry
            let filename = "\(entry.objectID.uriRepresentation().lastPathComponent).m4a"
            let decryptedURL = tempDirectory.appendingPathComponent(filename)
            
            // Write decrypted data
            try decryptedData.write(to: decryptedURL)
            print("💾 [AudioPlaybackManager] Wrote decrypted file: \(decryptedURL.path)")
            
            // Cache the path
            decryptedPathCache[entry.objectID] = decryptedURL.path
            
            return decryptedURL
            
        } catch {
            print("❌ [AudioPlaybackManager] Decryption error: \(error)")
            return nil
        }
    }
    
    private func loadAudioFile(at url: URL, for entryID: NSManagedObjectID) {
        do {
            // Stop any existing playback
            stop()
            
            // Create new audio player
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            // Update properties
            duration = audioPlayer?.duration ?? 0
            currentlyPlayingEntryID = entryID
            
            print("✅ [AudioPlaybackManager] Audio loaded successfully. Duration: \(duration)")
            
            // Post notification with URL for spectrum analyzer
            NotificationCenter.default.post(
                name: .AudioPlaybackManagerDidLoadAudio,
                object: url
            )
            
            // Also post notification on play to ensure spectrum analyzer receives the audio file URL
            NotificationCenter.default.post(
                name: .AudioPlaybackManagerWillPlay,
                object: url
            )
            
        } catch {
            print("❌ [AudioPlaybackManager] Failed to load audio: \(error)")
            playbackError = error
            
            // Post error notification
            NotificationCenter.default.post(
                name: .AudioPlaybackManagerDidEncounterError,
                object: error
            )
        }
    }
    
    // MARK: - Cleanup
    
    private func setupCleanupTimer() {
        // Reduce cleanup interval from 300s (5 min) to 60s (1 min) 
        // to more aggressively clean up orphaned decrypted files
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            // Run cleanup on a background queue
            DispatchQueue.global(qos: .utility).async {
                self?.cleanupOldFiles()
            }
        }
    }
    
    private func cleanupOldFiles() {
        let fileManager = FileManager.default
        // Reduce age threshold from 3600s (1 hour) to 300s (5 minutes)
        // since we're now explicitly cleaning up files after playback
        let cutoffDate = Date().addingTimeInterval(-300) // 5 minutes ago
        
        do {
            let files = try fileManager.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: [.creationDateKey])
            
            for file in files {
                if let attributes = try? file.resourceValues(forKeys: [.creationDateKey]),
                   let creationDate = attributes.creationDate,
                   creationDate < cutoffDate {
                    try? fileManager.removeItem(at: file)
                    print("🗑 [AudioPlaybackManager] Cleaned up old file: \(file.lastPathComponent)")
                }
            }
        } catch {
            print("❌ [AudioPlaybackManager] Cleanup error: \(error)")
        }
    }
    
    /// Clear cache for a specific entry
    func clearCache(for entryID: NSManagedObjectID) {
        if let cachedPath = decryptedPathCache[entryID] {
            if FileManager.default.fileExists(atPath: cachedPath) {
                do {
                    try FileManager.default.removeItem(atPath: cachedPath)
                    print("🗑 [AudioPlaybackManager] Deleted cache file: \(cachedPath)")
                } catch {
                    print("⚠️ [AudioPlaybackManager] Failed to delete cache file: \(error)")
                }
            } else {
                print("ℹ️ [AudioPlaybackManager] Cache file already removed: \(cachedPath)")
            }
            
            decryptedPathCache.removeValue(forKey: entryID)
            print("🗑 [AudioPlaybackManager] Cleared cache entry for: \(entryID)")
        }
    }
    
    /// Clear all cached files
    func clearAllCache() {
        let fileManager = FileManager.default
        
        // Remove all cached files
        for (id, path) in decryptedPathCache {
            if fileManager.fileExists(atPath: path) {
                do {
                    try fileManager.removeItem(atPath: path)
                    print("🗑 [AudioPlaybackManager] Deleted cached file for entry \(id): \(path)")
                } catch {
                    print("⚠️ [AudioPlaybackManager] Failed to delete cached file: \(path), error: \(error)")
                }
            }
        }
        
        // Clear the cache dictionary
        decryptedPathCache.removeAll()
        
        // Also clean any orphaned files in the temp directory
        do {
            let files = try fileManager.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
            for file in files {
                try? fileManager.removeItem(at: file)
                print("🧹 [AudioPlaybackManager] Removed orphaned file: \(file.lastPathComponent)")
            }
        } catch {
            print("⚠️ [AudioPlaybackManager] Failed to clean temp directory: \(error)")
        }
        
        print("🗑 [AudioPlaybackManager] Cleared all cached files")
    }
    
    // MARK: - Timer Management
    
    private var playbackTimer: Timer?
    
    private func startPlaybackTimer() {
        // Reduced timer frequency from 10Hz (0.1s) to 5Hz (0.2s)
        // This decreases UI refresh rate by 50% while still maintaining smooth progress updates
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.updatePlaybackTime()
        }
    }
    
    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    private func updatePlaybackTime() {
        currentTime = audioPlayer?.currentTime ?? 0
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioPlaybackManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Update playback state
            self.isPlaying = false
            self.currentTime = 0
            self.stopPlaybackTimer()
            print("🏁 [AudioPlaybackManager] Playback finished")
            
            // Post notification for spectrum analyzer and other listeners
            NotificationCenter.default.post(
                name: .AudioPlaybackManagerDidFinishPlaying,
                object: nil
            )
            
            // Clean up decrypted file immediately when playback finishes
            if let entryID = self.currentlyPlayingEntryID {
                // Use a background queue for file operations
                DispatchQueue.global(qos: .utility).async {
                    self.clearCache(for: entryID)
                    print("🧹 [AudioPlaybackManager] Cleaned up decrypted file after playback")
                }
                
                // Clear the current entry reference
                self.currentlyPlayingEntryID = nil
            }
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Update playback state
            self.playbackError = error
            self.isPlaying = false
            self.stopPlaybackTimer()
            print("❌ [AudioPlaybackManager] Decode error: \(error?.localizedDescription ?? "Unknown")")
            
            // Clean up decrypted file on error
            if let entryID = self.currentlyPlayingEntryID {
                // Use a background queue for file operations
                DispatchQueue.global(qos: .utility).async {
                    self.clearCache(for: entryID)
                    print("🧹 [AudioPlaybackManager] Cleaned up decrypted file after playback error")
                }
                
                // Clear the current entry reference
                self.currentlyPlayingEntryID = nil
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let AudioPlaybackManagerDidLoadAudio = Notification.Name("AudioPlaybackManagerDidLoadAudio")
    static let AudioPlaybackManagerWillPlay = Notification.Name("AudioPlaybackManagerWillPlay")
    static let AudioPlaybackManagerDidPlay = Notification.Name("AudioPlaybackManagerDidPlay")
    static let AudioPlaybackManagerDidPause = Notification.Name("AudioPlaybackManagerDidPause")
    static let AudioPlaybackManagerDidStop = Notification.Name("AudioPlaybackManagerDidStop")
    static let AudioPlaybackManagerDidFinishPlaying = Notification.Name("AudioPlaybackManagerDidFinishPlaying")
    static let AudioPlaybackManagerDidEncounterError = Notification.Name("AudioPlaybackManagerDidEncounterError")
}

// MARK: - Error Types

enum AudioManagerError: LocalizedError {
    case noAudioRecording
    case failedToGetAudioURL
    case failedToDecrypt
    case fileNotFound
    
    var errorDescription: String? {
        switch self {
        case .noAudioRecording:
            return "No audio recording found for this entry"
        case .failedToGetAudioURL:
            return "Failed to get audio file URL"
        case .failedToDecrypt:
            return "Failed to decrypt audio file"
        case .fileNotFound:
            return "Audio file not found"
        }
    }
}