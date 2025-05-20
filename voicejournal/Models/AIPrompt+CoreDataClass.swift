//
//  AIPrompt+CoreDataClass.swift
//  voicejournal
//
//  Created on 5/19/25.
//
//

import Foundation
import CoreData

// This is a supporting file to ensure proper Core Data entity registration
// Swift compiler rules require that the @objc(AIPrompt) directive appear in a 
// file named as the class + "CoreDataClass" suffix
@objc(AIPrompt)
public class AIPrompt: NSManagedObject, Identifiable {
    // This class contains Core Data entity registration metadata
}