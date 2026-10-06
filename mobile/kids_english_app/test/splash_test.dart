import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/core/storage.dart';
import 'package:kids_english_app/features/splash/dandoona_splash.dart';

import 'helpers.dart';

Future<List<String>> _pump(WidgetTester t, {String language = 'ar', bool enabled = true}) async {
  final played = <String>[];
  final prefs = await mockPrefs({
    'settings.v1': '{"languageCode":"$language","sessionMinutes":15,"unlockAll":false,"onboarded":true}',
  });
  await t.pumpWidget(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      greetingPlayerProvider.overrideWithValue((path) async => played.add(path)),
    ],
    child: MaterialApp(home: DandoonaSplash(enabled: enabled, child: const Scaffold(body: Text('the app')))),
  ));
  return played;
}

void main() {
  testWidgets('the app is built underneath from the first frame, and the splash shows Dandoona', (t) async {
    await _pump(t);
    expect(find.text('the app', skipOffstage: false), findsOneWidget); // loads in parallel
    expect(find.bySemanticsLabel('Dandoona'), findsOneWidget);
  });

  testWidgets('it plays by itself, greets once in the parent language, and is gone within 2.5 seconds', (t) async {
    final played = await _pump(t);
    await t.pump(const Duration(milliseconds: 100));
    expect(played, isEmpty); // the first frames are static, like the native splash
    await t.pump(const Duration(milliseconds: 500));
    expect(played, ['audio/brand/dandoona_hello_ar.mp3']);
    await t.pump(const Duration(milliseconds: 1800));
    expect(find.bySemanticsLabel('Dandoona'), findsNothing);
    expect(find.text('the app'), findsOneWidget);
    expect(played, hasLength(1));
    expect(DandoonaSplash.total, lessThanOrEqualTo(const Duration(milliseconds: 2500)));
  });

  testWidgets('English parents hear the English greeting', (t) async {
    final played = await _pump(t, language: 'en');
    await t.pump(const Duration(milliseconds: 600));
    expect(played, ['audio/brand/dandoona_hello_en.mp3']);
    await t.pumpAndSettle();
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
    final played = await _pump(t, enabled: false);
    expect(find.bySemanticsLabel('Dandoona'), findsNothing);
    expect(find.text('the app'), findsOneWidget);
    expect(played, isEmpty);
  });

  test('the greeting files are bundled', () {
    expect(greetingAsset('ar'), 'audio/brand/dandoona_hello_ar.mp3');
    expect(greetingAsset('en'), 'audio/brand/dandoona_hello_en.mp3');
  });
}
