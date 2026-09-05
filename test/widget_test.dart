import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:go_transit_my/app.dart';

void main() {
  testWidgets('App splash screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const GoTransitApp());

    expect(find.text('GoTransit MY'), findsOneWidget);
    expect(find.text('Smart Public Transport Tracker'), findsOneWidget);

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}
