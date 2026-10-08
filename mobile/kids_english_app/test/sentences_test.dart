import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/features/activities/activity_logic.dart';
import 'package:kids_english_app/features/activities/hand_demo.dart';
import 'package:kids_english_app/features/activities/phonics_activities.dart';
import 'package:kids_english_app/features/activities/sentence_activities.dart';
import 'package:kids_english_app/features/audio/audio_service.dart';
import 'package:kids_english_app/features/content/content_models.dart';
import 'package:kids_english_app/features/profiles/child_profile.dart';

import 'helpers.dart';

/// A My Sentences lesson: the cat (one and two) and the sun, three sight words.
Lesson _lesson() => Lesson.fromJson({
      'id': 'my-sentences-1',
      'order': 1,
      'level': 'a1',
      'audio': {
        'intro': 'audio/x/intro.mp3',
        'praise': ['audio/x/p.mp3'],
        'instructions': {'find-the-word': 'audio/x/i_find.mp3', 'sentence-builder': 'audio/x/i_build.mp3', 'fill-the-gap': 'audio/x/i_gap.mp3'},
      },
      'words': [
        {'word': 'cat', 'audio': 'audio/x/word_cat.mp3', 'image': 'images/little_learners/letter_c/cat.webp'},
        {'word': 'sun', 'audio': 'audio/x/word_sun.mp3', 'image': 'images/little_learners/letter_s/sun.svg'},
      ],
      'sightWords': [
        {'word': 'the', 'audio': 'audio/x/sight_the.mp3'},
        {'word': 'is', 'audio': 'audio/x/sight_is.mp3'},
        {'word': 'are', 'audio': 'audio/x/sight_are.mp3'},
      ],
      'sentences': [
        {'text': 'The cat is big.', 'audio': 'audio/x/s1.mp3', 'image': 'images/little_learners/letter_c/cat.webp', 'gap': 'is', 'choices': ['is', 'are']},
        {'text': 'The cats are big.', 'audio': 'audio/x/s2.mp3', 'image': 'images/little_learners/letter_c/cat.webp', 'two': true, 'gap': 'are', 'choices': ['is', 'are']},
        {'text': 'The sun is hot!', 'audio': 'audio/x/s3.mp3', 'image': 'images/little_learners/letter_s/sun.svg', 'gap': 'is', 'choices': ['is', 'are']},
      ],
      'activities': ['find-the-word', 'sentence-builder', 'fill-the-gap'],
    });

const _child = '[{"id":"c1","name":"Lina","avatarKey":"star","birthYear":2019,"birthMonth":2,"track":"explorers","createdAt":"2026-01-01T00:00:00Z"}]';

Future<(FakeAudio, List<ActivityResult>, ProviderContainer)> _game(WidgetTester t, Widget Function(ValueChanged<ActivityResult>) build, {String? seen}) async {
  t.view.physicalSize = const Size(1080, 2400);
  t.view.devicePixelRatio = 1080 / 411;
  addTearDown(t.view.reset);
  final audio = FakeAudio();
  final results = <ActivityResult>[];
  final overrides = await testOverrides(prefs: {'children.v1': _child, if (seen != null) 'demos.v1': '{"c1":["$seen"]}'});
  final c = ProviderContainer(overrides: [...overrides, audioServiceProvider.overrideWithValue(audio)]);
  addTearDown(c.dispose);
  c.read(activeChildIdProvider.notifier).select('c1');
  await t.pumpWidget(UncontrolledProviderScope(container: c, child: MaterialApp(home: Scaffold(body: build(results.add)))));
  await t.pumpAndSettle();
  return (audio, results, c);
}

Future<void> _tap(WidgetTester t, String key) async {
  await t.tap(find.byKey(Key(key)));
  await t.pumpAndSettle();
}

