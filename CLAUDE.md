# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build/Test Commands
- Check syntax using `xcodebuild` command, example: xcodebuild -scheme voicejournal -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
- build and install app to external iphone/device only when requested using `xrun` example: `xcrun devicectl device process launch --device 00008140-001270893C6A801C com.ztwoi.voicejournal`
- after major code updates and upon completion of any updates make sure to check that the build completes successfully

## Important Instructions

### Issue Handling
- ALWAYS report issues like typos, incorrect attributes, or inconsistencies directly to the user without implementing workarounds
- When you notice issues (like mismatched property names), explain the problem and recommend a proper fix rather than creating code to work around it
- Only implement changes that directly address the user's request, not changes that address underlying issues unless specifically asked

## Code Style Guidelines
- use 4 spaces for indentation
- keep lines under 80 character length
- **Never create a file longer than 500 lines of code.** If a file approaches this limit, refactor by splitting it into modules or helper files.
- **Organize code into clearly separated modules**, grouped by feature or responsibility.
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
