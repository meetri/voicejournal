# Voice Journal iOS App - Planning Document

## Project Overview
The Voice Journal iOS app is designed to provide users with a secure and intuitive platform for recording daily journal entries using voice input. The app will automatically transcribe voice recordings to text, allow custom tagging, visualize audio waveforms in real-time, and incorporate AI analysis for extracting insights from journal entries.

## Core Features

### 1. Voice Recording & Transcription
- Record audio journal entries with high-quality capture
- Real-time waveform visualization during recording
- Automatic transcription of voice to text using iOS Speech framework
- Support for editing transcriptions after recording

### 2. Security
- App-level authentication using Face ID/Touch ID/PIN
- Encrypted storage for all journal entries
- Privacy-focused design with local-first approach
- Option to lock specific journal entries with additional authentication

### 3. Journal Organization
- Custom tagging system for entries
- Calendar view of journal entries
- Search functionality for both text content and tags
- Sorting and filtering options

### 4. AI Analysis Integration
- Connection to ChatGPT API for journal analysis
- Sentiment analysis (mood detection)
- Subject categorization
- Pattern recognition across entries
- Insights dashboard with metrics and trends

### 5. User Experience
- Clean, minimalist interface
- Dark/light mode support
- Customizable reminder notifications
- Backup/export options for journal entries

## Technical Stack

### iOS Development
- Swift with SwiftUI for modern UI components
- UIKit integration where necessary for specialized components
- Minimum iOS version: iOS 18 (to leverage latest Speech and recording features)
- Target devices: iPhone and iPad (universal app)

### Core Technologies
- **Audio Recording**: AVFoundation framework
- **Transcription**: Speech framework (iOS native)
- **Waveform Visualization**: Combination of AVFoundation for audio processing with custom visualization (or libraries like DSWaveformImage)
- **Authentication**: LocalAuthentication framework for Face ID/Touch ID
- **Storage**: Core Data with encryption for local database
- **Cloud Sync**: (Optional future feature) CloudKit for secure syncing

### External APIs
- OpenAI GPT API for journal analysis
- Potential backup services integration

## User Flow
1. **First Launch**: 
   - App setup and authentication configuration
   - Privacy policy acceptance
   - Optional tutorial

2. **Daily Use**:
   - Authenticate to access the app
   - Record new journal entry with visual waveform feedback
   - Review automatically generated transcript
   - Add/edit custom tags
   - Save entry

3. **Review & Insights**:
   - Browse past entries by date, tag, or search
   - View AI-generated insights from entries
   - Track mood and topic trends over time
   - Export or share insights (with privacy controls)

## Technical Challenges & Solutions

### Audio Processing
- Challenge: Real-time waveform visualization during recording
- Solution: Use AVAudioEngine for audio capture with buffer processing to extract amplitude data for visualization

### Secure Storage
- Challenge: Ensuring journal entries remain private and secure
- Solution: Implement encryption at rest using iOS security features and the LocalAuthentication framework

### Battery Optimization
- Challenge: Audio processing and transcription can be resource-intensive
- Solution: Optimize recording settings and process transcription efficiently

### AI Integration
- Challenge: Balancing local processing with cloud-based AI analysis
- Solution: Use a hybrid approach where basic processing happens on-device, with deeper analysis via API

## Future Expansion Possibilities
- Multi-device sync via iCloud
- Web companion app
- Audio journaling prompts/questions
- Visualization of mood trends over time
- Integration with Apple Health for correlation with physical well-being
- Support for voice commands during journaling

## Privacy & Data Handling
- All journal content stored locally by default
- Explicit user consent required for any cloud processing
- Transparency about data used for AI analysis
- Option to delete all data permanently
- Compliance with applicable privacy regulations

## App Monetization Strategy (Optional)
- Freemium model with basic functionality free
- Premium features could include:
  - Advanced AI analysis
  - Extended storage
  - Custom themes
  - Export options
  - Additional visualization tools
