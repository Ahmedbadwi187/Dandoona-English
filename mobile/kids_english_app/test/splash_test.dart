import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/features/splash/dandoona_splash.dart';

Future<void> _pump(WidgetTester t, {bool enabled = true}) => t.pumpWidget(
      MaterialApp(home: DandoonaSplash(enabled: enabled, child: const Scaffold(body: Text('the app')))),
    );

void main() {
  testWidgets('the app is built underneath from the first frame, and the splash shows Dandoona', (t) async {
    await _pump(t);
    expect(find.text('the app', skipOffstage: false), findsOneWidget); // loads in parallel
    expect(find.bySemanticsLabel('Dandoona'), findsOneWidget);
  });

  testWidgets('it plays by itself and is gone within 2.5 seconds', (t) async {
    await _pump(t);
    await t.pump(const Duration(milliseconds: 600));
    expect(find.bySemanticsLabel('Dandoona'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 1800));
    expect(find.bySemanticsLabel('Dandoona'), findsNothing);
    expect(find.text('the app'), findsOneWidget);
    expect(DandoonaSplash.total, lessThanOrEqualTo(const Duration(milliseconds: 2500)));
  });

  testWidgets('a tap skips the animation straight to the app', (t) async {
    await _pump(t);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.byType(DandoonaSplash));
    await t.pump();
    expect(find.bySemanticsLabel('Dandoona'), findsNothing);
    expect(find.text('the app'), findsOneWidget);
  });

  testWidgets('disabled (tests, previews) shows only the app', (t) async {
    await _pump(t, enabled: false);
    expect(find.bySemanticsLabel('Dandoona'), findsNothing);
    expect(find.text('the app'), findsOneWidget);
  });
}
