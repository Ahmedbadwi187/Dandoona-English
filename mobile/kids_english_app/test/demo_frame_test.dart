import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/features/activities/demo_steps.dart';
import 'package:kids_english_app/features/activities/hand_demo.dart';
import 'package:kids_english_app/features/activities/listen_and_tap_activity.dart';
import 'package:kids_english_app/features/audio/audio_service.dart';

import 'helpers.dart';

/// Practice and Review host the Listen & Tap game inside a DemoFrame: the hand has to find the speaker and a picture there too.
void main() {
  testWidgets('the hand plays over the game hosted by Practice and Review, and "?" plays it again', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 1080 / 411;
    addTearDown(t.view.reset);
    final track = realContent();
    final lesson = track.lessons.firstWhere((l) => l.activities.contains('listen-and-tap') && l.words.length >= 3);
    final overrides = await testOverrides(content: track, autoDemo: true);
    final c = ProviderContainer(overrides: [...overrides, audioServiceProvider.overrideWithValue(FakeAudio())]);
    addTearDown(c.dispose);
    await t.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        home: Scaffold(
          body: DemoFrame(
            activity: 'listen-and-tap',
            instruction: null,
            child: ListenAndTapActivity(lesson: lesson, track: track, onFinished: (_) {}, random: Random(1)),
          ),
        ),
      ),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 700));
    expect(t.widget<HandDemo>(find.byType(HandDemo)).running, isTrue);
    expect(find.byKey(const Key('demo-hand')), findsOneWidget, reason: 'the hand found the speaker and a picture');
    await t.pump(const Duration(seconds: 6));
    expect(t.widget<HandDemo>(find.byType(HandDemo)).running, isFalse);
    await t.tap(find.byKey(const Key('demo-help')));
    await t.pump();
    expect(t.widget<HandDemo>(find.byType(HandDemo)).running, isTrue);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  });
}
