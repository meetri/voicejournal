# Core Data Model Update for AI Prompts

The Core Data model needs to be updated to add the new AIPrompt entity. Follow these steps to update the model:

1. Open the Xcode project in Xcode
2. In the Project Navigator, locate the `voicejournal.xcdatamodeld` file in the `voicejournal` group
3. Open the file and click on "Add Entity" in the editor
4. Name the new entity `AIPrompt`
5. Add the following attributes to the AIPrompt entity:

| Attribute Name | Type     | Default Value | Notes                         |
|---------------|----------|---------------|-------------------------------|
| id            | UUID     | nil           | Set as indexed attribute      |
| name          | String   | nil           |                               |
| content       | String   | nil           |                               |
| type          | String   | nil           |                               |
| isDefault     | Boolean  | false         |                               |
| createdAt     | Date     | nil           |                               |
| modifiedAt    | Date     | nil           |                               |

6. Create a new Core Data Model Version:
   - Editor > Add Model Version
   - Name it "voicejournal 2"
   - Set it as the current version (select the .xcdatamodeld file, then in the File Inspector, set Current Version to "voicejournal 2")

7. Add migration code to `MigrationUtility.swift` to handle the model update:

```swift
func migrateToVersion2(context: NSManagedObjectContext) {
    // Create default AI prompts
    createDefaultAudioAnalysisPrompt(in: context)
    createDefaultTranscriptionEnhancementPrompt(in: context)
    
    try? context.save()
}

private func createDefaultAudioAnalysisPrompt(in context: NSManagedObjectContext) {
    // Check if there's already a prompt with this name
    let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "AIPrompt")
    request.predicate = NSPredicate(format: "name == %@ AND type == %@", "Standard Analysis", "audioAnalysis")
    
    do {
        let count = try context.count(for: request)
        if count == 0 {
            // Create the default prompt
            let prompt = NSEntityDescription.insertNewObject(forEntityName: "AIPrompt", into: context) as! NSManagedObject
            prompt.setValue(UUID(), forKey: "id")
            prompt.setValue("Standard Analysis", forKey: "name")
            prompt.setValue("audioAnalysis", forKey: "type")
            prompt.setValue(true, forKey: "isDefault")
            prompt.setValue(Date(), forKey: "createdAt")
            prompt.setValue(Date(), forKey: "modifiedAt")
            
            // Set the default content
            let content = """
            Please analyze this audio recording and provide:

            1. A detailed summary of the audio content
            2. Key topics and themes discussed
            3. Important insights or conclusions
            4. Any notable patterns or recurring elements
            5. Suggested action items or follow-ups (if applicable)
            6. Create relevant mermaid diagrams if the content involves:
               - Processes or workflows
               - Relationships or hierarchies
               - Timeline or sequences
               - Decision trees

            Format the response in markdown with clear sections and headers.
            If creating mermaid diagrams, use proper mermaid syntax blocks.
            """
            
            prompt.setValue(content, forKey: "content")
        }
    } catch {
        print("Error checking for existing AI prompts: \(error)")
    }
}

private func createDefaultTranscriptionEnhancementPrompt(in context: NSManagedObjectContext) {
    // Check if there's already a prompt with this name
    let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "AIPrompt")
    request.predicate = NSPredicate(format: "name == %@ AND type == %@", "Standard Enhancement", "transcriptionEnhancement")
    
    do {
        let count = try context.count(for: request)
        if count == 0 {
            // Create the default prompt
            let prompt = NSEntityDescription.insertNewObject(forEntityName: "AIPrompt", into: context) as! NSManagedObject
            prompt.setValue(UUID(), forKey: "id")
            prompt.setValue("Standard Enhancement", forKey: "name")
            prompt.setValue("transcriptionEnhancement", forKey: "type")
            prompt.setValue(true, forKey: "isDefault")
            prompt.setValue(Date(), forKey: "createdAt")
            prompt.setValue(Date(), forKey: "modifiedAt")
            
            // Set the default content
            let content = """
            Enhance this raw transcription by adding proper punctuation, capitalization, and paragraph breaks.
            Do not change any words or phrases, only improve formatting and readability.
            """
            
            prompt.setValue(content, forKey: "content")
        }
    } catch {
        print("Error checking for existing AI prompts: \(error)")
    }
}
```

8. Update the `migrateIfNeeded` method in `MigrationUtility.swift` to call the new migration function:

```swift
func migrateIfNeeded() {
    let context = PersistenceController.shared.container.viewContext
    
    // Check the store version
    let currentVersion = UserDefaults.standard.integer(forKey: "CoreDataVersion")
    
    // If the version is 0 (or doesn't exist), we need to migrate
    if currentVersion < 1 {
        migrateToVersion1(context: context)
        UserDefaults.standard.set(1, forKey: "CoreDataVersion")
    }
    
    // If the version is less than 2, migrate to version 2
    if currentVersion < 2 {
        migrateToVersion2(context: context)
        UserDefaults.standard.set(2, forKey: "CoreDataVersion")
    }
}
```

After completing these steps, build and run the app. The Core Data model will be updated, and default AI prompts will be created.