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
    
    /// Load and prepare audio for a journal entry
    func loadAudio(for entry: JournalEntry) {
        print("🎵 [AudioPlaybackManager] Loading audio for entry: \(entry.objectID)")
        
        // Clear any previous error
        playbackError = nil
        
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
        } else {
            print("❌ [AudioPlaybackManager] Failed to get audio URL")
            playbackError = AudioManagerError.failedToGetAudioURL
        }
    }
    
    /// Play the loaded audio
    func play() {
        guard let player = audioPlayer else {
            print("❌ [AudioPlaybackManager] No audio player available")
            return
        }
        
        player.play()
        isPlaying = true
        startPlaybackTimer()
        print("▶️ [AudioPlaybackManager] Playback started")
    }
    
    /// Pause playback
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopPlaybackTimer()
        print("⏸ [AudioPlaybackManager] Playback paused")
    }
    
    /// Stop playback
    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        isPlaying = false
        currentTime = 0
        stopPlaybackTimer()
        print("⏹ [AudioPlaybackManager] Playback stopped")
    }
    
    /// Seek to specific time
    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
    }
    
    // MARK: - Private Methods
    
    private func getAudioURL(for entry: JournalEntry, recording: AudioRecording) -> URL? {
        let entryID = entry.objectID
        
        // Check cache first
        if let cachedPath = decryptedPathCache[entryID],
           FileManager.default.fileExists(atPath: cachedPath) {
            print("🎯 [AudioPlaybackManager] Using cached decrypted path: \(cachedPath)")
            return URL(fileURLWithPath: cachedPath)
        }
        
        // If encrypted, decrypt the file
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
                print("🔑 [AudioPlaybackManager] Using tag encryption key")
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
            
            // Decrypt the data
            guard let decryptedData = EncryptionManager.decrypt(encryptedData, using: key) else {
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
            
        } catch {
            print("❌ [AudioPlaybackManager] Failed to load audio: \(error)")
            playbackError = error
        }
    }
    
    // MARK: - Cleanup
    
    private func setupCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.cleanupOldFiles()
        }
    }
    
    private func cleanupOldFiles() {
        let fileManager = FileManager.default
        let cutoffDate = Date().addingTimeInterval(-3600) // 1 hour ago
        
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
            try? FileManager.default.removeItem(atPath: cachedPath)
            decryptedPathCache.removeValue(forKey: entryID)
            print("🗑 [AudioPlaybackManager] Cleared cache for entry: \(entryID)")
        }
    }
    
    /// Clear all cached files
    func clearAllCache() {
        let fileManager = FileManager.default
        
        // Remove all cached files
        for (_, path) in decryptedPathCache {
            try? fileManager.removeItem(atPath: path)
        }
        
        // Clear the cache dictionary
        decryptedPathCache.removeAll()
        
        print("🗑 [AudioPlaybackManager] Cleared all cached files")
    }
    
    // MARK: - Timer Management
    
    private var playbackTimer: Timer?
    
    private func startPlaybackTimer() {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
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
            self?.isPlaying = false
            self?.currentTime = 0
            self?.stopPlaybackTimer()
            print("🏁 [AudioPlaybackManager] Playback finished")
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.playbackError = error
            self?.isPlaying = false
            self?.stopPlaybackTimer()
            print("❌ [AudioPlaybackManager] Decode error: \(error?.localizedDescription ?? "Unknown")")
        }
    }
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