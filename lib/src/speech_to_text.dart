import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'speech_result.dart';
import 'speech_error.dart';
import 'permission_options.dart';

/// Main class for speech-to-text functionality.
///
/// This class provides methods to start and stop speech recognition,
/// request permissions, and listen to recognition events.
///
/// Example usage:
/// ```dart
/// final speechToText = SpeechToText();
///
/// // Listen for results
/// speechToText.onResult.listen((result) {
///   print('Transcript: ${result.transcript}');
///   print('Confidence: ${result.confidence}');
///   print('Is final: ${result.isFinal}');
/// });
///
/// // Listen for errors
/// speechToText.onError.listen((error) {
///   print('Error: ${error.message}');
/// });
///
/// // Listen for end of speech
/// speechToText.onEnd.listen((_) {
///   print('Speech recognition ended');
/// });
///
/// // Start listening
/// await speechToText.start(language: 'en-US');
///
/// // Stop listening
/// await speechToText.stop();
/// ```
class SpeechToText {
  static const MethodChannel _channel = MethodChannel(
    'com.dbkable.speech_to_text/methods',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.dbkable.speech_to_text/events',
  );

  static SpeechToText? _instance;

  final StreamController<SpeechResult> _resultController =
      StreamController<SpeechResult>.broadcast();
  final StreamController<SpeechError> _errorController =
      StreamController<SpeechError>.broadcast();
  final StreamController<void> _endController =
      StreamController<void>.broadcast();

  StreamSubscription<dynamic>? _eventSubscription;
  bool _isInitialized = false;

  /// Creates a singleton instance of [SpeechToText].
  factory SpeechToText() {
    _instance ??= SpeechToText._internal();
    return _instance!;
  }

  SpeechToText._internal() {
    _initialize();
  }

