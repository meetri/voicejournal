//
//  JournalEntryRow+Debug.swift
//  voicejournal
//
//  Created on 5/4/25.
//

import SwiftUI
import CoreData

#if DEBUG
// This file adds debug functionality to help diagnose tag display issues

extension JournalEntryRow {
    
    func printTagInfo() {
        // Print encrypted tag info
        if let encryptedTag = entry.encryptedTag {
            print("🔒 Encrypted tag: \(encryptedTag.name ?? "unnamed") (ID: \(encryptedTag.objectID))")
        } else {
            print("🔒 No encrypted tag")
        }
        
        // Print regular tags info
        if let tags = entry.tags as? Set<Tag>, !tags.isEmpty {
            print("🏷 Regular tags: \(tags.count)")
            for tag in tags {
                print("  - \(tag.name ?? "unnamed") (ID: \(tag.objectID))")
            }
        } else {
            print("🏷 No regular tags")
        }
    }
}
#endif