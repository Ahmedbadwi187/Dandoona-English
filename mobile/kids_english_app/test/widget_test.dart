import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/app.dart';
import 'package:kids_english_app/core/theme.dart';
import 'package:kids_english_app/features/gate/parental_gate.dart';
import 'package:kids_english_app/features/session/session.dart';

import 'helpers.dart';

Future<void> pumpApp(WidgetTester tester, {Map<String, Object> prefs = const {}}) async {
  final overrides = await testOverrides(prefs: prefs);
  await tester.pumpWidget(ProviderScope(overrides: overrides, child: const KidsEnglishApp()));
  await tester.pumpAndSettle();
}

/// Presses and holds the gate button long enough, then returns the challenge the dialog is showing.
Future<GateChallenge> passHoldStep(WidgetTester tester, int seed) async {
  final gesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('gate-hold'))));
  await tester.pump(const Duration(milliseconds: 200)); // press registers, hold animation starts
  await tester.pump(const Duration(seconds: 3)); // held past the 2 s requirement
  await gesture.up();
  await tester.pump();
  return GateChallenge.random(Random(seed)); // dialog was created with Random(seed): same challenge
}

void main() {
  group('parental gate dialog', () {
    Future<void> openGate(WidgetTester tester, ValueSetter<bool> onResult, int seed) async {
      final overrides = await testOverrides();
      await tester.pumpWidget(ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async => onResult(await showParentalGate(context, random: Random(seed))),
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('releasing early does not advance; holding does', (tester) async {
      bool? result;
      await openGate(tester, (r) => result = r, 7);
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('gate-hold'))));
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.up();
      await tester.pump();
      expect(find.byKey(const Key('gate-question')), findsNothing);

      await passHoldStep(tester, 7);
      expect(find.byKey(const Key('gate-question')), findsOneWidget);
      expect(result, isNull); // still open
    });

    testWidgets('correct answer passes the gate', (tester) async {
      bool? result;
      await openGate(tester, (r) => result = r, 7);
      final challenge = await passHoldStep(tester, 7);
      await tester.tap(find.byKey(Key('gate-option-${challenge.answer}')));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('wrong answer shows a message and keeps the gate closed', (tester) async {
      bool? result;
      await openGate(tester, (r) => result = r, 7);
      final challenge = await passHoldStep(tester, 7);
      final wrong = challenge.options.firstWhere((o) => o != challenge.answer);
      await tester.tap(find.byKey(Key('gate-option-$wrong')));
      await tester.pump();
      expect(find.text('إجابة غير صحيحة، حاول مرة أخرى'), findsOneWidget);
      expect(result, isNull);
    });

    testWidgets('cancel returns false', (tester) async {
      bool? result;
      await openGate(tester, (r) => result = r, 7);
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });
  });

  group('full flow', () {
    testWidgets('first launch: onboarding in Arabic (RTL) then create the first profile', (tester) async {
      await pumpApp(tester);
      expect(find.byKey(const Key('onboarding-start')), findsOneWidget);
      expect(find.text('أهلاً بك!'), findsOneWidget);
      expect(Directionality.of(tester.element(find.text('أهلاً بك!'))), TextDirection.rtl);

      await tester.tap(find.byKey(const Key('onboarding-start')));
      await tester.pumpAndSettle();

      // empty name is rejected with the Arabic message
      await tester.tap(find.byKey(const Key('child-save')));
      await tester.pumpAndSettle();
      expect(find.text('أدخل اسمًا من حرف إلى 30 حرفًا'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('child-name')), 'Omar');
      await tester.tap(find.byKey(const Key('avatar-rocket')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('child-save')));
      await tester.pumpAndSettle();

      // child area: English, LTR
      expect(find.text('Who is playing?'), findsOneWidget);
      expect(Directionality.of(tester.element(find.text('Who is playing?'))), TextDirection.ltr);
      expect(find.text('Omar'), findsOneWidget);
    });

    testWidgets('picking a child opens the 26-letter map; only A is open at first', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('onboarding-start')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('child-name')), 'Omar');
      await tester.tap(find.byKey(const Key('child-save')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Omar'));
      await tester.pumpAndSettle();

      final list = tester.widget<ListView>(find.byKey(const Key('letter-map')));
      expect(list.childrenDelegate.estimatedChildCount, 26);
      expect(find.byKey(const Key('node-letter-a')), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsWidgets); // B.. are locked

      // every tap target on the map is at least 64 dp
      final node = tester.getSize(find.byKey(const Key('node-letter-a')));
      expect(node.width, greaterThanOrEqualTo(kMinTapTarget));
      expect(node.height, greaterThanOrEqualTo(kMinTapTarget));
    });

    testWidgets('parent area is reached through the gate and is Arabic RTL', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('onboarding-start')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('child-name')), 'Omar');
      await tester.tap(find.byKey(const Key('child-save')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open-parent-area')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('للكبار فقط'), findsOneWidget);

      // The dialog uses Random(), so read the question from the screen.
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('gate-hold'))));
      await tester.pump(const Duration(milliseconds: 200)); // press registers, hold animation starts
  await tester.pump(const Duration(seconds: 3)); // held past the 2 s requirement
      await gesture.up();
      await tester.pump();
      final question = (tester.widget<Text>(find.byKey(const Key('gate-question'))).data)!; // "a × b = ?"
      final parts = RegExp(r'(\d+) × (\d+)').firstMatch(question)!;
      final answer = int.parse(parts.group(1)!) * int.parse(parts.group(2)!);
      await tester.tap(find.byKey(Key('gate-option-$answer')));
      await tester.pumpAndSettle();

      expect(find.text('منطقة الأهل'), findsOneWidget);
      expect(Directionality.of(tester.element(find.text('منطقة الأهل'))), TextDirection.rtl);
      expect(find.text('Omar'), findsOneWidget);
    });

    testWidgets('returning user (already onboarded, has a profile) goes straight to the picker', (tester) async {
      await pumpApp(tester, prefs: {
        'settings.v1': '{"languageCode":"ar","sessionMinutes":15,"unlockAll":false,"onboarded":true}',
        'children.v1': '[{"id":"c1","name":"Omar","avatarKey":"star","birthYear":2022,"track":"little-learners","createdAt":"2026-01-01T00:00:00Z"}]',
      });
      expect(find.text('Who is playing?'), findsOneWidget);
    });
  });

  group('session guard', () {
    testWidgets('the time-up overlay appears when the limit is reached and needs the gate', (tester) async {
      final overrides = await testOverrides();
      await tester.pumpWidget(ProviderScope(
        overrides: overrides,
        child: const MaterialApp(
          home: SessionGuard(tickEvery: Duration(milliseconds: 100), child: Scaffold(body: Text('play'))),
        ),
      ));
      expect(find.byKey(const Key('time-up-overlay')), findsNothing);

      final container = ProviderScope.containerOf(tester.element(find.text('play')));
      container.read(sessionSecondsProvider.notifier).tick(15 * 60);
      await tester.pump();
      expect(find.byKey(const Key('time-up-overlay')), findsOneWidget);
      expect(find.text('Time to rest'), findsOneWidget);
    });
  });
}
