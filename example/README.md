# speech_to_text_native Example

A demo app showcasing the `speech_to_text_native` Flutter plugin for real-time speech-to-text conversion.

## Getting Started

1. Clone the repository
2. Run `flutter pub get`
3. Run `flutter run`

### iOS Setup

Make sure to run `pod install` in the `ios/` directory:

```bash
cd ios && pod install
```

### Android Setup

No additional setup required. The `RECORD_AUDIO` permission is already configured.

## Features Demonstrated

- Real-time speech recognition
- Partial and final transcription results
- Confidence scores
- Permission handling
- Error handling

## 🙏 Acknowledgments

This example is part of the [speech_to_text_native](https://pub.dev/packages/speech_to_text_native) package, which was vibe coded from [react-native-speech-to-text](https://github.com/adelbeke/react-native-speech-to-text) by Arthur Delbeke. Thanks to his excellent work, this Flutter implementation was made possible!

## More Resources

- [speech_to_text_native on pub.dev](https://pub.dev/packages/speech_to_text_native)
- [Flutter Documentation](https://docs.flutter.dev/)
- [Original React Native Package](https://github.com/adelbeke/react-native-speech-to-text)
