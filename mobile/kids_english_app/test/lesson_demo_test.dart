import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/features/activities/hand_demo.dart';
import 'package:kids_english_app/features/audio/audio_service.dart';
import 'package:kids_english_app/features/child/lesson_screen.dart';
import 'package:kids_english_app/features/profiles/child_profile.dart';

import 'helpers.dart';

const _child = '[{"id":"c1","name":"Lina","avatarKey":"star","birthYear":2022,"track":"little-learners","createdAt":"2026-01-01T00:00:00Z"}]';

Future<(FakeAudio, ProviderContainer)> _open(WidgetTester t, {bool autoDemo = true}) async {
  t.view.physicalSize = const Size(1080, 2400);
  t.view.devicePixelRatio = 1080 / 411;
  addTearDown(t.view.reset);
  final audio = FakeAudio();
  final overrides = await testOverrides(content: realContent(), autoDemo: autoDemo, prefs: {'children.v1': _child});
  final c = ProviderContainer(overrides: [...overrides, audioServiceProvider.overrideWithValue(audio)]);
  addTearDown(c.dispose);
  c.read(activeChildIdProvider.notifier).select('c1');
  await t.pumpWidget(UncontrolledProviderScope(container: c, child: const MaterialApp(home: LessonScreen(lessonId: 'letter-a'))));
  await t.pump();
  return (audio, c);
}

/// Opening a lesson: Dandoona says the intro, then a slow hand points at the capital, the small letter and each picture, and says each name.
void main() {
  testWidgets('after the intro the hand visits the letter and every picture in turn, saying each name, and "?" plays it again', (t) async {
    final (audio, _) = await _open(t);
    final lesson = realContent().lessonById('letter-a')!;
    await t.pump(const Duration(milliseconds: 200));
    expect(t.widget<HandDemo>(find.byType(HandDemo)).running, isTrue);
    expect(t.widget<HandDemo>(find.byType(HandDemo)).slow, isTrue);
    expect(find.byKey(const Key('demo-help')), findsOneWidget);

    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 700));
    }
    final said = audio.played.map((p) => p.replaceFirst('asset:', '')).toList();
    // the intro first, then the words in the order of the pictures
    expect(said.first, lesson.audio.intro);
    final wordClips = [for (final w in lesson.words) w.audio];
    final positions = [for (final c in wordClips) said.indexOf(c)];
    expect(positions.every((p) => p > 0), isTrue, reason: 'every word is said: $said');
    expect(positions, [...positions]..sort(), reason: 'in the order of the pictures');
    expect(t.widget<HandDemo>(find.byType(HandDemo)).running, isFalse);

    final before = audio.played.length;
    await t.tap(find.byKey(const Key('demo-help')));
    await t.pump();
    expect(t.widget<HandDemo>(find.byType(HandDemo)).running, isTrue);
    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 700));
    }
    expect(audio.played.length, greaterThan(before));
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('a tap skips it', (t) async {
    await _open(t);
    await t.pump(const Duration(milliseconds: 200));
    await t.tap(find.byKey(const Key('hand-demo')));
    await t.pump();
    expect(t.widget<HandDemo>(find.byType(HandDemo)).running, isFalse);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('with the demo off (tests about something else) nothing plays by itself', (t) async {
    await _open(t, autoDemo: false);
    await t.pump(const Duration(milliseconds: 200));
    expect(t.widget<HandDemo>(find.byType(HandDemo)).running, isFalse);
  });
}