  void _initialize() {
    if (_isInitialized) return;

    debugPrint('[SpeechToText] Initializing event stream...');

    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        debugPrint('[SpeechToText] Received event: $event');
        if (event is Map) {
          final eventType = event['type'] as String?;
          final data = event['data'] as Map?;

          debugPrint('[SpeechToText] Event type: $eventType, data: $data');

          switch (eventType) {
            case 'onSpeechResult':
              if (data != null) {
                debugPrint('[SpeechToText] Emitting result...');
                _resultController.add(SpeechResult.fromMap(data));
              }
              break;
            case 'onSpeechError':
              if (data != null) {
                debugPrint('[SpeechToText] Emitting error...');
                _errorController.add(SpeechError.fromMap(data));
              }
              break;
            case 'onSpeechEnd':
              debugPrint('[SpeechToText] Emitting end...');
              _endController.add(null);
              break;
          }
        }
      },
      onError: (error) {
        debugPrint('[SpeechToText] Stream error: $error');
        _errorController.add(
          SpeechError(
            errorCode: SpeechErrorCode.unknownError,
            message: error.toString(),
          ),
        );
      },
    );

    _isInitialized = true;
    debugPrint('[SpeechToText] Initialized successfully');
  }

  /// Stream of speech recognition results.
  ///
  /// Emits both partial (interim) and final results.
  /// Check [SpeechResult.isFinal] to determine if the result is final.
  Stream<SpeechResult> get onResult => _resultController.stream;

  /// Stream of speech recognition errors.
  Stream<SpeechError> get onError => _errorController.stream;

  /// Stream that emits when speech recognition ends.
  Stream<void> get onEnd => _endController.stream;

  /// Starts speech recognition with the specified language.
  ///
  /// [language] is an optional locale identifier (e.g., 'en-US', 'fr-FR', 'es-ES').
  /// If not provided, defaults to the device's locale with English ('en-US') as fallback.
  ///
  /// Throws a [SpeechError] if:
  /// - Permissions are not granted ([SpeechErrorCode.permissionDenied])
  /// - Speech recognition is not available ([SpeechErrorCode.notAvailable])
  /// - Failed to start recognition ([SpeechErrorCode.startFailed])
  ///
  /// Example:
  /// ```dart
  /// // Use device language
  /// await speechToText.start();
  ///
  /// // Or specify a language
  /// await speechToText.start(language: 'fr-FR');
  /// ```
  Future<void> start({String? language}) async {
    final effectiveLanguage = language ?? _getDeviceLanguage();
    debugPrint('[SpeechToText] Starting with language: $effectiveLanguage');
    try {
      await _channel.invokeMethod('start', {'language': effectiveLanguage});
    } on PlatformException catch (e) {
      throw SpeechError(
        errorCode: SpeechErrorCode.fromString(e.code),
        message: e.message ?? 'Unknown error',
      );
    }
  }

  /// Gets the device's current language locale.
  /// Falls back to 'en-US' if the locale cannot be determined.
  String _getDeviceLanguage() {
    try {
      final locale = PlatformDispatcher.instance.locale;
      // Format as language-country (e.g., 'en-US', 'fr-FR')
      if (locale.countryCode != null && locale.countryCode!.isNotEmpty) {
        return '${locale.languageCode}-${locale.countryCode}';
      }
      // If no country code, try common mappings
      return _getDefaultLocaleForLanguage(locale.languageCode);
    } catch (e) {
      debugPrint('[SpeechToText] Error getting device language: $e');
      return 'en-US';
    }
  }

  /// Returns a default locale for a given language code.
  String _getDefaultLocaleForLanguage(String languageCode) {
    const defaults = {
      'en': 'en-US',
      'fr': 'fr-FR',
      'es': 'es-ES',
      'de': 'de-DE',
      'it': 'it-IT',
      'pt': 'pt-BR',
      'zh': 'zh-CN',
      'ja': 'ja-JP',
      'ko': 'ko-KR',
      'ar': 'ar-SA',
      'ru': 'ru-RU',
      'nl': 'nl-NL',
      'pl': 'pl-PL',
      'tr': 'tr-TR',
      'vi': 'vi-VN',
      'th': 'th-TH',
      'hi': 'hi-IN',
    };
    return defaults[languageCode] ?? 'en-US';
  }

  /// Stops speech recognition.
  ///
  /// When stopped, a final result will be emitted with [SpeechResult.isFinal]
  /// set to true, followed by an [onEnd] event.
  ///
  /// Example:
  /// ```dart
  /// await speechToText.stop();
  /// ```
  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
    } on PlatformException catch (e) {
      throw SpeechError(
        errorCode: SpeechErrorCode.fromString(e.code),
        message: e.message ?? 'Unknown error',
      );
    }
  }

  /// Requests microphone and speech recognition permissions.
  ///
  /// [options] can be used to customize the permission dialog on Android.
  /// On iOS, the system handles permission dialogs automatically.
  ///
  /// Returns `true` if all permissions are granted, `false` otherwise.
  ///
  /// Example:
  /// ```dart
  /// final hasPermission = await speechToText.requestPermissions(
  ///   options: PermissionOptions(
  ///     title: 'Microphone Permission',
  ///     message: 'We need microphone access for voice recognition.',
  ///     buttonPositive: 'Allow',
  ///   ),
  /// );
  /// ```
  Future<bool> requestPermissions({PermissionOptions? options}) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'requestPermissions',
        options?.toMap(),
      );
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Checks if speech recognition is available on this device.
  ///
  /// Returns `true` if speech recognition is available, `false` otherwise.
  ///
  /// Example:
  /// ```dart
  /// final available = await speechToText.isAvailable();
  /// if (!available) {
  ///   print('Speech recognition not available on this device');
  /// }
  /// ```
  Future<bool> isAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAvailable');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Opens the system settings for speech recognition permissions.
  ///
  /// On macOS, this opens System Settings > Privacy & Security > Speech Recognition.
  /// On iOS, this opens Settings > Privacy > Speech Recognition.
  /// On Android, this opens the app's settings page.
  ///
  /// This is useful when permissions have been denied and the user needs to
  /// manually grant them, or on macOS where requesting permissions programmatically
  /// can cause crashes in debug mode.
  ///
  /// Returns `true` if settings were opened successfully, `false` otherwise.
  ///
  /// Example:
  /// ```dart
  /// final hasPermission = await speechToText.requestPermissions();
  /// if (!hasPermission) {
  ///   // Ask user to grant permissions manually
  ///   await speechToText.openSettings();
  /// }
  /// ```
  Future<bool> openSettings() async {
    try {
      final result = await _channel.invokeMethod<bool>('openSettings');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Disposes of the speech-to-text resources.
  ///
  /// Call this when you no longer need speech recognition to free up resources.
  void dispose() {
    _eventSubscription?.cancel();
    _resultController.close();
    _errorController.close();
    _endController.close();
    _isInitialized = false;
    _instance = null;
  }
}
