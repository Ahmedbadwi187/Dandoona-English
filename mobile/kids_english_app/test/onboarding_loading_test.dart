import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/core/strings.dart';
import 'package:kids_english_app/features/gate/parental_gate.dart';
import 'package:kids_english_app/features/onboarding/onboarding_screens.dart';
import 'package:kids_english_app/features/session/session.dart';

import 'helpers.dart';

void main() {
  for (final screen in ['language', 'auth', 'reminder', 'summary']) {
    testWidgets('$screen keeps loading until its action finishes and prevents a second tap', (t) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 1080 / 411;
      addTearDown(t.view.reset);
      final pending = Completer<void>();
      var calls = 0;
      Future<void> submit() {
        calls++;
        return pending.future;
      }

      final Widget child;
      switch (screen) {
        case 'language':
          child = LanguageScreen(selected: 'en', onSelect: (_) {}, onContinue: submit);
        case 'auth':
          child = AuthScreen(
            s: Strings.en,
            signup: false,
            email: 'parent@example.com',
            password: 'secret-pass',
            firstName: '',
            guardian: false,
            agreed: false,
            onToggleMode: () {},
            onEmail: (_) {},
            onPassword: (_) {},
            onFirstName: (_) {},
            onGuardian: (_) {},
            onAgreed: (_) {},
            onSubmit: submit,
            onBack: () {},
          );
        case 'reminder':
          child = ReminderScreen(s: Strings.en, time: 'morning', onTime: (_) {}, onRemind: submit, onLater: () {}, onBack: () {});
        default:
          child = SummaryScreen(s: Strings.en, name: 'Lina', rows: const [], onEdit: (_) {}, onStart: submit, onBack: () {});
      }
      await t.pumpWidget(MaterialApp(home: child));
      await t.pumpAndSettle();

      final button = find.byKey(const Key('ob-continue'));
      final invoke = t.widget<FilledButton>(button).onPressed!;
      final originalSize = t.getSize(button);
      invoke();
      invoke(); // Also reject a stale callback before the disabled button rebuilds.
      await t.pump();
      expect(calls, 1);
      expect(t.widget<FilledButton>(button).onPressed, isNull);
      expect(find.descendant(of: button, matching: find.byType(CircularProgressIndicator)), findsOneWidget);
      expect(t.getSize(button), originalSize);
      final back = find.byKey(const Key('ob-back'));
      if (back.evaluate().isNotEmpty) expect(t.widget<IconButton>(back).onPressed, isNull);
      final secondary = find.byKey(const Key('ob-secondary'));
      if (secondary.evaluate().isNotEmpty) expect(t.widget<TextButton>(secondary).onPressed, isNull);

      pending.complete();
      await t.pumpAndSettle();
      expect(t.widget<FilledButton>(button).onPressed, isNotNull);
      expect(find.descendant(of: button, matching: find.byType(CircularProgressIndicator)), findsNothing);
      expect(t.getSize(button), originalSize);
    });
  }

  testWidgets('auth reflects controller loading and blocks switching modes until it finishes', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: AuthScreen(
          s: Strings.en,
          signup: false,
          email: 'parent@example.com',
          password: 'secret-pass',
          firstName: '',
          guardian: false,
          agreed: false,
          busy: true,
          onToggleMode: () {},
          onEmail: (_) {},
          onPassword: (_) {},
          onFirstName: (_) {},
          onGuardian: (_) {},
          onAgreed: (_) {},
          onSubmit: () {},
        ),
      ),
    );
    await t.pump();
    final button = find.byKey(const Key('ob-continue'));
    expect(t.widget<FilledButton>(button).onPressed, isNull);
    expect(find.descendant(of: button, matching: find.byType(CircularProgressIndicator)), findsOneWidget);
    expect(t.widget<TextButton>(find.byKey(const Key('ob-secondary'))).onPressed, isNull);
  });

  testWidgets('time-up continue allows only one pending parental gate and recovers after cancel', (t) async {
    final overrides = await testOverrides();
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    container.read(sessionSecondsProvider.notifier).tick(15 * 60);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SessionGuard(tickEvery: Duration(days: 1), child: SizedBox.expand()),
        ),
      ),
    );
    await t.pumpAndSettle();
    final button = find.descendant(of: find.byKey(const Key('time-up-overlay')), matching: find.byType(FilledButton));
    final invoke = t.widget<FilledButton>(button).onPressed!;
    invoke();
    invoke();
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byType(ParentalGateDialog), findsOneWidget);
    expect(t.widget<FilledButton>(button).onPressed, isNull);
    expect(find.descendant(of: button, matching: find.byType(CircularProgressIndicator)), findsOneWidget);
    await t.tap(find.descendant(of: find.byType(ParentalGateDialog), matching: find.byType(TextButton)));
    await t.pumpAndSettle();
    expect(t.widget<FilledButton>(button).onPressed, isNotNull);
    expect(find.byType(ParentalGateDialog), findsNothing);
    expect(container.read(sessionSecondsProvider), 15 * 60);
  });
}
