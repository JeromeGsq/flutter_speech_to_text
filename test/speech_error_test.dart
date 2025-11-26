import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text_native/speech_to_text_native.dart';

void main() {
  group('SpeechErrorCode', () {
    test('has correct code strings', () {
      expect(SpeechErrorCode.permissionDenied.code, 'PERMISSION_DENIED');
      expect(SpeechErrorCode.notAvailable.code, 'NOT_AVAILABLE');
      expect(SpeechErrorCode.requestFailed.code, 'REQUEST_FAILED');
      expect(SpeechErrorCode.startFailed.code, 'START_FAILED');
      expect(SpeechErrorCode.stopFailed.code, 'STOP_FAILED');
      expect(SpeechErrorCode.audioError.code, 'AUDIO_ERROR');
      expect(SpeechErrorCode.clientError.code, 'CLIENT_ERROR');
      expect(SpeechErrorCode.networkError.code, 'NETWORK_ERROR');
      expect(SpeechErrorCode.networkTimeout.code, 'NETWORK_TIMEOUT');
      expect(SpeechErrorCode.recognizerBusy.code, 'RECOGNIZER_BUSY');
      expect(SpeechErrorCode.serverError.code, 'SERVER_ERROR');
      expect(SpeechErrorCode.unknownError.code, 'UNKNOWN_ERROR');
    });

    test('fromString returns correct enum value', () {
      expect(
        SpeechErrorCode.fromString('PERMISSION_DENIED'),
        SpeechErrorCode.permissionDenied,
      );
      expect(
        SpeechErrorCode.fromString('NOT_AVAILABLE'),
        SpeechErrorCode.notAvailable,
      );
      expect(
        SpeechErrorCode.fromString('NETWORK_ERROR'),
        SpeechErrorCode.networkError,
      );
    });

    test('fromString returns unknownError for invalid code', () {
      expect(
        SpeechErrorCode.fromString('INVALID_CODE'),
        SpeechErrorCode.unknownError,
      );
      expect(
        SpeechErrorCode.fromString(''),
        SpeechErrorCode.unknownError,
      );
    });
  });

  group('SpeechError', () {
    test('creates instance with required parameters', () {
      const error = SpeechError(
        errorCode: SpeechErrorCode.permissionDenied,
        message: 'Permission was denied',
      );

      expect(error.errorCode, SpeechErrorCode.permissionDenied);
      expect(error.message, 'Permission was denied');
    });

    test('creates instance from map', () {
      final map = {
        'code': 'NETWORK_ERROR',
        'message': 'Network connection failed',
      };

      final error = SpeechError.fromMap(map);

      expect(error.errorCode, SpeechErrorCode.networkError);
      expect(error.message, 'Network connection failed');
    });

    test('handles missing code in map', () {
      final map = <dynamic, dynamic>{
        'message': 'Some error',
      };

      final error = SpeechError.fromMap(map);

      expect(error.errorCode, SpeechErrorCode.unknownError);
    });

    test('handles missing message in map', () {
      final map = {
        'code': 'AUDIO_ERROR',
      };

      final error = SpeechError.fromMap(map);

      expect(error.message, 'Unknown error');
    });

    test('converts to map correctly', () {
      const error = SpeechError(
        errorCode: SpeechErrorCode.serverError,
        message: 'Server failed',
      );

      final map = error.toMap();

      expect(map['code'], 'SERVER_ERROR');
      expect(map['message'], 'Server failed');
    });

    test('toString returns readable format', () {
      const error = SpeechError(
        errorCode: SpeechErrorCode.audioError,
        message: 'Audio issue',
      );

      expect(error.toString(), 'SpeechError(AUDIO_ERROR): Audio issue');
    });

    test('implements Exception', () {
      const error = SpeechError(
        errorCode: SpeechErrorCode.unknownError,
        message: 'Test',
      );

      expect(error, isA<Exception>());
    });
  });
}
