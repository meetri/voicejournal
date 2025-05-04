# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build/Test Commands
- Check syntax using `xcodebuild` command, example: xcodebuild -scheme voicejournal -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
- install app to iphone (physical device) using `xcrun` example: xcrun devicectl device process launch --device 00008140-001270893C6A801C com.ztwoi.voicejournal

## Important Instructions

### Issue Handling
- ALWAYS report issues like typos, incorrect attributes, or inconsistencies directly to the user without implementing workarounds
- When you notice issues (like mismatched property names), explain the problem and recommend a proper fix rather than creating code to work around it
- Only implement changes that directly address the user's request, not changes that address underlying issues unless specifically asked

## Code Style Guidelines
- **Imports**: Standard libraries first, then frameworks alphabetically, custom modules last
- **Types**: PascalCase for types/classes/enums, camelCase for methods/properties/variables
- **Organization**: Use `MARK: - Section Name` comments to organize code sections
- **Documentation**: Triple-slash `///` comments for documentation
- **Extensions**: Use extensions for protocol conformance and to organize functionality
- **Concurrency**: Use Swift concurrency (async/await) with proper actor isolation
- **Error Handling**: Create custom error enums, use try/catch, provide descriptive error messages

## Architecture
- MVVM architecture with clear separation of concerns
- Services for core functionality (AudioRecordingService, SpeechRecognitionService)
- ViewModels for UI state management and business logic
- Core Data for persistence (see Persistence.swift)

## Testing
- Test both success and error paths
- Use descriptive method names: test[Feature][Scenario]
- Properly clean up resources in tearDown methods
