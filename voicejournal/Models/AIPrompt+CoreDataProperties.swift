//
//  AIPrompt+CoreDataProperties.swift
//  voicejournal
//
//  Created on 5/19/25.
//
//

import Foundation
import CoreData

extension AIPrompt {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<AIPrompt> {
        return NSFetchRequest<AIPrompt>(entityName: "AIPrompt")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var content: String?
    @NSManaged public var type: String?
    @NSManaged public var isDefault: Bool
    @NSManaged public var createdAt: Date
    @NSManaged public var modifiedAt: Date
}