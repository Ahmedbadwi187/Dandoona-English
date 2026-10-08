import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/features/activities/activity_logic.dart';
import 'package:kids_english_app/features/activities/hand_demo.dart';
import 'package:kids_english_app/features/activities/reading_games.dart';
import 'package:kids_english_app/features/audio/audio_service.dart';
import 'package:kids_english_app/features/content/content_models.dart';
import 'package:kids_english_app/features/profiles/child_profile.dart';

import 'helpers.dart';

Lesson _lesson() => Lesson.fromJson({
      'id': 'my-sentences-1',
      'order': 1,
      'level': 'a1',
      'audio': {
        'intro': 'audio/x/intro.mp3',
        'praise': ['audio/x/p.mp3'],
        'instructions': {'true-or-false': 'audio/x/i_tf.mp3', 'sight-word-hunt': 'audio/x/i_hunt.mp3'},
      },
      'words': [
        {'word': 'cat', 'audio': 'audio/x/word_cat.mp3', 'image': 'images/little_learners/letter_c/cat.webp'},
        {'word': 'sun', 'audio': 'audio/x/word_sun.mp3', 'image': 'images/little_learners/letter_s/sun.svg'},
      ],
      'sightWords': [
        {'word': 'the', 'audio': 'audio/x/sight_the.mp3'},
        {'word': 'is', 'audio': 'audio/x/sight_is.mp3'},
        {'word': 'are', 'audio': 'audio/x/sight_are.mp3'},
        {'word': 'see', 'audio': 'audio/x/sight_see.mp3'},
      ],
      'sentences': [
        {'text': 'The cat is big.', 'audio': 'audio/x/s1.mp3', 'image': 'images/little_learners/letter_c/cat.webp', 'gap': 'is', 'choices': ['is', 'are']},
        {'text': 'The cats are big.', 'audio': 'audio/x/s2.mp3', 'image': 'images/little_learners/letter_c/cat.webp', 'two': true, 'gap': 'are', 'choices': ['is', 'are']},
        {'text': 'I see the sun.', 'audio': 'audio/x/s3.mp3', 'image': 'images/little_learners/letter_s/sun.svg'},
        {'text': 'I see the cat.', 'audio': 'audio/x/s4.mp3', 'image': 'images/little_learners/letter_c/cat.webp'},
      ],
      'activities': ['true-or-false', 'sight-word-hunt'],
    });

const _child = '[{"id":"c1","name":"Lina","avatarKey":"star","birthYear":2019,"birthMonth":2,"track":"explorers","createdAt":"2026-01-01T00:00:00Z"}]';

Future<(FakeAudio, List<ActivityResult>)> _game(WidgetTester t, Widget Function(ValueChanged<ActivityResult>) build, {String? seen}) async {
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
  return (audio, results);
}

void main() {
  group('the rounds of True or False', () {
    test('half true, half false; a sentence about one or two is false with the wrong number, otherwise with another picture', () {
      for (var seed = 0; seed < 30; seed++) {
        final rounds = buildTrueFalseRounds(_lesson(), Random(seed));
        expect(rounds.length, 4);
        expect(rounds.where((r) => r.isTrue).length, 2);
        for (final r in rounds) {
          final s = r.sentence;
          if (r.isTrue) {
            expect(r.image, s.image);
            expect(r.two, s.two);
          } else if (s.tokens.any((t) => t == 'is' || t == 'are')) {
            expect(r.image, s.image, reason: s.text);
            expect(r.two, !s.two, reason: s.text); // "The cats are big." with one cat
          } else {
            expect(r.image, isNot(s.image), reason: s.text);
          }
        }
      }
    });
  });

  group('True or False', () {
    testWidgets('read the sentence, tap the check or the cross; a wrong tap costs a star; after the right one the sentence is read', (t) async {
      final (audio, results) = await _game(t, (done) => TrueOrFalseActivity(lesson: _lesson(), onFinished: done, random: Random(3), nextDelay: const Duration(milliseconds: 50)), seen: 'true-or-false');
      expect(audio.played.last, 'asset:audio/x/i_tf.mp3'); // only the instruction: the child reads
      final rounds = buildTrueFalseRounds(_lesson(), Random(3));
      for (final (i, r) in rounds.indexed) {
        expect(t.widget<Text>(find.byKey(const Key('tf-sentence'))).data, '${r.sentence.tokens.join(' ')}${r.sentence.mark}');
        if (i == 0) {
          await t.tap(find.byKey(Key(r.isTrue ? 'tf-no' : 'tf-yes'))); // wrong
          await t.pump(const Duration(milliseconds: 700));
        }
        await t.tap(find.byKey(Key(r.isTrue ? 'tf-yes' : 'tf-no')));
        await t.pump(const Duration(milliseconds: 100));
        expect(audio.played.last, 'asset:${r.sentence.audio}');
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(results.single.stars, 2);
      expect(results.single.attempts, rounds.length + 1);
    });

    testWidgets('its first time shows the hand demo', (t) async {
      await _game(t, (done) => TrueOrFalseActivity(lesson: _lesson(), onFinished: done, random: Random(3)));
      expect(find.byType(HandDemo), findsOneWidget);
    });
  });

  group('Sight Word Hunt', () {
    testWidgets('every sight word is hunted once: hear it, tap its bubble, it pops; a wrong bubble says its own word', (t) async {
      final (audio, results) = await _game(t, (done) => SightWordHuntActivity(lesson: _lesson(), onFinished: done, random: Random(2), drift: false, nextDelay: const Duration(milliseconds: 50)), seen: 'sight-word-hunt');
      final lesson = _lesson();
      String heard() => lesson.sightWords.firstWhere((w) => 'asset:${w.audio}' == audio.played.last).word;
      for (var i = 0; i < lesson.sightWords.length; i++) {
        final target = heard();
        if (i == 0) {
          final other = lesson.sightWords.firstWhere((w) => w.word != target);
          await t.tap(find.byKey(Key('hunt-${other.word}')));
          await t.pump(const Duration(milliseconds: 700));
          expect(audio.played.last, 'asset:${other.audio}');
        }
        await t.tap(find.byKey(Key('hunt-$target')));
        await t.pump(const Duration(milliseconds: 100));
        await t.pump(const Duration(milliseconds: 600));
      }
      expect(results.single.stars, 2);
      expect(results.single.attempts, lesson.sightWords.length + 1);
    });
  });
}
