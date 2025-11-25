# speech_to_text_native

[![pub package](https://img.shields.io/pub/v/speech_to_text_native.svg)](https://pub.dev/packages/speech_to_text_native)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/adelbeke/flutter-speech-to-text/blob/main/LICENSE)

Speech to text native plugin for Flutter.

This Flutter package was vibe coded from [react-native-speech-to-text](https://github.com/adelbeke/react-native-speech-to-text) by [Arthur Delbeke](https://github.com/adelbeke). Thanks to his excellent work on the React Native version, this Flutter implementation was made possible!

## ✨ Features

- 🎤 **Real-time transcription** with partial results as you speak
- 📱 **Cross-platform** support for iOS and Android
- 🎯 **Confidence scores** for transcription accuracy
- 🌍 **Multi-language** support
- ⚡ **Stream-based** architecture for reactive programming
- 🔒 **Built-in permission handling**
- 📝 **Full Dart/Flutter types** included

## 📦 Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  speech_to_text_native: ^1.0.0
```

### iOS Setup

Add the following to your `Info.plist`:

```xml
<key>NSSpeechRecognitionUsageDescription</key>
<string>This app needs speech recognition to convert your voice to text</string>
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access to record your voice</string>
```

### Android Setup

Add the following permission to your `AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <uses-permission android:name="android.permission.RECORD_AUDIO" />
</manifest>
```

The package handles runtime permission requests automatically.

## 🚀 Quick Start

```dart
import 'package:speech_to_text_native/speech_to_text_native.dart';

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final SpeechToText _speechToText = SpeechToText();
  String _transcript = '';
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _initSpeechToText();
  }

  void _initSpeechToText() {
    // Listen for results
    _speechToText.onResult.listen((result) {
      setState(() {
        _transcript = result.transcript;
      });
      print('Confidence: ${result.confidence}');
      print('Is final: ${result.isFinal}');
    });

    // Listen for errors
    _speechToText.onError.listen((error) {
      print('Error: ${error.message}');
      setState(() => _isListening = false);
    });

    // Listen for end of speech
    _speechToText.onEnd.listen((_) {
      setState(() => _isListening = false);
    });
  }

  Future<void> _startListening() async {
    final available = await _speechToText.isAvailable();
    if (!available) {
      print('Speech recognition not available');
      return;
    }

    final hasPermission = await _speechToText.requestPermissions();
    if (!hasPermission) {
      print('Permission denied');
      return;
    }

    await _speechToText.start(language: 'en-US');
    setState(() => _isListening = true);
  }

  Future<void> _stopListening() async {
    await _speechToText.stop();
  }

  @override
  void dispose() {
    _speechToText.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_transcript.isEmpty ? 'Press start to begin' : _transcript),
            ElevatedButton(
              onPressed: _isListening ? _stopListening : _startListening,
              child: Text(_isListening ? 'Stop' : 'Start'),
            ),
          ],
        ),
      ),
    );
  }
}
```

## 📚 API Reference

### SpeechToText Class

#### Methods

##### `start({required String language})`

Starts speech recognition.

```dart
await speechToText.start(language: 'en-US');
```

**Parameters:**
- `language` (String, required): Language code (e.g., "en-US", "fr-FR", "es-ES")

**Throws:**
- `SpeechError` with appropriate error code

---

##### `stop()`

Stops speech recognition and sends the final transcript.

```dart
await speechToText.stop();
```

---

##### `requestPermissions({PermissionOptions? options})`

Requests necessary permissions for speech recognition.

```dart
final granted = await speechToText.requestPermissions(
  options: PermissionOptions(
    title: 'Microphone Permission',
    message: 'We need microphone access for speech recognition.',
    buttonPositive: 'Allow',
  ),
);
```

**Returns:** `Future<bool>` - `true` if permission granted

---

##### `isAvailable()`

Checks if speech recognition is available on the device.

```dart
final available = await speechToText.isAvailable();
```

**Returns:** `Future<bool>`

---

#### Streams

##### `onResult`

Stream of transcription results (both partial and final).

```dart
speechToText.onResult.listen((result) {
  print('Transcript: ${result.transcript}');
  print('Confidence: ${result.confidence}');
  print('Is final: ${result.isFinal}');
});
```

---

##### `onError`

Stream of error events.

```dart
speechToText.onError.listen((error) {
  print('Error code: ${error.errorCode}');
  print('Error message: ${error.message}');
});
```

---

##### `onEnd`

Stream that emits when speech recognition ends.

```dart
speechToText.onEnd.listen((_) {
  print('Speech recognition ended');
});
```

---

### Types

#### SpeechResult

```dart
class SpeechResult {
  final String transcript;   // The recognized text
  final double confidence;   // Confidence score from 0.0 to 1.0
  final bool isFinal;        // true for final result, false for partial
}
```

#### SpeechError

```dart
class SpeechError {
  final SpeechErrorCode errorCode;
  final String message;
}
```

#### SpeechErrorCode

```dart
enum SpeechErrorCode {
  permissionDenied,
  notAvailable,
  requestFailed,
  startFailed,
  stopFailed,
  audioError,
  clientError,
  networkError,
  networkTimeout,
  recognizerBusy,
  serverError,
  unknownError,
}
```

#### PermissionOptions

```dart
class PermissionOptions {
  final String? title;           // Dialog title (Android only)
  final String? message;         // Dialog message (Android only)
  final String? buttonNeutral;   // Neutral button text
  final String? buttonNegative;  // Negative button text
  final String? buttonPositive;  // Positive button text
}
```

## 🌍 Supported Languages

You can use any standard locale identifier. Here are some examples:

- English: `en-US`, `en-GB`, `en-AU`
- French: `fr-FR`, `fr-CA`
- Spanish: `es-ES`, `es-MX`
- German: `de-DE`
- Italian: `it-IT`
- Portuguese: `pt-BR`, `pt-PT`
- Japanese: `ja-JP`
- Chinese: `zh-CN`, `zh-TW`
- Korean: `ko-KR`
- Arabic: `ar-SA`

Availability depends on the device and platform. Use `isAvailable()` to check.

## 🔧 Troubleshooting

### "Permission denied" error

**iOS:**
- Make sure you've added `NSSpeechRecognitionUsageDescription` and `NSMicrophoneUsageDescription` to your `Info.plist`
- Check that the user granted permissions in Settings > Your App

**Android:**
- Ensure `RECORD_AUDIO` permission is in `AndroidManifest.xml`
- Call `requestPermissions()` before `start()`

---

### "Speech recognition not available"

- **iOS**: Speech recognition requires iOS 10+ and may not work in the simulator. Test on a real device.
- **Android**: Ensure Google app or speech recognition service is installed and up to date.

---

### No partial results showing

- Partial results are enabled by default on both platforms
- On Android, partial results appear after a short delay
- Check that you're handling the `isFinal` flag correctly

---

### Recognition stops automatically

- **iOS**: May stop automatically after detecting silence
- **Android**: Configured with 2-second pause detection
- Call `start()` again to restart recognition

## 📄 License

MIT

## 🔗 Links

- [GitHub Repository](https://github.com/adelbeke/flutter-speech-to-text)
- [pub.dev Package](https://pub.dev/packages/speech_to_text_native)
- [Report Issues](https://github.com/adelbeke/flutter-speech-to-text/issues)
- [Original React Native Package](https://github.com/adelbeke/react-native-speech-to-text)
