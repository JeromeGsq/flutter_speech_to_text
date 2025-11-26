// This is a basic Flutter widget test for the speech_to_text_native example app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:speech_to_text_example/main.dart';

void main() {
  testWidgets('App smoke test - app builds and shows title',
      (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the app title is displayed.
    expect(find.text('Speech to Text'), findsOneWidget);

    // Verify subtitle is displayed.
    expect(find.text('Native Recognition'), findsOneWidget);
  });

  testWidgets('App shows status indicators', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Verify status labels are shown.
    expect(find.text('Available'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Confidence'), findsOneWidget);

    // Verify the transcript label.
    expect(find.text('Transcript'), findsOneWidget);
  });

  testWidgets('App shows microphone button', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Verify the microphone icon exists (in button and header).
    expect(find.byIcon(Icons.mic_rounded), findsWidgets);
  });
}
