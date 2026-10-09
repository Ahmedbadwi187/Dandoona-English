import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/app.dart';
import 'package:kids_english_app/core/strings.dart';
import 'package:kids_english_app/features/parent/settings_screen.dart';
import 'package:kids_english_app/features/router_state.dart';
import 'package:kids_english_app/features/settings/settings.dart';
import 'package:kids_english_app/router.dart';

import 'helpers.dart';

class _DelayedLanguageSettings extends SettingsNotifier {
  final pending = Completer<void>();
  int writes = 0;

  @override
  Future<void> setLanguage(String code) async {
    writes++;
    await super.setLanguage(code);
    await pending.future;
  }
}

void main() {
  testWidgets('copy cards keeps its label and blocks repeated presses until the clipboard completes', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 1080 / 411;
    addTearDown(t.view.reset);
    final pending = Completer<Object?>();
    var copies = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) {
      if (call.method == 'Clipboard.setData') {
        copies++;
        return pending.future;
      }
      return Future<Object?>.value();
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final overrides = await testOverrides(prefs: {
      'settings.v1': '{"languageCode":"en","sessionMinutes":15,"unlockAll":false}',
    });
    await t.pumpWidget(ProviderScope(overrides: overrides, child: const MaterialApp(home: SettingsScreen())));
    await t.pumpAndSettle();
    final button = find.byKey(const Key('cards-copy'));
    await t.ensureVisible(button);
    final originalSize = t.getSize(button);
    final originalText = t.widget<Text>(find.descendant(of: button, matching: find.byType(Text))).data;

    await t.tap(button);
    await t.pump();
    expect(t.widget<OutlinedButton>(button).onPressed, isNull);
    expect(find.descendant(of: button, matching: find.byType(CircularProgressIndicator)), findsOneWidget);
    expect(t.widget<Text>(find.descendant(of: button, matching: find.byType(Text))).data, originalText);
    expect(t.getSize(button), originalSize);
    await t.tap(button);
    await t.pump();
    expect(copies, 1);

    pending.complete();
    await t.pumpAndSettle();
    expect(t.widget<OutlinedButton>(button).onPressed, isNotNull);
    expect(find.descendant(of: button, matching: find.byType(CircularProgressIndicator)), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('language segments keep their labels and block selection while saving', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 1080 / 411;
    addTearDown(t.view.reset);
    final settings = _DelayedLanguageSettings();
    final overrides = await testOverrides();
    await t.pumpWidget(ProviderScope(
      overrides: [...overrides, settingsProvider.overrideWith(() => settings)],
      child: const MaterialApp(home: SettingsScreen()),
    ));
    await t.pumpAndSettle();
    final selector = find.byKey(const Key('language-selector'));
    final change = t.widget<SegmentedButton<String>>(selector).onSelectionChanged!;
    change({'en'});
    await t.pump(const Duration(milliseconds: 300));
    final pending = t.widget<SegmentedButton<String>>(selector);
    expect(pending.onSelectionChanged, isNull);
    expect(pending.selected, {'en'});
    expect(pending.segments.map((segment) => (segment.label as Text).data), [Strings.en('arabic'), Strings.en('english')]);
    expect(find.descendant(of: selector, matching: find.byType(CircularProgressIndicator)), findsOneWidget);
    change({'ar'}); // a stale callback cannot start another persistence operation
    await t.pump();
    expect(settings.writes, 1);
    expect(t.widget<SegmentedButton<String>>(selector).selected, {'en'});

    settings.pending.complete();
    await t.pumpAndSettle();
    expect(t.widget<SegmentedButton<String>>(selector).onSelectionChanged, isNotNull);
    expect(find.descendant(of: selector, matching: find.byType(CircularProgressIndicator)), findsNothing);
  });

  testWidgets('button and system back share one discard dialog and recover after keeping edits', (t) async {
    t.view.physicalSize = const Size(1080, 4200);
    t.view.devicePixelRatio = 1080 / 411;
    addTearDown(t.view.reset);
    final overrides = await testOverrides(prefs: {
      'settings.v1': '{"languageCode":"en","sessionMinutes":15,"unlockAll":false,"onboarded":true,"languageChosen":true}',
      'children.v1': '[{"id":"c1","name":"Omar","avatarKey":"bear","birthYear":2022,"birthMonth":1,"goalMinutes":10,"track":"little-learners","createdAt":"2026-01-01T00:00:00Z"}]',
    });
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    await t.pumpWidget(UncontrolledProviderScope(container: container, child: const KidsEnglishApp()));
    await t.pumpAndSettle();
    container.read(parentSessionProvider.notifier).unlock();
    container.read(routerProvider).go('/parent/children');
    await t.pumpAndSettle();
    container.read(routerProvider).push('/parent/children/c1');
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('edit-name')), 'Changed');
    await t.pump();
    final back = find.byKey(const Key('parent-back'));
    final buttonPress = t.widget<IconButton>(back).onPressed!;
    final popScope = find.ancestor(of: find.byKey(const Key('edit-name')), matching: find.byWidgetPredicate((w) => w is PopScope)).first; // (PopScope is generic: byType would not match it)
    final pop = (t.widget(popScope) as PopScope).onPopInvokedWithResult!;
    buttonPress();
    pop(false, null);
    pop(false, null);
    await t.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(t.widget<IconButton>(back).onPressed, isNull);
    expect(find.descendant(of: back, matching: find.byType(CircularProgressIndicator)), findsOneWidget);
    await t.tap(find.byKey(const Key('keep-editing')));
    await t.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(t.widget<IconButton>(back).onPressed, isNotNull);

    pop(false, null);
    pop(false, null);
    await t.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await t.tap(find.byKey(const Key('discard-confirm')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('manage-title')), findsOneWidget);
    expect(container.read(settingsProvider).languageCode, 'en');
  });
}
