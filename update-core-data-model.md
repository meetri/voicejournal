# Core Data Model Update Instructions

To fix the app crash when accessing encrypted audio recordings, you need to update the Core Data model to include the missing attributes.

## Steps to fix:

1. Open the project in Xcode
2. Navigate to `/voicejournal/voicejournal.xcdatamodeld/voicejournal.xcdatamodel`
3. Select the `AudioRecording` entity in the Core Data model editor
4. Add the following attributes:
   - `isEncrypted` (Type: Boolean, Default: NO, Optional: Yes)
   - `originalFilePath` (Type: String, Optional: Yes)

5. Save the changes
6. Create a Core Data Model Version and Migration if prompted (recommended for existing data)

## Details on the issue:

The app is crashing because the code is trying to access these properties:
```swift
audioRecording.isEncrypted = true
```
```swift
audioRecording.originalFilePath = filePath
```

These properties were added in the Swift extension but not in the actual Core Data model:
```swift
// From AudioRecording+Extensions.swift
@NSManaged var originalFilePath: String?
@NSManaged var isEncrypted: Bool
```

Adding these attributes to the Core Data model will resolve the crash when trying to decrypt content.