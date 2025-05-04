# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build/Test Commands
- Check syntax using xcodebuild command, example: xcodebuild -scheme voicejournal -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
- Build & run: Use Xcode's ⌘+R (Product > Run)
- Run all tests: ⌘+U (Product > Test)
- Run single test: Select test method in test file and use ⌘+U

## Syntax Checking using xcode build command line

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
