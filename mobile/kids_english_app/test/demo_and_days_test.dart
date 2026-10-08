import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/app.dart';
import 'package:kids_english_app/features/activities/hand_demo.dart';
import 'package:kids_english_app/features/audio/audio_service.dart';
import 'package:kids_english_app/features/progress/active_days.dart';
import 'package:kids_english_app/features/progress/progress.dart';

import 'helpers.dart';

ProgressRecord _rec(String child, DateTime at, [String lesson = 'letter-a']) =>
    ProgressRecord(clientRecordId: 'r-$child-$at-$lesson', childId: child, lessonId: lesson, activity: 'trace', stars: 3, attempts: 1, timeSpentSeconds: 5, completedAt: at);

void main() {
  group('active days', () {
    test('every day with a finished activity counts once; days in between are simply not counted', () {
      final records = [
        _rec('a', DateTime(2026, 9, 1, 9)),
        _rec('a', DateTime(2026, 9, 1, 18), 'letter-b'), // same day
        _rec('a', DateTime(2026, 9, 5, 10)), // four days later: nothing is lost
        _rec('b', DateTime(2026, 9, 2, 10)),
      ];
      expect(activeDays(records, 'a'), 2);
      expect(activeDays(records, 'b'), 1);
      expect(activeDays(records, 'nobody'), 0);
    });

    test('milestones only grow', () {
      expect(milestoneFor(1), isNull);
      expect(milestoneFor(2), 2);
      expect(milestoneFor(6), 5);
      expect(milestoneFor(100), 100);
    });

    Future<ProviderContainer> map(WidgetTester t, String track, List<ProgressRecord> records, {Map<String, Object> extra = const {}}) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 1080 / 411;
      addTearDown(t.view.reset);
      final overrides = await testOverrides(content: realContent(), explorers: realExplorersContent(), prefs: {
        'settings.v1': '{"languageCode":"en","sessionMinutes":15,"unlockAll":false,"onboarded":true}',
        'children.v1': '[{"id":"c1","name":"Lina","avatarKey":"star","birthYear":2019,"birthMonth":2,"track":"$track","createdAt":"2026-01-01T00:00:00Z"}]',
        'progress.v1': jsonEncode([for (final r in records) r.toJson()]),
        ...extra,
      });
      final c = ProviderContainer(overrides: [...overrides, audioServiceProvider.overrideWithValue(FakeAudio()), recorderServiceProvider.overrideWithValue(FakeRecorder())]);
      addTearDown(c.dispose);
      await t.pumpWidget(UncontrolledProviderScope(container: c, child: const KidsEnglishApp()));
      await t.pumpAndSettle();
      return c;
    }

    final threeDays = [_rec('c1', DateTime(2026, 9, 1, 10)), _rec('c1', DateTime(2026, 9, 3, 10), 'letter-b'), _rec('c1', DateTime(2026, 9, 9, 10), 'letter-c')];

    testWidgets('on the Explorers map: a new milestone is celebrated once, then the badge just counts', (t) async {
      final c = await map(t, 'explorers', threeDays);
      expect(t.widget<Text>(find.byKey(const Key('active-days-text'))).data, '3 days! Hooray!');
      expect(c.read(celebratedDaysProvider)['c1'], 3);
    });

    testWidgets('a milestone already celebrated is not celebrated again', (t) async {
      await map(t, 'explorers', threeDays, extra: {'activeDays.v1': '{"c1":3}'});
      expect(t.widget<Text>(find.byKey(const Key('active-days-text'))).data, '3 days');
    });

    testWidgets('the Little Learners map has no badge (it stays as it was)', (t) async {
      await map(t, 'little-learners', threeDays);
      expect(find.byKey(const Key('active-days')), findsNothing);
    });
  });

  group('hand demo', () {
    Future<(List<String>, ValueNotifier<bool>)> demo(WidgetTester t) async {
      final taps = <String>[];
      final running = ValueNotifier(true);
      final a = GlobalKey(), b = GlobalKey(), c = GlobalKey();
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: running,
            builder: (context, r, _) => HandDemo(
              running: r,
              steps: [DemoStep.tap(a), DemoStep.drag(b, c)],
              onDone: () => running.value = false,
              child: Column(children: [
                ElevatedButton(key: a, onPressed: () => taps.add('a'), child: const Text('A')),
                ElevatedButton(key: b, onPressed: () => taps.add('b'), child: const Text('B')),
                SizedBox(key: c, width: 80, height: 80),
              ]),
            ),
          ),
        ),
      ));
      await t.pump();
      return (taps, running);
    }

    testWidgets('the hand shows each move once, then hands over to the child; it never answers for them', (t) async {
      final (taps, running) = await demo(t);
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('demo-hand')), findsOneWidget);
      await t.pumpAndSettle();
      expect(running.value, isFalse);
      expect(find.byKey(const Key('demo-hand')), findsNothing);
      expect(taps, isEmpty); // the demo pressed nothing
      await t.tap(find.text('A'));
      expect(taps, ['a']); // now the child plays
    });

    testWidgets('a tap anywhere skips it, and that tap does not reach the game', (t) async {
      final (taps, running) = await demo(t);
      await t.pump(const Duration(milliseconds: 200));
      await t.tap(find.byKey(const Key('hand-demo')));
      await t.pump();
      expect(running.value, isFalse);
      expect(taps, isEmpty);
    });

    test('each child sees the demo of each game once by itself', () async {
      final overrides = await testOverrides();
      final c = ProviderContainer(overrides: overrides);
      addTearDown(c.dispose);
      final seen = c.read(demoSeenProvider.notifier);
      expect(seen.seen('c1', 'sound-tap'), isFalse);
      await seen.markSeen('c1', 'sound-tap');
      expect(seen.seen('c1', 'sound-tap'), isTrue);
      expect(seen.seen('c2', 'sound-tap'), isFalse);
      expect(seen.seen('c1', 'word-builder'), isFalse);
    });
  });
}
