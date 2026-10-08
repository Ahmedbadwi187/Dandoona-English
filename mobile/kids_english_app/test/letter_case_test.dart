import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/app.dart';
import 'package:kids_english_app/features/audio/audio_service.dart';
import 'package:kids_english_app/router.dart';

import 'helpers.dart';

const _child = '[{"id":"c1","name":"Omar","avatarKey":"star","birthYear":2022,"track":"little-learners","createdAt":"2026-01-01T00:00:00Z"}]';
const _settings = '{"languageCode":"en","sessionMinutes":15,"unlockAll":false,"onboarded":true,"languageChosen":true}';

Future<(FakeAudio, ProviderContainer)> _open(WidgetTester t, String path) async {
  t.view.physicalSize = const Size(1080, 2400);
  t.view.devicePixelRatio = 1080 / 411;
  addTearDown(t.view.reset);
  final audio = FakeAudio();
  final overrides = await testOverrides(content: realContent(), prefs: {'settings.v1': _settings, 'children.v1': _child});
  final c = ProviderContainer(overrides: [...overrides, audioServiceProvider.overrideWithValue(audio), recorderServiceProvider.overrideWithValue(FakeRecorder())]);
  addTearDown(c.dispose);
  await t.pumpWidget(UncontrolledProviderScope(container: c, child: const KidsEnglishApp()));
  await t.pumpAndSettle();
  c.read(routerProvider).push(path);
  await t.pump();
  await t.pump(const Duration(milliseconds: 300));
  return (audio, c);
}

void main() {
  final content = realContent();
  final letters = content.unitById('letters')!.lessons;

  test('every letter lesson has the capital and small letter lines and the small letter to trace, and the audio files are in the app', () {
    expect(letters.length, 26);
    for (final l in letters) {
      expect(l.activities, contains('trace-small'), reason: l.id);
      expect(l.activities.indexOf('trace'), lessThan(l.activities.indexOf('trace-small')), reason: 'the capital first, then the small letter');
      for (final key in ['capital', 'small', 'trace-small']) {
        final path = l.audio.instructions[key];
        expect(path, isNotNull, reason: '${l.id}: $key');
        expect(File('assets/$path').existsSync(), isTrue, reason: '${l.id}: $path');
      }
    }
  });

  testWidgets('a letter lesson shows the capital and the small letter; each says which it is and then the sound', (t) async {
    final (audio, _) = await _open(t, '/lesson/letter-a');
    final a = content.lessonById('letter-a')!;
    expect(t.widget<Text>(find.byKey(const Key('lesson-letter'))).data, 'A');
    expect(t.widget<Text>(find.byKey(const Key('lesson-letter-small'))).data, 'a');
    expect(find.text('Capital'), findsOneWidget);
    expect(find.text('Small'), findsOneWidget);
    audio.played.clear();

    await t.tap(find.byKey(const Key('lesson-letter-tap')));
    await t.pump();
    expect(audio.played, ['asset:${a.audio.instructions['capital']}', 'asset:${a.audio.phoneme}']);
    audio.played.clear();
    await t.tap(find.byKey(const Key('lesson-letter-small-tap')));
    await t.pump();
    expect(audio.played, ['asset:${a.audio.instructions['small']}', 'asset:${a.audio.phoneme}']);
    // both are big enough for a small finger
    expect(t.getSize(find.byKey(const Key('lesson-letter-tap'))).width, greaterThanOrEqualTo(64));
    expect(t.getSize(find.byKey(const Key('lesson-letter-small-tap'))).width, greaterThanOrEqualTo(64));
  });

  testWidgets('the lesson offers tracing the small letter as its own activity, with its own instruction', (t) async {
    final (audio, _) = await _open(t, '/lesson/letter-b/trace-small');
    final b = content.lessonById('letter-b')!;
    expect(audio.played, contains('asset:${b.audio.instructions['trace-small']}'));
    expect(audio.played, isNot(contains('asset:${b.audio.instructions['trace']}')));
  });

  testWidgets('the capital letter is still traced as before', (t) async {
    final (audio, _) = await _open(t, '/lesson/letter-b/trace');
    final b = content.lessonById('letter-b')!;
    expect(audio.played, contains('asset:${b.audio.instructions['trace']}'));
  });

  test('lessons of the other units are not letters: no capital and small pair', () {
    expect(content.unitById('colors')!.lessons.every((l) => l.letter == null), isTrue);
  });
}
