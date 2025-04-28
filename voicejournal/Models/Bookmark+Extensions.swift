//
//  Bookmark+Extensions.swift
//  voicejournal
//
//  Created on 4/27/25.
//

import Foundation
import CoreData

extension Bookmark {
    // MARK: - Constants
    
    /// Default colors for bookmarks
    static let defaultColors = [
        "#FF5733", // Red-Orange
        "#33FF57", // Green
        "#3357FF", // Blue
        "#F3FF33", // Yellow
        "#FF33F3", // Pink
        "#33FFF3", // Cyan
        "#FF8033", // Orange
        "#8033FF"  // Purple
    ]
    
    // MARK: - Convenience Methods
    
    /// Create a new bookmark for an audio recording
    /// - Parameters:
    ///   - timestamp: The position in seconds where the bookmark is placed
    ///   - label: Optional description for the bookmark
    ///   - color: Optional color for the bookmark (hex string)
    ///   - recording: The audio recording to associate with this bookmark
    ///   - context: The managed object context
    /// - Returns: The newly created bookmark
    static func create(
        at timestamp: TimeInterval,
        label: String? = nil,
        color: String? = nil,
        for recording: AudioRecording,
        in context: NSManagedObjectContext
    ) -> Bookmark {
        let bookmark = Bookmark(context: context)
        bookmark.timestamp = timestamp
        bookmark.label = label
        bookmark.color = color ?? defaultColors.randomElement()!
        bookmark.createdAt = Date()
        bookmark.audioRecording = recording
        
        return bookmark
    }
    
    /// Format the timestamp as a string (MM:SS)
    var formattedTimestamp: String {
        let minutes = Int(timestamp) / 60
        let seconds = Int(timestamp) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    /// Save changes to the bookmark
    func save() throws {
        try audioRecording?.journalEntry?.managedObjectContext?.save()
    }
}

// MARK: - Fetch Requests

extension Bookmark {
    /// Fetch all bookmarks for a specific audio recording
    /// - Parameters:
    ///   - recording: The audio recording
    ///   - context: The managed object context
    /// - Returns: Array of bookmarks sorted by timestamp
    static func fetchAll(for recording: AudioRecording, in context: NSManagedObjectContext) -> [Bookmark] {
        let request: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        request.predicate = NSPredicate(format: "audioRecording == %@", recording)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Bookmark.timestamp, ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching bookmarks: \(error)")
            return []
        }
    }
}
