# Debug Logging Catalog for VoiceJournal

This document catalogs all debug logging statements found in the voicejournal codebase.

## Summary

- **Total Files with Debug Logging**: 23+ files
- **Patterns Found**: print() statements, DEBUG: prefixes, emoji indicators (🔍, 🎨, 📊, ❌, 📝, 📅, 🏷, 🔒, 🔑, 🔓, 📆, 🔄)
- **Primary Areas**: Audio recording, speech recognition, spectrum analysis, timeline views, error handling

## DEBUG:, Error, and Info Print Statements

### /Users/meetri/Documents/dev/apps/voicejournal/voicejournal/ViewModels/AudioRecordingViewModel.swift
- Line 177: `print("DEBUG: Spectrum analyzer started successfully")` (DEBUG-ONLY)
- Line 179: `print("DEBUG: Failed to start spectrum analyzer: \(error)")` (DEBUG-ONLY)
- Line 193: `print("Speech recognition failed to start: \(error.localizedDescription)")` (ERROR LOG)
- Line 225: `print("DEBUG: Speech recognition starting with language: \(currentTranscriptionLanguage)")` (DEBUG-ONLY)
- Line 226: `print("DEBUG: Locale identifier: \(locale.identifier)")` (DEBUG-ONLY)
- Line 227: `print("DEBUG: Locale language code: \(locale.languageCode ?? "unknown")")` (DEBUG-ONLY)
- Line 228: `print("DEBUG: Language status: \(status.description)")` (DEBUG-ONLY)
- Line 248: `print("DEBUG: Speech recognition error: \(error.localizedDescription)")` (DEBUG-ONLY)
- Line 255: `print("DEBUG: Speech recognition failed to start: \(error.localizedDescription)")` (DEBUG-ONLY)
- Line 259: `print("DEBUG: Unknown speech recognition error: \(error.localizedDescription)")` (DEBUG-ONLY)
- Line 363: `print("Transcription failed: \(error.localizedDescription)")` (ERROR LOG)
- Line 485: `print("DEBUG: AudioRecordingViewModel received frequency data with \(data.count) bars")` (DEBUG-ONLY)
- Line 562: `print("Failed to save managed object context: \(error.localizedDescription)")` (ERROR LOG)
- Line 599: `print("Failed to update journal entry with transcription: \(error.localizedDescription)")` (ERROR LOG)

### /Users/meetri/Documents/dev/apps/voicejournal/voicejournal/ViewModels/SpectrumViewModel.swift
- Line 82: `print("Failed to start spectrum analyzer: \(error.localizedDescription)")` (ERROR LOG)

### /Users/meetri/Documents/dev/apps/voicejournal/voicejournal/ViewModels/Calendar/CalendarViewModel.swift
- Line 95: `print("Move to today")` (DEBUG-ONLY)
- Line 426: `print("Error fetching encrypted tags: \(error)")` (ERROR LOG)

### /Users/meetri/Documents/dev/apps/voicejournal/voicejournal/ViewModels/AudioPlaybackViewModel.swift
- Line 171: `print("Error loading audio file for spectrum analysis: \(error)")` (ERROR LOG)

