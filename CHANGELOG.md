# Changelog

All notable changes to this project will be documented in this file.

## [1.1.0] - 2025-11-27

### Changed
- **BREAKING**: Renamed package from `speech_to_text_native` to `flutter_speech_to_text`
- Updated library export file from `speech_to_text_native.dart` to `flutter_speech_to_text.dart`

### Migration
To migrate from `speech_to_text_native` to `flutter_speech_to_text`:
```dart
// Before
import 'package:speech_to_text_native/speech_to_text_native.dart';

// After
import 'package:flutter_speech_to_text/flutter_speech_to_text.dart';
```

## [1.0.1] - 2025-11-26

### Fixed
- Corrected repository URLs in package metadata

### Added
- Unit tests for SpeechResult, SpeechError, and PermissionOptions
- macOS platform documentation in README

## [1.0.0] - 2024-01-01

### Added
- Initial release
- Real-time speech-to-text conversion
- Support for iOS (Speech Framework) and Android (SpeechRecognizer)
- Partial and final results with confidence scores
- Multi-language support
- Stream-based API for reactive programming
- Built-in permission handling
- Full TypeScript-like types for Dart

