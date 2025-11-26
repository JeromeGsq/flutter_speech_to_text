import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text_native/speech_to_text_native.dart';

void main() {
  group('SpeechResult', () {
    test('creates instance with required parameters', () {
      const result = SpeechResult(
        transcript: 'Hello world',
        confidence: 0.95,
        isFinal: true,
      );

      expect(result.transcript, 'Hello world');
      expect(result.confidence, 0.95);
      expect(result.isFinal, true);
    });

    test('creates instance from map', () {
      final map = {
        'transcript': 'Test transcript',
        'confidence': 0.85,
        'isFinal': false,
      };

      final result = SpeechResult.fromMap(map);

      expect(result.transcript, 'Test transcript');
      expect(result.confidence, 0.85);
      expect(result.isFinal, false);
    });

    test('handles null values in map with defaults', () {
      final map = <dynamic, dynamic>{};

      final result = SpeechResult.fromMap(map);

      expect(result.transcript, '');
      expect(result.confidence, 0.0);
      expect(result.isFinal, false);
    });

    test('handles numeric confidence as int', () {
      final map = {
        'transcript': 'Test',
        'confidence': 1,
        'isFinal': true,
      };

      final result = SpeechResult.fromMap(map);

      expect(result.confidence, 1.0);
    });

    test('converts to map correctly', () {
      const result = SpeechResult(
        transcript: 'Hello',
        confidence: 0.9,
        isFinal: true,
      );

      final map = result.toMap();

      expect(map['transcript'], 'Hello');
      expect(map['confidence'], 0.9);
      expect(map['isFinal'], true);
    });

    test('toString returns readable format', () {
      const result = SpeechResult(
        transcript: 'Test',
        confidence: 0.5,
        isFinal: false,
      );

      expect(
        result.toString(),
        'SpeechResult(transcript: Test, confidence: 0.5, isFinal: false)',
      );
    });

    test('equality works correctly', () {
      const result1 = SpeechResult(
        transcript: 'Hello',
        confidence: 0.9,
        isFinal: true,
      );
      const result2 = SpeechResult(
        transcript: 'Hello',
        confidence: 0.9,
        isFinal: true,
      );
      const result3 = SpeechResult(
        transcript: 'Different',
        confidence: 0.9,
        isFinal: true,
      );

      expect(result1, equals(result2));
      expect(result1, isNot(equals(result3)));
    });

    test('hashCode is consistent with equality', () {
      const result1 = SpeechResult(
        transcript: 'Hello',
        confidence: 0.9,
        isFinal: true,
      );
      const result2 = SpeechResult(
        transcript: 'Hello',
        confidence: 0.9,
        isFinal: true,
      );

      expect(result1.hashCode, equals(result2.hashCode));
    });
  });
}