### /Users/meetri/Documents/dev/apps/voicejournal/voicejournal/Views/EntryCreationView.swift
- Line 248: `print("DEBUG: Processing \(selectedTags.count) selected tags")` (DEBUG-ONLY)
- Line 253: `print("DEBUG: Found encrypted tag: '\(tagName)'")` (DEBUG-ONLY)
- Line 256: `print("DEBUG: Found PIN for encrypted tag '\(tagName)'")` (DEBUG-ONLY)
- Line 264: `print("DEBUG: No PIN found for encrypted tag '\(tagName)'")` (DEBUG-ONLY)
- Line 265: `print("DEBUG: Available tag names in dictionary: \(EntryCreationView.encryptedTagPINs.keys)")` (DEBUG-ONLY)
- Line 270: `print("DEBUG: Adding regular tag: \(tag.name ?? "unnamed")")` (DEBUG-ONLY)
- Line 282: `print("Error creating journal entry: \(error.localizedDescription)")` (ERROR LOG)
- Line 297: `print("DEBUG: Attempting to apply encrypted tag: '\(tagName)'")` (DEBUG-ONLY)
- Line 298: `print("DEBUG: All stored tag names with PINs: \(EntryCreationView.encryptedTagPINs.keys)")` (DEBUG-ONLY)
- Line 301: `print("DEBUG: Found PIN for '\(tagName)', applying encrypted tag")` (DEBUG-ONLY)
- Line 304: `print("DEBUG: Successfully applied encrypted tag and encrypted content")` (DEBUG-ONLY)
- Line 306: `print("ERROR: Failed to apply encrypted tag")` (ERROR LOG)
- Line 312: `print("ERROR: No PIN found for encrypted tag: '\(tagName)'")` (ERROR LOG)
- Line 348: `print("Error saving journal entry: \(error.localizedDescription)")` (ERROR LOG)
- Line 363: `print("Error saving transcription: \(error.localizedDescription)")` (ERROR LOG)
- Line 375: `print("Error deleting entry: \(error.localizedDescription)")` (ERROR LOG)
- Line 721: `print("Error creating tag: \(error.localizedDescription)")` (ERROR LOG)
- Line 780: `print("DEBUG: Stored PIN for tag '\(tagName)' using name as key")` (DEBUG-ONLY)
- Line 782: `print("ERROR: Cannot store PIN - tag has no name")` (ERROR LOG)

### /Users/meetri/Documents/dev/apps/voicejournal/voicejournal/Services/SpectrumAnalyzerService.swift
- Line 123: `print("DEBUG: Spectrum data received with \(processedData.count) bars, max: \(processedData.max() ?? 0)")` (DEBUG-ONLY)

### /Users/meetri/Documents/dev/apps/voicejournal/voicejournal/Services/AudioSpectrumManager.swift
- Line 47: `print("Microphone analysis ready - using external buffer processing")` (INFO LOG)
- Line 62: `print("Failed to open audio file")` (ERROR LOG)
- Line 84: `print("Audio engine started for playback analysis.")` (INFO LOG)
- Line 86: `print("Failed to start audio engine: \(error)")` (ERROR LOG)
- Line 105: `print("Audio engine stopped.")` (INFO LOG)
- Line 121: `print("DEBUG: Process failed - fftSetup: \(fftSetup != nil), channelData: \(buffer.floatChannelData != nil), frameLength: \(buffer.frameLength)")` (DEBUG-ONLY)
- Line 201: `print("DEBUG: Spectrum bars generated with max: \(bars.max() ?? 0)")` (DEBUG-ONLY)

### /Users/meetri/Documents/dev/apps/voicejournal/voicejournal/Services/SpeechRecognitionService.swift
- Line 290: `print("DEBUG: Language status for \(currentLocale.identifier): \(languageStatus.description)")` (DEBUG-ONLY)
- Line 381: `print("DEBUG: Speech recognition error: \(error.localizedDescription)")` (DEBUG-ONLY)
- Line 382: `print("DEBUG: Converted to: \(specificError.localizedDescription)")` (DEBUG-ONLY)

### /Users/meetri/Documents/dev/apps/voicejournal/voicejournal/Services/EncryptedTagsAccessManager.swift
- Line 185: `print("Error decrypting audio file: \(error)")` (ERROR LOG)

### /Users/meetri/Documents/dev/apps/voicejournal/voicejournal/Services/AudioFileAnalyzer.swift
- Line 62: `print("Error reading audio file: \(error)")` (ERROR LOG)