void main() {
  test('a sentence splits into its word cards and its closing mark', () {
    final s = _lesson().sentences[2];
    expect(s.tokens, ['The', 'sun', 'is', 'hot']);
    expect(s.mark, '!');
    expect(_lesson().sentences[1].two, isTrue);
    expect(_lesson().sightWords.map((w) => w.word), ['the', 'is', 'are']);
  });

  group('Find the Word', () {
    testWidgets('the word is said; the child taps it among three; a wrong card says its own word and costs a star', (t) async {
      final (audio, results, _) = await _game(t, (done) => FindTheWordActivity(lesson: _lesson(), onFinished: done, random: Random(1)), seen: 'find-the-word');
      final rounds = buildFindRounds(_lesson(), Random(1));
      expect(audio.played.last, 'asset:${rounds.first.target.audio}');
      for (final (i, r) in rounds.indexed) {
        if (i == 0) {
          final other = r.options.firstWhere((o) => o.word != r.target.word);
          await _tap(t, 'find-${other.word}');
          expect(audio.played.last, 'asset:${other.audio}');
          await t.pump(const Duration(seconds: 1));
        }
        await _tap(t, 'find-${r.target.word}');
        await t.pump(const Duration(seconds: 2));
        await t.pumpAndSettle();
      }
      expect(results.single.stars, 2);
      expect(results.single.attempts, 4);
    });

    testWidgets('the first time, the hand shows it and taps nothing', (t) async {
      final (audio, _, c) = await _game(t, (done) => FindTheWordActivity(lesson: _lesson(), onFinished: done, random: Random(1)));
      expect(audio.played.first, 'asset:audio/x/i_find.mp3');
      expect(c.read(demoSeenProvider.notifier).seen('c1', 'find-the-word'), isTrue);
    });
  });

  group('Sentence Builder', () {
    testWidgets('the sentence is heard; the cards go in order, a wrong card shakes; the built sentence is read with its mark', (t) async {
      final (audio, results, _) = await _game(t, (done) => SentenceBuilderActivity(lesson: _lesson(), onFinished: done, random: Random(2)), seen: 'sentence-builder');
      expect(audio.played, contains('asset:audio/x/s1.mp3'));
      Future<void> build(List<String> words, {bool oneWrong = false}) async {
        final tiles = [
          for (var i = 0; i < 8; i++)
            if (find.byKey(Key('sentence-tile-$i')).evaluate().isNotEmpty) (i, t.widget<WordCard>(find.descendant(of: find.byKey(Key('sentence-tile-$i')), matching: find.byType(WordCard))).text),
        ];
        if (oneWrong) await _tap(t, 'sentence-tile-${tiles.firstWhere((x) => x.$2 != words[0]).$1}');
        final used = <int>{};
        for (final (n, w) in words.indexed) {
          final i = tiles.firstWhere((x) => x.$2 == w && !used.contains(x.$1)).$1;
          used.add(i);
          if (n < words.length - 1) {
            await _tap(t, 'sentence-tile-$i');
          } else {
            await t.tap(find.byKey(Key('sentence-tile-$i')));
            await t.pump(const Duration(milliseconds: 100));
            expect(find.byKey(const Key('sentence-mark')), findsOneWidget); // built: the mark comes
          }
        }
      }

      await build(['The', 'cat', 'is', 'big'], oneWrong: true);
      audio.played.clear();
      await t.pump(const Duration(seconds: 2));
      await t.pumpAndSettle();
      expect(audio.played, ['asset:audio/x/s1.mp3', 'asset:audio/x/s2.mp3']); // the built one is read, then the next is heard
      expect(find.byType(ManyPicture), findsOneWidget);
      expect(t.widget<ManyPicture>(find.byType(ManyPicture)).two, isTrue); // two cats
      await build(['The', 'cats', 'are', 'big']);
      await t.pump(const Duration(seconds: 2));
      await t.pumpAndSettle();
      await build(['The', 'sun', 'is', 'hot']);
      await t.pump(const Duration(seconds: 2));
      await t.pumpAndSettle();
      expect(results.single.stars, 2);
    });
  });

  group('Fill the Gap', () {
    testWidgets('nothing is read first; the picture tells "is" or "are"; the right word fills the gap and the sentence is read', (t) async {
      final (audio, results, _) = await _game(t, (done) => FillTheGapActivity(lesson: _lesson(), onFinished: done, random: Random(3)), seen: 'fill-the-gap');
      expect(audio.played, ['asset:audio/x/i_gap.mp3']); // only the instruction: the child reads
      for (var r = 0; r < 3; r++) {
        final two = t.widget<ManyPicture>(find.byType(ManyPicture)).two;
        final right = two ? 'are' : 'is';
        if (r == 0) {
          await _tap(t, 'gap-choice-${two ? 'is' : 'are'}');
          expect(t.widget<WordCard>(find.byKey(const Key('gap-blank'))).text.trim(), isEmpty);
          await t.pump(const Duration(seconds: 1));
        }
        await _tap(t, 'gap-choice-$right');
        expect(t.widget<WordCard>(find.byKey(const Key('gap-blank'))).text, right);
        expect(audio.played.last, startsWith('asset:audio/x/s'));
        await t.pump(const Duration(seconds: 2));
        await t.pumpAndSettle();
      }
      expect(results.single.stars, 2);
    });
  });
}
