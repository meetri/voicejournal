//
//  CustomTheme+CoreDataProperties.swift
//  voicejournal
//
//  Created on 5/17/25.
//

import Foundation
import CoreData

extension CustomTheme {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CustomTheme> {
        return NSFetchRequest<CustomTheme>(entityName: "CustomTheme")
    }
    
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var author: String?
    @NSManaged public var createdDate: Date?
    @NSManaged public var lastModified: Date?
    @NSManaged public var isBuiltIn: Bool
    @NSManaged public var isEditable: Bool
    @NSManaged public var themeDataJSON: Data?
    @NSManaged public var isSelected: Bool
    
}

extension CustomTheme : Identifiable {
    
}

// MARK: - Helper methods

extension CustomTheme {
    
    /// Convert Core Data entity to ThemeData model
    var themeData: ThemeData? {
        guard let jsonData = themeDataJSON else { return nil }
        
        do {
            let themeData = try JSONDecoder().decode(ThemeData.self, from: jsonData)
            return themeData
        } catch {
            print("Error decoding theme data: \(error)")
            return nil
        }
    }
    
    /// Update Core Data entity from ThemeData model
    func updateFromThemeData(_ themeData: ThemeData) {
        self.id = themeData.id
        self.name = themeData.name
        self.author = themeData.author
        self.createdDate = themeData.createdDate
        self.lastModified = themeData.lastModified
        self.isBuiltIn = themeData.isBuiltIn
        self.isEditable = themeData.isEditable
        
        // Debug log to verify cell border is being saved
        // Update theme with cell border
        
        do {
            self.themeDataJSON = try JSONEncoder().encode(themeData)
            
            // Verify the data was encoded correctly
            if let jsonData = self.themeDataJSON,
               let decodedData = try? JSONDecoder().decode(ThemeData.self, from: jsonData) {
                // Successfully encoded theme with cell border
            }
        } catch {
            print("Error encoding theme data: \(error)")
        }
    }
    
    /// Create a new CustomTheme entity from ThemeData
    static func create(from themeData: ThemeData, in context: NSManagedObjectContext) -> CustomTheme {
        let customTheme = CustomTheme(context: context)
        customTheme.updateFromThemeData(themeData)
        return customTheme
    }
}