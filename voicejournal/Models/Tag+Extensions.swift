//
//  Tag+Extensions.swift
//  voicejournal
//
//  Created on 4/29/25.
//

import Foundation
import CoreData
import SwiftUI // For Color
import CryptoKit

extension Tag {
    // MARK: - Relationship Properties
    
    // Get count of entries encrypted with this tag
    var encryptedEntriesCount: Int {
        if let entries = self.encryptedEntries {
            return entries.count
        }
        return 0
    }
    
    // MARK: - Convenience Properties
    
    /// Returns the tag's color as a SwiftUI Color, defaulting to blue if nil or invalid.
    var swiftUIColor: Color {
        Color(hex: self.color ?? "#007AFF")
    }
    
    /// Data property to store salt data for PIN hashing
    var saltData: Data? {
        get {
            if let base64Salt = self.pinSalt {
                return Data(base64Encoded: base64Salt)
            }
            return nil
        }
        set {
            self.pinSalt = newValue?.base64EncodedString()
        }
    }
    
    // MARK: - Encryption Related Properties & Methods
    
    // Note: 'pinSalt' property is defined in the Core Data model
    // and will be generated automatically in Tag+CoreDataProperties.swift
    // /// Additional property to store PIN salt for hashing
    // @NSManaged var pinSalt: String?
    
    /// Set a PIN for this tag, making it an encrypted tag
    func setEncryptionPin(_ pin: String) -> Bool {
        guard pin.count >= 4 else { return false }
        
        // Generate a new salt
        let salt = EncryptionManager.generateSalt()
        self.saltData = salt
        
        // Hash the PIN with the salt
        guard let hashedPin = EncryptionManager.hashPin(pin, salt: salt) else {
            return false
        }
        
        // Create a unique key identifier based on objectID
        let keyIdentifier = EncryptionManager.generateKeyIdentifier(for: self.objectID.uriRepresentation().absoluteString)
        
        // Generate an encryption key from the PIN and salt
        let encryptionKey = EncryptionManager.generateEncryptionKey(from: pin, salt: salt)
        
        // Save the encryption key to the keychain
        let keySaved = EncryptionManager.saveTagEncryptionKey(encryptionKey, for: keyIdentifier)
        
        if keySaved {
            // Set encrypted tag properties
            self.pinHash = hashedPin
            self.isEncrypted = true
            self.encryptionKeyIdentifier = keyIdentifier
            
            // Save the context
            try? self.managedObjectContext?.save()
            return true
        }
        
        return false
    }
    
    /// Verify a PIN against this tag's stored hash
    func verifyPin(_ pin: String) -> Bool {
        guard self.isEncrypted, 
              let hashedPin = self.pinHash,
              let salt = self.saltData else {
            return false
        }
        
        return EncryptionManager.verifyPin(pin, against: hashedPin, salt: salt)
    }
    
    /// Get this tag's encryption key (requires PIN verification)
    func getEncryptionKey(with pin: String) -> SymmetricKey? {
        guard self.isEncrypted,
              let keyIdentifier = self.encryptionKeyIdentifier,
              verifyPin(pin) else {
            return nil
        }
        
        // Try to get from keychain first
        if let key = EncryptionManager.getTagEncryptionKey(for: keyIdentifier) {
            return key
        }
        
        // If not found in keychain, regenerate from the PIN
        guard let salt = self.saltData else {
            return nil
        }
        
        // Regenerate the key from the PIN and salt
        let regeneratedKey = EncryptionManager.generateEncryptionKey(from: pin, salt: salt)
        
        // Save it back to keychain
        if EncryptionManager.saveTagEncryptionKey(regeneratedKey, for: keyIdentifier) {
            return regeneratedKey
        }
        
        return nil
    }
    
    /// Remove encryption from this tag
    func removeEncryption(with pin: String) -> Bool {
        guard self.isEncrypted, verifyPin(pin) else {
            return false
        }
        
        // Delete the encryption key from keychain
        if let keyIdentifier = self.encryptionKeyIdentifier {
            _ = EncryptionManager.deleteTagEncryptionKey(for: keyIdentifier)
        }
        
        // Reset encryption-related properties
        self.isEncrypted = false
        self.pinHash = nil
        self.encryptionKeyIdentifier = nil
        self.pinSalt = nil
        
        // Save the context
        do {
            try self.managedObjectContext?.save()
            return true
        } catch {
            // Error occurred
            return false
        }
    }
    
