import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/features/activities/activity_screen.dart';
import 'package:kids_english_app/features/activities/demo_steps.dart';
import 'package:kids_english_app/features/activities/hand_demo.dart';
import 'package:kids_english_app/features/audio/audio_service.dart';
import 'package:kids_english_app/features/content/content_models.dart';
import 'package:kids_english_app/features/profiles/child_profile.dart';

import 'helpers.dart';
import 'pack_content.dart';

String _child(String track) => '[{"id":"c1","name":"Lina","avatarKey":"star","birthYear":2019,"birthMonth":2,"track":"$track","createdAt":"2026-01-01T00:00:00Z"}]';

/// Every game that does not bring its own demo shows the hand when it opens, and has the "?" to show it again.
void main() {
  final ll = contentWithPacks();
  final ex = realExplorersContent();
  final activities = {for (final t in [ll, ex]) for (final l in t.lessons) for (final a in l.activities) a}.where(hasHostedDemo).toList()..sort();

  test('the list of games with a hosted demo covers every game of both tracks that has no demo of its own', () {
    final all = {for (final t in [ll, ex]) for (final l in t.lessons) ...l.activities};
    expect(all.difference(ownDemoActivities).difference(activities.toSet()), isEmpty);
  });

  for (final a in activities) {
    testWidgets('$a: the hand plays when it opens, a tap skips it, and "?" plays it again', (t) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 1080 / 411;
      addTearDown(t.view.reset);
      final inLl = ll.lessons.any((l) => l.activities.contains(a));
      final track = inLl ? ll : ex;
      final Lesson lesson = track.lessons.firstWhere((l) => l.activities.contains(a));
      final overrides = await testOverrides(content: ll, explorers: ex, autoDemo: true, prefs: {'children.v1': _child(inLl ? 'little-learners' : 'explorers')});
      final c = ProviderContainer(overrides: [...overrides, audioServiceProvider.overrideWithValue(FakeAudio()), recorderServiceProvider.overrideWithValue(FakeRecorder())]);
      addTearDown(c.dispose);
      c.read(activeChildIdProvider.notifier).select('c1');
      await t.pumpWidget(UncontrolledProviderScope(container: c, child: MaterialApp(home: ActivityScreen(lessonId: lesson.id, activity: a))));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));

      expect(t.widget<HandDemo>(find.byType(HandDemo)).running, isTrue, reason: a);
      expect(find.byKey(const Key('demo-hand')), findsOneWidget, reason: 'the hand found its pieces in $a');
      expect(find.byKey(const Key('demo-help')), findsOneWidget);

      await t.tap(find.byKey(const Key('hand-demo')));
      await t.pump();
      expect(t.widget<HandDemo>(find.byType(HandDemo)).running, isFalse);

      await t.tap(find.byKey(const Key('demo-help')));
      await t.pump();
      expect(t.widget<HandDemo>(find.byType(HandDemo)).running, isTrue);
      await t.pumpWidget(const SizedBox()); // the hand's animation stops with the screen
      await t.pump(const Duration(seconds: 5)); // and a game's own waiting timers run out
    });
  }
}
