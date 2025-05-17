//
//  TimelineViewModelDebug.swift
//  voicejournal
//
//  Created on 5/4/25.
//

import Foundation
import CoreData

#if DEBUG
/// Extension with debugging methods for TimelineViewModel
extension TimelineViewModel {
    
    /// Debug method to print information about all entries in the database
    func debugPrintAllEntries() {
        // Access context through a public method to avoid private access issues
        guard let context = getCurrentContext() else {
            print("❌ ERROR: Failed to get context for debugging")
            return
        }
        
        let request: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \JournalEntry.createdAt, ascending: false)]
        
        do {
            let allEntries = try context.fetch(request)
            print("📊 DEBUG: Found \(allEntries.count) total entries in the database")
            
            for (index, entry) in allEntries.enumerated() {
                print("  📝 Entry #\(index + 1): \(entry.title ?? "Untitled") (ID: \(entry.objectID))")
                
                // Print date information
                if let date = entry.createdAt {
                    print("    📅 Created: \(date)")
                }
                
                // Print tag information
                if let tags = entry.tags as? Set<Tag>, !tags.isEmpty {
                    print("    🏷 Regular tags: \(tags.count)")
                    for tag in tags {
                        print("      - \(tag.name ?? "unnamed") (ID: \(tag.objectID), Encrypted: \(tag.isEncrypted))")
                    }
                } else {
                    print("    🏷 No regular tags")
                }
                
                // Print encrypted tag information
                if let encryptedTag = entry.encryptedTag {
                    print("    🔒 Encrypted tag: \(encryptedTag.name ?? "unnamed") (ID: \(encryptedTag.objectID))")
                    print("    🔑 Has global access: \(encryptedTag.hasGlobalAccess)")
                } else {
                    print("    🔓 No encrypted tag")
                }
                
                // Print if it would be filtered out
                let wouldBeFiltered = shouldFilterEntry(entry)
                print("    🔍 Would be filtered out: \(wouldBeFiltered)")
                
                print("") // Empty line for readability
            }
        } catch {
            print("❌ ERROR: Failed to fetch entries for debugging: \(error)")
        }
    }
    
    /// Return the current context for debugging purposes
    func getCurrentContext() -> NSManagedObjectContext? {
        // We'll access this through reflection to avoid changing the private access
        let mirror = Mirror(reflecting: self)
        for child in mirror.children {
            if child.label == "viewContext", let context = child.value as? NSManagedObjectContext {
                return context
            }
        }
        return nil
    }
    
    /// Debug method to check if an entry would be filtered out
    private func shouldFilterEntry(_ entry: JournalEntry) -> Bool {
        // Check if entry has encrypted tag without global access
        if let encryptedTag = entry.encryptedTag, !encryptedTag.hasGlobalAccess {
            return true
        }
        
        // Entry passes filters
        return false
    }
    
    /// Debug method to print information about the predicates being used
    func debugPrintPredicates() {
        print("📆 DEBUG: Current date range: \(dateRange.displayName)")
        
        // Get encrypted tags without access
        if let context = getCurrentContext() {
            let request: NSFetchRequest<Tag> = Tag.fetchRequest()
            request.predicate = NSPredicate(format: "isEncrypted == YES")
            
            do {
                let encryptedTags = try context.fetch(request)
                let accessManager = EncryptedTagsAccessManager.shared
                let tagsWithoutAccess = encryptedTags.filter { !accessManager.hasAccess(to: $0) }
                
                print("🔒 DEBUG: Found \(tagsWithoutAccess.count) encrypted tags without access")
                for tag in tagsWithoutAccess {
                    print("  - \(tag.name ?? "unnamed") (ID: \(tag.objectID))")
                }
                
                // Build predicate description
                var predicateDescriptions: [String] = []
                
                // Date range predicate
                predicateDescriptions.append("Date range: uses current date range (\(dateRange.displayName))")
                
                // Search predicate
                if !searchText.isEmpty {
                    predicateDescriptions.append("Search: title or transcription contains '\(searchText)'")
                }
                
                // Tag filter predicate
                if !selectedTags.isEmpty {
                    switch tagFilterMode {
                    case .all:
                        predicateDescriptions.append("Tags: entry must have ALL \(selectedTags.count) selected tags")
                    case .any:
                        predicateDescriptions.append("Tags: entry must have ANY of the \(selectedTags.count) selected tags")
                    case .exclude:
                        predicateDescriptions.append("Tags: entry must NOT have any of the \(selectedTags.count) selected tags")
                    }
                }
                
                // Encrypted tag filter
                if !tagsWithoutAccess.isEmpty {
                    predicateDescriptions.append("Exclude entries with encrypted tags that don't have global access")
                }
                
                print("🔍 DEBUG: Predicates being used:")
                for (index, desc) in predicateDescriptions.enumerated() {
                    print("  \(index + 1). \(desc)")
                }
            } catch {
                print("❌ ERROR: Failed to fetch encrypted tags for debugging: \(error)")
            }
        }
    }
}
#endif