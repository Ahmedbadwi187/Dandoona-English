import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/app.dart';
import 'package:kids_english_app/core/strings.dart';
import 'package:kids_english_app/core/storage.dart';
import 'package:kids_english_app/features/onboarding/language_route.dart';
import 'package:kids_english_app/features/parent/settings_screen.dart';
import 'package:kids_english_app/features/settings/settings.dart';
import 'package:kids_english_app/router.dart';

import 'helpers.dart';

Future<ProviderContainer> _start(WidgetTester t, {String device = 'en', Map<String, Object> prefs = const {}}) async {
  final overrides = await testOverrides(prefs: prefs);
  final container = ProviderContainer(overrides: [...overrides, deviceLanguageProvider.overrideWithValue(device)]);
  addTearDown(container.dispose);
  await t.pumpWidget(UncontrolledProviderScope(container: container, child: const KidsEnglishApp()));
  await t.pumpAndSettle();
  return container;
}

void main() {
  group('the language screen is the very first screen', () {
    testWidgets('a fresh install shows it, with both languages written in their own language', (t) async {
      await _start(t);
      expect(find.byKey(const Key('lang-ar')), findsOneWidget);
      expect(find.byKey(const Key('lang-en')), findsOneWidget);
      expect(find.text('العربية'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
    });

    testWidgets('an Arabic phone has Arabic pre-selected and the screen is already right to left; one tap confirms', (t) async {
      final c = await _start(t, device: 'ar');
      expect(Directionality.of(t.element(find.byKey(const Key('lang-ar')))), TextDirection.rtl);
      expect(find.text('متابعة'), findsOneWidget);
      await t.tap(find.byKey(const Key('ob-continue')));
      await t.pumpAndSettle();
      expect(c.read(settingsProvider).languageCode, 'ar');
      expect(c.read(settingsProvider).languageChosen, isTrue);
    });

    testWidgets('an English phone has English pre-selected (left to right)', (t) async {
      await _start(t, device: 'en');
      expect(Directionality.of(t.element(find.byKey(const Key('lang-en')))), TextDirection.ltr);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('choosing English flips the screen at once and the following screens are English and left to right', (t) async {
      final c = await _start(t, device: 'ar');
      await t.ensureVisible(find.byKey(const Key('lang-en'))); // (the default test screen is short and the language screen now has a line of explanation)
      await t.tap(find.byKey(const Key('lang-en')));
      await t.pumpAndSettle();
      expect(Directionality.of(t.element(find.byKey(const Key('lang-en')))), TextDirection.ltr);
      expect(find.text('Continue'), findsOneWidget);

      await t.tap(find.byKey(const Key('ob-continue')));
      await t.pumpAndSettle();
      expect(c.read(settingsProvider).languageCode, 'en');
      expect(find.byKey(const Key('ob-continue')), findsOneWidget); // the next screen
      expect(Directionality.of(t.element(find.byKey(const Key('ob-continue')))), TextDirection.ltr);
    });

    testWidgets('it is shown on the first launch only: the choice is saved and the next launch skips it', (t) async {
      final c = await _start(t, device: 'ar');
      await t.tap(find.byKey(const Key('ob-continue')));
      await t.pumpAndSettle();

      final prefs = c.read(sharedPreferencesProvider);
      final second = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs), deviceLanguageProvider.overrideWithValue('ar')]);
      addTearDown(second.dispose);
      await t.pumpWidget(UncontrolledProviderScope(container: second, child: const KidsEnglishApp(key: Key('second-launch'))));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('lang-ar')), findsNothing);
    });

    testWidgets('settings saved before this screen existed count as chosen (no language screen for existing parents)', (t) async {
      await _start(t, prefs: {'settings.v1': '{"languageCode":"en","sessionMinutes":15,"unlockAll":false,"onboarded":true}'});
      expect(find.byKey(const Key('lang-ar')), findsNothing);
    });
  });

  testWidgets('the parent changes the language in settings and the screen updates immediately, without restarting', (t) async {
    final overrides = await testOverrides(prefs: {'settings.v1': '{"languageCode":"ar","sessionMinutes":15,"unlockAll":false,"onboarded":true,"languageChosen":true}'});
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    await t.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) {
          final s = ref.watch(settingsProvider);
          return MaterialApp(
            locale: Locale(s.languageCode),
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
            home: const SettingsScreen(),
          );
        },
      ),
    ));
    await t.pumpAndSettle();
    expect(find.text('الإعدادات'), findsOneWidget);
    expect(Directionality.of(t.element(find.text('الإعدادات'))), TextDirection.rtl);

    await t.tap(find.text('English'));
    await t.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(Directionality.of(t.element(find.text('Settings'))), TextDirection.ltr);

    await t.tap(find.text('العربية'));
    await t.pumpAndSettle();
    expect(find.text('الإعدادات'), findsOneWidget);
  });


  group('localization keys', () {
    test('a key missing in either language is named in the failure', () {
      final ar = Strings.arabicKeys.toSet(), en = Strings.englishKeys.toSet();
      expect(en.difference(ar), isEmpty, reason: 'keys missing in Arabic');
      expect(ar.difference(en), isEmpty, reason: 'keys missing in English');
    });

    test('placeholders such as {name} appear in both languages', () {
      for (final key in Strings.englishKeys) {
        final inEn = RegExp(r'\{(\w+)\}').allMatches(Strings.en(key)).map((m) => m[1]).toSet();
        final inAr = RegExp(r'\{(\w+)\}').allMatches(Strings.ar(key)).map((m) => m[1]).toSet();
        expect(inAr, inEn, reason: key);
      }
    });

    test('every key written in the code as s(\'key\') or Strings.en(\'key\') exists in both languages', () {
      final used = <String>{};
      for (final file in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
        if (file.path.endsWith('strings.dart')) continue;
        final text = file.readAsStringSync();
        used.addAll(RegExp(r"""(?:\bs|Strings\.en|Strings\.ar)\(\s*'([A-Za-z0-9]+)'\s*\)""").allMatches(text).map((m) => m[1]!));
      }
      expect(used, isNotEmpty);
      final known = Strings.englishKeys.toSet();
      expect(used.where((k) => !known.contains(k)).toList(), isEmpty, reason: 'used in the code but not defined');
    });
  });

  group('route guard', () {
    String? go(String location, {required bool chosen}) =>
        guardRoute(location: location, onboarded: false, hasProfiles: false, parentUnlocked: false, hasActiveChild: false, languageChosen: chosen);

    test('before the language is chosen every path leads to the language screen', () {
      for (final p in ['/', '/onboarding', '/who', '/map', '/parent']) {
        expect(go(p, chosen: false), '/language', reason: p);
      }
      expect(go('/language', chosen: false), isNull);
    });

    test('after it, the first launch continues to onboarding', () {
      expect(go('/', chosen: true), '/onboarding');
    });
  });
}
