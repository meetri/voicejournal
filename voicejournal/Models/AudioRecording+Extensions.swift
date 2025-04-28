//
//  AudioRecording+Extensions.swift
//  voicejournal
//
//  Created on 4/27/25.
//

import Foundation
import CoreData

extension AudioRecording {
    // MARK: - Bookmark Management
    
    /// Create a new bookmark at the specified timestamp
    /// - Parameters:
    ///   - timestamp: The position in seconds where the bookmark is placed
    ///   - label: Optional description for the bookmark
    ///   - color: Optional color for the bookmark (hex string)
    /// - Returns: The newly created bookmark
    func createBookmark(at timestamp: TimeInterval, label: String? = nil, color: String? = nil) -> Bookmark {
        guard let context = managedObjectContext else {
            fatalError("Managed object context is nil")
        }
        
        let bookmark = Bookmark.create(
            at: timestamp,
            label: label,
            color: color,
            for: self,
            in: context
        )
        
        // Save the context
        do {
            try context.save()
        } catch {
            print("Error saving bookmark: \(error.localizedDescription)")
        }
        
        return bookmark
    }
    
    /// Delete a bookmark
    /// - Parameter bookmark: The bookmark to delete
    func deleteBookmark(_ bookmark: Bookmark) {
        guard let context = managedObjectContext else { return }
        
        context.delete(bookmark)
        
        // Save the context
        do {
            try context.save()
        } catch {
            print("Error deleting bookmark: \(error.localizedDescription)")
        }
    }
    
    /// Get all bookmarks for this recording, sorted by timestamp
    var allBookmarks: [Bookmark] {
        guard let context = managedObjectContext else { return [] }
        return Bookmark.fetchAll(for: self, in: context)
    }
    
    /// Find the nearest bookmark to a given timestamp
    /// - Parameter timestamp: The timestamp to search near
    /// - Returns: The nearest bookmark, or nil if no bookmarks exist
    func nearestBookmark(to timestamp: TimeInterval) -> Bookmark? {
        let bookmarks = allBookmarks
        guard !bookmarks.isEmpty else { return nil }
        
        // Find the bookmark with the smallest absolute difference in timestamp
        return bookmarks.min(by: { abs($0.timestamp - timestamp) < abs($1.timestamp - timestamp) })
    }
    
    /// Find the next bookmark after a given timestamp
    /// - Parameter timestamp: The current timestamp
    /// - Returns: The next bookmark, or nil if no bookmarks exist after the timestamp
    func nextBookmark(after timestamp: TimeInterval) -> Bookmark? {
        let bookmarks = allBookmarks
        
        // Filter bookmarks that are after the current timestamp
        let futureBookmarks = bookmarks.filter { $0.timestamp > timestamp }
        
        // Return the bookmark with the smallest timestamp (closest next one)
        return futureBookmarks.min(by: { $0.timestamp < $1.timestamp })
    }
    
    /// Find the previous bookmark before a given timestamp
    /// - Parameter timestamp: The current timestamp
    /// - Returns: The previous bookmark, or nil if no bookmarks exist before the timestamp
    func previousBookmark(before timestamp: TimeInterval) -> Bookmark? {
        let bookmarks = allBookmarks
        
        // Filter bookmarks that are before the current timestamp
        let pastBookmarks = bookmarks.filter { $0.timestamp < timestamp }
        
        // Return the bookmark with the largest timestamp (closest previous one)
        return pastBookmarks.max(by: { $0.timestamp < $1.timestamp })
    }
}
