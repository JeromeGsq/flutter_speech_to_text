import 'dart:async';

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
  /// [language] is a locale identifier (e.g., 'en-US', 'fr-FR', 'es-ES').
  ///
  /// Throws a [SpeechError] if:
  /// - Permissions are not granted ([SpeechErrorCode.permissionDenied])
  /// - Speech recognition is not available ([SpeechErrorCode.notAvailable])
  /// - Failed to start recognition ([SpeechErrorCode.startFailed])
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   await speechToText.start(language: 'en-US');
  /// } on SpeechError catch (e) {
  ///   print('Failed to start: ${e.message}');
  /// }
  /// ```
  Future<void> start({required String language}) async {
    try {
      await _channel.invokeMethod('start', {'language': language});
    } on PlatformException catch (e) {
      throw SpeechError(
        errorCode: SpeechErrorCode.fromString(e.code),
        message: e.message ?? 'Unknown error',
      );
    }
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
