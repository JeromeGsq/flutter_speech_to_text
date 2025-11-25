/// Error codes returned by the speech recognition service.
enum SpeechErrorCode {
  /// User denied microphone or speech recognition permissions.
  permissionDenied('PERMISSION_DENIED'),

  /// Speech recognition is not available on this device.
  notAvailable('NOT_AVAILABLE'),

  /// Failed to create recognition request.
  requestFailed('REQUEST_FAILED'),

  /// Failed to start speech recognition.
  startFailed('START_FAILED'),

  /// Failed to stop speech recognition.
  stopFailed('STOP_FAILED'),

  /// Audio recording error.
  audioError('AUDIO_ERROR'),

  /// Client-side error.
  clientError('CLIENT_ERROR'),

  /// Network error during recognition.
  networkError('NETWORK_ERROR'),

  /// Network request timed out.
  networkTimeout('NETWORK_TIMEOUT'),

  /// Speech recognizer is busy.
  recognizerBusy('RECOGNIZER_BUSY'),

  /// Server-side error.
  serverError('SERVER_ERROR'),

  /// Unknown error occurred.
  unknownError('UNKNOWN_ERROR');

  final String code;
  const SpeechErrorCode(this.code);

  static SpeechErrorCode fromString(String code) {
    return SpeechErrorCode.values.firstWhere(
      (e) => e.code == code,
      orElse: () => SpeechErrorCode.unknownError,
    );
  }
}

/// Represents an error that occurred during speech recognition.
class SpeechError implements Exception {
  /// The error code identifying the type of error.
  final SpeechErrorCode errorCode;

  /// Human-readable error message.
  final String message;

  const SpeechError({required this.errorCode, required this.message});

  factory SpeechError.fromMap(Map<dynamic, dynamic> map) {
    final codeString = map['code'] as String? ?? 'UNKNOWN_ERROR';
    return SpeechError(
      errorCode: SpeechErrorCode.fromString(codeString),
      message: map['message'] as String? ?? 'Unknown error',
    );
  }

  Map<String, dynamic> toMap() {
    return {'code': errorCode.code, 'message': message};
  }

  @override
  String toString() => 'SpeechError(${errorCode.code}): $message';
}