    /// Change the PIN for an encrypted tag
    func changePin(currentPin: String, newPin: String) -> Bool {
        guard self.isEncrypted, verifyPin(currentPin), newPin.count >= 4 else {
            return false
        }
        
        // Get the current encryption key
        guard let currentKey = getEncryptionKey(with: currentPin) else {
            return false
        }
        
        // Generate a new salt
        let newSalt = EncryptionManager.generateSalt()
        
        // Hash the new PIN with the new salt
        guard let newHashedPin = EncryptionManager.hashPin(newPin, salt: newSalt) else {
            return false
        }
        
        // Generate a new encryption key from the new PIN and salt
        let newKey = EncryptionManager.generateEncryptionKey(from: newPin, salt: newSalt)
        
        // Update the keychain with the new key
        if let keyIdentifier = self.encryptionKeyIdentifier,
           EncryptionManager.saveTagEncryptionKey(newKey, for: keyIdentifier) {
            
            // Update the tag properties
            self.pinHash = newHashedPin
            self.saltData = newSalt
            
            // Save the context
            do {
                try self.managedObjectContext?.save()
                return true
            } catch {
                // Error occurred
                return false
            }
        }
        
        return false
    }
    
    // MARK: - Static Methods
    
    /// Fetches all tags sorted by name.
    static func fetchAll(in context: NSManagedObjectContext) -> [Tag] {
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            // Error occurred
            return []
        }
    }
    
    /// Fetches all encrypted tags.
    static func fetchAllEncrypted(in context: NSManagedObjectContext) -> [Tag] {
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        request.predicate = NSPredicate(format: "isEncrypted == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            // Error occurred
            return []
        }
    }
    
    /// Finds an existing tag by name or creates a new one if it doesn't exist.
    static func findOrCreate(name: String, colorHex: String? = nil, in context: NSManagedObjectContext) -> Tag {
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        // Case-insensitive search for tag name
        request.predicate = NSPredicate(format: "name ==[cd] %@", name)
        
        do {
            let results = try context.fetch(request)
            if let existingTag = results.first {
                // Return existing tag
                return existingTag
            }
        } catch {
            // Error occurred
        }
        
        // Create a new tag if not found
        let newTag = Tag(context: context)
        newTag.name = name.trimmingCharacters(in: .whitespacesAndNewlines) // Ensure name is trimmed
        newTag.createdAt = Date()
        newTag.color = colorHex ?? generateRandomHexColor() // Assign provided or random color
        newTag.isEncrypted = false // Default to not encrypted
        
        return newTag
    }
    
    /// Create a new encrypted tag with a PIN
    static func createEncrypted(name: String, pin: String, colorHex: String? = nil, in context: NSManagedObjectContext) -> Tag? {
        guard pin.count >= 4 else { return nil }
        
        let tag = findOrCreate(name: name, colorHex: colorHex, in: context)
        
        if tag.setEncryptionPin(pin) {
            return tag
        }
        
        return nil
    }
    
    /// Fetches tags whose names contain the given query string (case-insensitive).
    static func fetch(matching query: String, in context: NSManagedObjectContext) -> [Tag] {
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        request.predicate = NSPredicate(format: "name CONTAINS[cd] %@", query)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            // Error occurred
            return []
        }
    }
    
    /// Generates a random hex color string.
    static func generateRandomHexColor() -> String {
        let colors = [
            "#FF5733", "#33FF57", "#3357FF", "#F3FF33", "#FF33F3",
            "#33FFF3", "#FF8033", "#8033FF", "#FF6347", "#4682B4",
            "#32CD32", "#FFD700", "#6A5ACD", "#FF4500", "#20B2AA"
        ]
        return colors.randomElement() ?? "#007AFF" // Default blue
    }
    
    // MARK: - Instance Methods
    
    /// Saves changes to the tag.
    func save(in context: NSManagedObjectContext) {
        // Potentially update a 'modifiedAt' attribute if added later
        do {
            try context.save()
        } catch {
            // Error saving tag
        }
    }
    
    /// Deletes the tag from the context.
    func delete(in context: NSManagedObjectContext) {
        // If this is an encrypted tag, delete its encryption key
        if self.isEncrypted, let keyIdentifier = self.encryptionKeyIdentifier {
            _ = EncryptionManager.deleteTagEncryptionKey(for: keyIdentifier)
        }
        
        context.delete(self)
        // Note: Saving the context should happen after deletion, typically higher up in the call stack.
    }
    
    // MARK: - Tag Suggestion
    
    /// Generates tag suggestions based on text content using multiple strategies.
    /// This implementation uses a combination of existing tag matching, common keyword extraction,
    /// and frequency analysis to provide relevant tag suggestions.
    static func suggestTags(for text: String, existingTags: [Tag], context: NSManagedObjectContext) -> [String] {
        guard !text.isEmpty else { return [] }
        
        var suggestions: [String] = []
        let lowercasedText = text.lowercased()
        
        // Strategy 1: Match existing tags in the text
        for tag in existingTags {
            if let tagName = tag.name?.lowercased(), 
               !tagName.isEmpty, 
               lowercasedText.contains(tagName) {
                suggestions.append(tag.name!) // Use original casing
            }
        }
        
        // Strategy 2: Extract common keywords based on frequency
        let words = extractWords(from: text)
        let frequentWords = findFrequentWords(in: words)
        suggestions.append(contentsOf: frequentWords)
        
        // Strategy 3: Identify common categories/topics
        let categories = identifyCategories(in: text)
        suggestions.append(contentsOf: categories)
        
        // Remove duplicates, filter out very short words, and limit suggestions
        return Array(Set(suggestions))
            .filter { $0.count > 2 } // Filter out very short words
            .prefix(8) // Limit to 8 suggestions
            .map { $0 }
    }
    
    /// Extracts individual words from text, removing common stop words.
    private static func extractWords(from text: String) -> [String] {
        let stopWords = ["the", "and", "a", "an", "in", "on", "at", "to", "for", "with", 
                         "by", "about", "like", "through", "over", "before", "between", 
                         "after", "since", "without", "under", "within", "along", "following",
                         "across", "behind", "beyond", "plus", "except", "but", "up", 
                         "out", "around", "down", "off", "above", "near", "i", "me", "my", 
                         "myself", "we", "our", "ours", "ourselves", "you", "your", "yours",
                         "yourself", "yourselves", "he", "him", "his", "himself", "she", 
                         "her", "hers", "herself", "it", "its", "itself", "they", "them", 
                         "their", "theirs", "themselves", "what", "which", "who", "whom",
                         "this", "that", "these", "those", "am", "is", "are", "was", "were",
                         "be", "been", "being", "have", "has", "had", "having", "do", "does",
                         "did", "doing", "would", "should", "could", "ought", "i'm", "you're",
                         "he's", "she's", "it's", "we're", "they're", "i've", "you've", 
                         "we've", "they've", "i'd", "you'd", "he'd", "she'd", "we'd", 
                         "they'd", "i'll", "you'll", "he'll", "she'll", "we'll", "they'll",
                         "isn't", "aren't", "wasn't", "weren't", "hasn't", "haven't", "hadn't",
                         "doesn't", "don't", "didn't", "won't", "wouldn't", "shan't", 
                         "shouldn't", "can't", "cannot", "couldn't", "mustn't", "let's", 
                         "that's", "who's", "what's", "here's", "there's", "when's", "where's",
                         "why's", "how's", "just", "very", "so", "really", "quite", "much"]
        
        // Split text into words, convert to lowercase, and remove punctuation
        let words = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && !stopWords.contains($0) && $0.count > 2 }
        
        return words
    }
    
    /// Finds frequent words in the text that might be good tag candidates.
    private static func findFrequentWords(in words: [String]) -> [String] {
        // Count word frequencies
        var wordCounts: [String: Int] = [:]
        for word in words {
            wordCounts[word, default: 0] += 1
        }
        
        // Sort by frequency and get top words
        let frequentWords = wordCounts.sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key.capitalized } // Capitalize first letter of each word
        
        return frequentWords
    }
    
    /// Identifies potential categories or topics in the text.
    private static func identifyCategories(in text: String) -> [String] {
        let lowercasedText = text.lowercased()
        var categories: [String] = []
        
        // Common topic categories that might be relevant for journal entries
        let topicKeywords: [String: String] = [
            "work": "work|job|career|office|meeting|project|deadline|colleague|presentation|interview|promotion|business",
            "health": "health|exercise|workout|fitness|diet|nutrition|doctor|medical|wellness|healthy|sick|illness|symptom",
            "family": "family|parent|child|kid|mom|dad|mother|father|brother|sister|son|daughter|grandparent|relative",
            "travel": "travel|trip|vacation|journey|flight|hotel|destination|tourist|explore|adventure|visit|abroad|foreign",
            "education": "education|school|college|university|class|course|study|learn|student|teacher|professor|assignment|exam|grade",
            "finance": "money|finance|budget|saving|expense|investment|bank|financial|income|salary|debt|loan|bill|payment",
            "food": "food|meal|recipe|cook|restaurant|dinner|lunch|breakfast|eat|dish|cuisine|ingredient|bake|delicious",
            "technology": "technology|computer|software|app|device|digital|online|internet|website|tech|code|program|mobile|phone",
            "hobby": "hobby|interest|craft|art|music|book|read|game|play|sport|collection|creative|painting|drawing",
            "emotion": "happy|sad|angry|frustrated|excited|anxious|worried|stressed|calm|peaceful|joy|fear|love|hate|feeling|emotion"
        ]
        
        // Check for each category's keywords in the text
        for (category, keywordPattern) in topicKeywords {
            let keywords = keywordPattern.components(separatedBy: "|")
            for keyword in keywords {
                if lowercasedText.contains(keyword) {
                    categories.append(category.capitalized)
                    break // Once we've matched a category, move to the next one
                }
            }
        }
        
        return categories
    }
}

// Note: Color(hex:) extension is defined in JournalEntryView.swift