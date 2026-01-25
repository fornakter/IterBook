// Basic widget tests for IterBook app

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iterbook/main.dart';

void main() {
  testWidgets('App loads and shows title', (WidgetTester tester) async {
    // Build app and trigger a frame
    await tester.pumpWidget(const MyApp());

    // Pump a few frames to allow initial build
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    // Verify app title is displayed
    expect(find.text('IterBook'), findsOneWidget);
  });

  testWidgets('Settings button is visible', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    // Verify settings icon is present
    expect(find.byIcon(Icons.settings), findsOneWidget);
  });

  testWidgets('Add book FAB is visible', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    // Verify FAB with add icon is present
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
