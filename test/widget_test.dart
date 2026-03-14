// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meditrack/main.dart';

void main() {
  testWidgets('Meditrack login screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MeditrackApp());

    expect(find.text('Meditrack'), findsOneWidget);
    expect(find.text('Login / Sign up'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });
}
