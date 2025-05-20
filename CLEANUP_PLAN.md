# Comprehensive Code Cleanup Plan for Voice Journal

This document outlines all identified code cleanup and optimization opportunities.

## Todo List

1. **[HIGH] Remove debug-only views that are not used in the main app flow**
   - AudioFileDebugView.swift
   - PathTestView.swift
   - LanguageDebugView.swift
   - LanguageDiagnosticsView.swift
   - TagDisplayTestView.swift (#if DEBUG)
   - JournalEntryRow+Debug.swift
   - TimelineViewModelDebug.swift

2. **[HIGH] Consolidate duplicate audio playback code between AudioPlaybackService and AudioPlaybackManager**
   - Refactor to have AudioPlaybackManager use AudioPlaybackService
   - Create clear delegation/composition pattern
   - Keep AudioPlaybackManager focused on encryption/decryption

3. **[MEDIUM] Remove excessive debug print statements throughout the codebase**
   - AIPrompt.swift - debug logging for prompt operations
   - AudioPlaybackManager.swift - 25+ print statements for playback stages
   - AIPromptDefaultManager.swift - prints for prompt creation
   - FilePathUtility.swift - verbose path resolution logs
   - AIAnalysisStatusChecker.swift - debug-only class with logs

4. **[MEDIUM] Centralize default AI prompt templates to avoid duplication**
   - Same templates in AIConfigurationManager.swift (line 200-217) and AIPromptDefaultManager.swift (line 67-84)
   - Move to a single location like AIPromptDefaults struct

5. **[HIGH] Simplify path resolution logic in FilePathUtility**
   - Reduce complexity in findAudioFile method (lines 131-206)
   - Standardize on a single path scheme
   - Make storage locations more deterministic

6. **[MEDIUM] Create reusable UI components for redundant view patterns**
   - Consolidate audio visualization components
   - Create unified card system from GlassCardView
   - Extract common tag display logic
   - Standardize theme usage and color references

7. **[MEDIUM] Optimize Timeline data fetching to reduce redundant Core Data operations**
   - Implement debounced fetch for multiple publisher updates
   - Remove redundant sorting (lines 514-567)
   - Cache encrypted tag results

8. **[HIGH] Implement proper background processing for expensive operations**
   - Move FFT calculations (AudioSpectrumManager.swift lines 117-207) to background queue
   - Make encryption/decryption operations async (EncryptionManager.swift lines 247-275)
   - Reduce timer frequency for UI updates (AudioPlaybackManager.swift line 315)

9. **[LOW] Remove redundant time formatting and calculation functions**
   - Consolidate duplicate code in AudioPlaybackService.swift (line 399-403) and AudioPlaybackViewModel.swift (line 544-548)
   - Create utility extension for TimeInterval

10. **[MEDIUM] Standardize error handling approach across the codebase**
    - Adopt consistent pattern (Result type preferred)
    - Improve optional handling with nil-coalescing
    - Create clear error enums and messages

## Additional Improvements

### UI Redundancies

1. **Audio Visualization Components**
   - WaveformView.swift, EnhancedWaveformView.swift, AudioVisualizationView.swift, SpectrumAnalyzerView.swift
   - Create unified component system with shared drawing logic

2. **Card and Container Components**
   - GlassCardView.swift as base view for all card-like components
   - Standardize corner radius, shadow, padding values

3. **Tag Display Components**
   - Create unified TagView for all tag display cases
   - Implement variations via modifiers

4. **Form Element Styling**
   - Create ThemedTextField, ThemedButton, ThemedToggle
   - Apply consistent styling to all forms

### Large View Files to Break Down

1. EnhancedPlaybackView.swift (575+ lines)
2. SpectrumAnalyzerView.swift (560+ lines)
3. JournalEntryRow.swift (~216 lines)

### Encryption UI Components to Unify

1. EncryptedTagIndicator.swift
2. JournalEntryView.swift encryption elements
3. EncryptedContentView.swift