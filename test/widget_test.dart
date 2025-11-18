// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quick_sharing/main.dart';

void main() {
  testWidgets('Quick Share app initialization test', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: QuickShareApp()));

    // Wait for the app to initialize
    await tester.pump();

    // Verify that the app title is displayed
    expect(find.text('Quick Share'), findsOneWidget);

    // Verify that the "Nearby Devices" section exists
    expect(find.text('Nearby Devices'), findsOneWidget);
  });
}
