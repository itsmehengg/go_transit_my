// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:go_transit_my/app.dart';

void main() {
  testWidgets('App splash screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const GoTransitApp());

    // Verify that the splash screen text is present.
    expect(find.text('GoTransit MY'), findsOneWidget);
    expect(find.text('Smart Public Transport Tracker'), findsOneWidget);

    // Verify that the loading indicator is present.
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}
