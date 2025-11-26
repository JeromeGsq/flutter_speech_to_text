import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text_native/speech_to_text_native.dart';

void main() {
  group('PermissionOptions', () {
    test('creates instance with no parameters', () {
      const options = PermissionOptions();

      expect(options.title, isNull);
      expect(options.message, isNull);
      expect(options.buttonNeutral, isNull);
      expect(options.buttonNegative, isNull);
      expect(options.buttonPositive, isNull);
    });

    test('creates instance with all parameters', () {
      const options = PermissionOptions(
        title: 'Permission Required',
        message: 'We need microphone access',
        buttonNeutral: 'Later',
        buttonNegative: 'Deny',
        buttonPositive: 'Allow',
      );

      expect(options.title, 'Permission Required');
      expect(options.message, 'We need microphone access');
      expect(options.buttonNeutral, 'Later');
      expect(options.buttonNegative, 'Deny');
      expect(options.buttonPositive, 'Allow');
    });

    test('toMap excludes null values', () {
      const options = PermissionOptions(
        title: 'Test Title',
        buttonPositive: 'OK',
      );

      final map = options.toMap();

      expect(map.containsKey('title'), true);
      expect(map.containsKey('buttonPositive'), true);
      expect(map.containsKey('message'), false);
      expect(map.containsKey('buttonNeutral'), false);
      expect(map.containsKey('buttonNegative'), false);
    });

    test('toMap returns empty map when all values are null', () {
      const options = PermissionOptions();

      final map = options.toMap();

      expect(map.isEmpty, true);
    });

    test('toMap includes all non-null values', () {
      const options = PermissionOptions(
        title: 'Title',
        message: 'Message',
        buttonNeutral: 'Neutral',
        buttonNegative: 'Negative',
        buttonPositive: 'Positive',
      );

      final map = options.toMap();

      expect(map['title'], 'Title');
      expect(map['message'], 'Message');
      expect(map['buttonNeutral'], 'Neutral');
      expect(map['buttonNegative'], 'Negative');
      expect(map['buttonPositive'], 'Positive');
      expect(map.length, 5);
    });
  });
}
