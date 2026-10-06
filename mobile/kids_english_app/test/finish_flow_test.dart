import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/app.dart';
import 'package:kids_english_app/features/activities/listen_and_tap_activity.dart';
import 'package:kids_english_app/features/audio/audio_service.dart';
import 'package:kids_english_app/features/content/content_models.dart';

import 'helpers.dart';

/// A player whose praise clips keep "playing" until released, to see what the app does while a praise line is heard.
class _PraiseHeldAudio extends FakeAudio {
  _PraiseHeldAudio(this.praise);
  final Set<String> praise;
  final Completer<void> release = Completer<void>();

  @override
  Future<void> playAsset(String assetPath) async {
    played.add('asset:$assetPath');
    if (praise.contains(assetPath)) await release.future;
  }
}

void main() {
  final content = realContent();
  final lessonA = content.lessonById('letter-a')!;

  LessonWord targetOf(FakeAudio audio) {
    final last = audio.played.lastWhere((p) => lessonA.words.any((w) => 'asset:${w.audio}' == p));
    return lessonA.words.firstWhere((w) => 'asset:${w.audio}' == last);
  }

  testWidgets('the praise is heard to the end before the next picture appears', (t) async {
    final audio = _PraiseHeldAudio(lessonA.audio.praise.toSet());
    final overrides = await testOverrides(content: content);
    await t.pumpWidget(ProviderScope(
      overrides: [...overrides, audioServiceProvider.overrideWithValue(audio), recorderServiceProvider.overrideWithValue(FakeRecorder())],
      child: MaterialApp(home: Scaffold(body: ListenAndTapActivity(lesson: lessonA, track: content, random: Random(1), onFinished: (_) {}))),
    ));
    await t.pump();

    final first = targetOf(audio);
    await t.tap(find.byKey(Key('option-${first.word}')));
    await t.pump(const Duration(seconds: 3)); // far longer than the delay between pictures
    final praised = audio.played.where((p) => lessonA.audio.praise.any((s) => p == 'asset:$s')).length;
    expect(praised, 1);
    expect(audio.played.last, startsWith('asset:audio/little_learners/letter_a/praise_')); // the next word did not cut it off
    expect(find.byKey(const Key('hear-again')), findsOneWidget);

    audio.release.complete(); // the praise ends
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(audio.played.last, isNot(startsWith('asset:audio/little_learners/letter_a/praise_'))); // now the next word plays
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('after the last picture only the result screen praises, and OK goes to the letter map', (t) async {
    final audio = FakeAudio();
    final overrides = await testOverrides(content: content, prefs: {
      'settings.v1': '{"languageCode":"ar","sessionMinutes":15,"unlockAll":false,"onboarded":true}',
      'children.v1': '[{"id":"c1","name":"Omar","avatarKey":"star","birthYear":2022,"track":"little-learners","createdAt":"2026-01-01T00:00:00Z"}]',
    });
    await t.pumpWidget(ProviderScope(
      overrides: [...overrides, audioServiceProvider.overrideWithValue(audio), recorderServiceProvider.overrideWithValue(FakeRecorder())],
      child: const KidsEnglishApp(),
    ));
    await t.pumpAndSettle();
    await t.tap(find.text('Omar'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('unit-letters')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('node-letter-a')));
    await t.pumpAndSettle();
    await t.ensureVisible(find.byKey(const Key('activity-listen-and-tap')));
    await t.tap(find.byKey(const Key('activity-listen-and-tap')));
    await t.pump();

    for (var i = 0; i < lessonA.words.length; i++) {
      await t.tap(find.byKey(Key('option-${targetOf(audio).word}')));
      await t.pump(const Duration(seconds: 1));
    }
    await t.pump(const Duration(seconds: 2));
    expect(find.byKey(const Key('result-done')), findsOneWidget);

    // 2 praise lines for the first two pictures + 1 from the result screen (not a 4th on top of it)
    final praised = audio.played.where((p) => lessonA.audio.praise.any((s) => p == 'asset:$s')).length;
    expect(praised, 3);

    await t.tap(find.byKey(const Key('result-done')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('node-letter-a')), findsOneWidget); // back on the roadmap, to pick the next letter
    expect(find.byKey(const Key('lesson-letter')), findsNothing);
  });
}