### /Users/meetri/Documents/dev/apps/voicejournal/voicejournal/Views/TranscriptionEditView.swift
- Line 132: `print("DEBUG: TranscriptionEditView appeared")` (DEBUG-ONLY)
- Line 139: `print("DEBUG: TranscriptionEditView disappeared")` (DEBUG-ONLY)
- Line 161: `print("Error capitalizing text: \(error.localizedDescription)")` (ERROR LOG)
- Line 183: `print("Error adding periods: \(error.localizedDescription)")` (ERROR LOG)
- Line 205: `print("Error fixing text: \(error.localizedDescription)")` (ERROR LOG)
- Line 227: `print("Error cleaning text: \(error.localizedDescription)")` (ERROR LOG)
- Line 278: `print("Error saving transcription: \(error.localizedDescription)")` (ERROR LOG)

### /Users/meetri/Documents/dev/apps/voicejournal/voicejournal/Views/EncryptedTagManagementView.swift
- Line 437: `print("Error saving context in EncryptedTagManagementView: \(error)")` (ERROR LOG)
- Line 609: `print("Error creating encrypted tag: \(error)")` (ERROR LOG)

### /Users/meetri/Documents/dev/apps/voicejournal/voicejournal/Persistence.swift
- Line 76: `print("Successfully migrated \(migratedCount) audio file paths")` (INFO LOG)
- Line 106: `print("Migrating \(entries.count) journal entries to base encryption...")` (INFO LOG)
- Line 119: `print("Successfully migrated \(encryptedCount)/\(entries.count) journal entries to base encryption")` (INFO LOG)
- Line 124: `print("Error migrating to base encryption: \(error)")` (ERROR LOG)

## Emoji-Based Debug Logging

### /Users/meetri/Documents/dev/apps/voicejournal/voicejournal/ViewModels/Timeline/TimelineViewModel.swift
- Line 99: `print("🔍 DEBUG: TimelineViewModel initialization")` (DEBUG-ONLY)
- Line 433: `print("🔍 DEBUG: Final predicate: \(finalPredicate)")` (DEBUG-ONLY)
- Line 447: `print("Error fetching encrypted tags: \(error)")` (ERROR LOG)

### /Users/meetri/Documents/dev/apps/voicejournal/voicejournal/ViewModels/Timeline/TimelineViewModelDebug.swift
- Line 19: `print("❌ ERROR: Failed to get context for debugging")` (DEBUG-ONLY)
- Line 28: `print("📊 DEBUG: Found \(allEntries.count) total entries in the database")` (DEBUG-ONLY)
- Line 31: `print("  📝 Entry #\(index + 1): \(entry.title ?? "Untitled") (ID: \(entry.objectID))")` (DEBUG-ONLY)
- Line 35: `print("    📅 Created: \(date)")` (DEBUG-ONLY)
- Line 40: `print("    🏷 Regular tags: \(tags.count)")` (DEBUG-ONLY)
- Line 42: `print("      - \(tag.name ?? "unnamed") (ID: \(tag.objectID), Encrypted: \(tag.isEncrypted))")` (DEBUG-ONLY)
- Line 45: `print("    🏷 No regular tags")` (DEBUG-ONLY)
- Line 50: `print("    🔒 Encrypted tag: \(encryptedTag.name ?? "unnamed") (ID: \(encryptedTag.objectID))")` (DEBUG-ONLY)
- Line 51: `print("    🔑 Has global access: \(encryptedTag.hasGlobalAccess)")` (DEBUG-ONLY)
- Line 53: `print("    🔓 No encrypted tag")` (DEBUG-ONLY)
- Line 58: `print("    🔍 Would be filtered out: \(wouldBeFiltered)")` (DEBUG-ONLY)
- Line 60: `print("")` (DEBUG-ONLY - empty line for readability)
- Line 63: `print("❌ ERROR: Failed to fetch entries for debugging: \(error)")` (DEBUG-ONLY)
- Line 92: `print("📆 DEBUG: Current date range: \(dateRange.displayName)")` (DEBUG-ONLY)
- Line 104: `print("🔒 DEBUG: Found \(tagsWithoutAccess.count) encrypted tags without access")` (DEBUG-ONLY)
- Line 106: `print("  - \(tag.name ?? "unnamed") (ID: \(tag.objectID))")` (DEBUG-ONLY)
- Line 137: `print("🔍 DEBUG: Predicates being used:")` (DEBUG-ONLY)
- Line 139: `print("  \(index + 1). \(desc)")` (DEBUG-ONLY)
- Line 142: `print("❌ ERROR: Failed to fetch encrypted tags for debugging: \(error)")` (DEBUG-ONLY)

