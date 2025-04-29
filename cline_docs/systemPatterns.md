# Voice Journal iOS App - System Patterns

## Architecture Overview

The Voice Journal app follows the **Model-View-ViewModel (MVVM)** architecture pattern, which provides a clean separation of concerns and facilitates testability.

### Key Components

1. **Models**: Core Data entities representing the domain objects
   - JournalEntry
   - AudioRecording
   - Bookmark
   - TranscriptionSegment

2. **Views**: SwiftUI views for the user interface
   - Authentication views
   - Recording interface
   - Journal entry views
   - Playback interface
   - Waveform visualization

3. **ViewModels**: Intermediaries between Models and Views
   - AudioRecordingViewModel
   - AudioPlaybackViewModel
   - WaveformViewModel

4. **Services**: Handle specific functionality domains
   - AudioRecordingService
   - AudioPlaybackService
   - AuthenticationService
   - SpeechRecognitionService

5. **Utilities**: Helper classes and extensions
   - EncryptionManager
   - FilePathUtility
   - ImportUtility
   - MigrationUtility

## Key Technical Decisions

### 1. SwiftUI as Primary UI Framework
- Modern declarative UI approach
- Reactive updates based on state changes
- Composition-based view hierarchy

### 2. Core Data for Persistence
- Structured data storage with relationships
- Support for complex queries
- Integration with SwiftUI via @FetchRequest

### 3. AVFoundation for Audio Handling
- High-quality audio recording and playback
- Access to audio buffer data for waveform visualization
- Fine-grained control over audio sessions

### 4. Speech Framework for Transcription
- Native iOS speech recognition
- On-device processing for privacy
- Support for continuous transcription

### 5. LocalAuthentication for Security
- Biometric authentication (Face ID/Touch ID)
- PIN fallback mechanism
- Secure app locking

### 6. Custom Waveform Visualization
- Real-time audio level visualization
- Interactive playback position indicator
- Multiple visualization styles

## Design Patterns

### 1. Dependency Injection
- Services are injected into ViewModels
- Facilitates testing through mock services

### 2. Observer Pattern
- Used for audio level updates
- Implemented via Combine framework

### 3. Repository Pattern
- Core Data access abstracted through extension methods
- Clean separation between data access and business logic

### 4. Factory Pattern
- Used for creating complex objects like audio sessions

### 5. Coordinator Pattern
- Navigation flow managed through coordinator objects

## Data Flow

1. **User Input** → View
2. View → **Action** → ViewModel
3. ViewModel → **Service Call** → Service
4. Service → **Data Manipulation** → Model
5. Model → **State Update** → ViewModel
6. ViewModel → **UI Update** → View

## Error Handling Strategy

- Comprehensive error types for different domains
- Error propagation through Result type
- User-friendly error messages
- Graceful degradation of features when errors occur

## Testing Approach

- Unit tests for ViewModels and Services
- UI tests for critical user flows
- Mock services for isolated testing
- Test coverage focused on core functionality