### /Users/meetri/Documents/dev/apps/voicejournal/voicejournal/Views/Timeline/TimelineView.swift
- Line 217: `print("🔄 Sort order selected: \(order.rawValue)")` (DEBUG-ONLY)
- Line 309: `print("Would scroll to date: \(closestDate)")` (DEBUG-ONLY)

### /Users/meetri/Documents/dev/apps/voicejournal/voicejournal/Views/JournalEntryRow+Debug.swift
- Line 19: `print("🔒 Encrypted tag: \(encryptedTag.name ?? "unnamed") (ID: \(encryptedTag.objectID))")` (DEBUG-ONLY)
- Line 21: `print("🔒 No encrypted tag")` (DEBUG-ONLY)
- Line 26: `print("🏷 Regular tags: \(tags.count)")` (DEBUG-ONLY)
- Line 31: `print("🏷 No regular tags")` (DEBUG-ONLY)

### /Users/meetri/Documents/dev/apps/voicejournal/voicejournal/Services/ThemeManager.swift
- Line 21: `print("🎨 Theme loaded: \(id.rawValue)")` (DEBUG-ONLY)
- Line 29: `print("🔄 Theme updated to: \(id.rawValue)")` (DEBUG-ONLY)

## Test Files

### /Users/meetri/Documents/dev/apps/voicejournal/voicejournalTests/AudioPlaybackServiceTests.swift
- Line 348: `print("Test audio file created successfully")` (TEST LOG)
- Line 350: `print("Failed to create test audio file")` (TEST LOG)
- Line 353: `print("Error creating test audio file: \(error.localizedDescription)")` (TEST LOG)

### /Users/meetri/Documents/dev/apps/voicejournal/voicejournalTests/AudioPlaybackViewModelTests.swift
- Line 343: `print("Test audio file created successfully")` (TEST LOG)
- Line 345: `print("Failed to create test audio file")` (TEST LOG)
- Line 348: `print("Error creating test audio file: \(error.localizedDescription)")` (TEST LOG)

## Analysis

### Debug-Only Statements
1. **Pattern**: Most debug statements begin with "DEBUG:" or use emoji indicators
2. **Count**: Approximately 50+ debug-only statements
3. **Files with Most Debug Logging**:
   - TimelineViewModelDebug.swift (entire file is debug-focused)
   - AudioRecordingViewModel.swift
   - EntryCreationView.swift
   - SpeechRecognitionService.swift

### Production-Required Logging
1. **Error Logs**: Approximately 25+ error logging statements that may be useful in production for diagnostics
2. **Info Logs**: Several informational logs about audio engine state that might be useful for troubleshooting

### Categories of Debug Logging
1. **Spectrum Analysis**: Multiple logging points for debugging spectrum analyzer and FFT processing
2. **Speech Recognition**: Extensive debugging for language detection and recognition state
3. **Timeline Filtering**: Comprehensive debugging for predicate construction and encrypted tag filtering
4. **Encrypted Tags**: Debug logging for PIN management and tag application
5. **Audio Engine**: State change logging for audio recording and playback

### Recommendations
1. **Create a Debug Flag**: Implement a global debug flag to conditionally enable debug logging
2. **Use os_log/Logger**: Replace print statements with os_log or Logger for better performance and control
3. **Remove DEBUG: Prefixed Statements**: These are clearly intended for development only
4. **Keep Error Logs**: Error logging should remain for production debugging
5. **Consider Log Levels**: Implement proper log levels (debug, info, warning, error) for better control