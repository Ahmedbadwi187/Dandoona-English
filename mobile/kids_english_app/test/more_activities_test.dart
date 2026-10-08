import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/features/activities/activity_logic.dart';
import 'package:kids_english_app/features/activities/activity_widgets.dart';
import 'package:kids_english_app/features/activities/build_picture_activity.dart';
import 'package:kids_english_app/features/activities/count_along_activity.dart';
import 'package:kids_english_app/features/activities/listen_and_tap_activity.dart';
import 'package:kids_english_app/features/activities/memory_activity.dart';
import 'package:kids_english_app/features/activities/mix_colors_activity.dart';
import 'package:kids_english_app/features/activities/odd_one_out_activity.dart';
import 'package:kids_english_app/features/activities/sort_activity.dart';
import 'package:kids_english_app/features/activities/story_feeling_activity.dart';
import 'package:kids_english_app/features/activities/trace_activity.dart';
import 'package:kids_english_app/features/activities/turns_activity.dart';
import 'package:kids_english_app/core/widgets.dart';
import 'package:kids_english_app/features/audio/audio_service.dart';
import 'package:kids_english_app/features/content/content_models.dart';

import 'helpers.dart';
import 'pack_content.dart';

void main() {
  final content = contentWithPacks();
  Lesson lesson(String id) => content.lessonById(id)!;

  group('the data of the extra games', () {
    test('numbers: counting and tracing; colors that mix; shapes that build; feelings in the story', () {
      for (final id in ['number-1-3', 'number-4-6', 'number-7-10']) {
        expect(lesson(id).activities, containsAll(['count-along', 'trace', 'memory']), reason: id);
      }
      for (final c in colorRecipes.keys) {
        expect(lesson('color-$c').activities, contains('mix-colors'), reason: c);
        expect(colorRecipes[c]!.every((x) => colorLesson(content, x) != null), isTrue, reason: '$c is mixed of colors the Colors unit has');
      }
      for (final id in buildRecipes.keys) {
        expect(lesson(id).activities, contains('build-picture'));
        final words = lesson(id).words.map((w) => w.word).toSet();
        expect(buildRecipes[id]!.every((p) => words.contains(p.word)), isTrue, reason: '$id: every piece is a shape of the lesson');
      }
      expect(lesson('feelings-2').activities, contains('story-feeling'));
    });

    test('sorting lessons: every bin has words, every word of a bin is in a bin of its lesson, and the icons are known', () {
      for (final id in ['my-body-2', 'food-4', 'clothes-3', 'transport-3', 'my-home-3', 'my-family-3']) {
        final l = lesson(id);
        expect(l.activities, contains('sort'), reason: id);
        final unitWords = unitWordsOf(content, l);
        for (final b in l.bins) {
          expect(unitWords.where((w) => w.group == b.key), isNotEmpty, reason: '$id/${b.key}');
          expect(binIcon(b.icon), isNot(Icons.star_rounded), reason: '$id/${b.icon} has an icon');
        }
        for (final w in unitWords.where((w) => w.group != null)) {
          expect(l.bins.map((b) => b.key), contains(w.group), reason: '$id/${w.word}');
        }
      }
    });

    test('odd one out: the odd words are bundled Letters pictures and none of them belongs to the theme', () {
      final letterWords = content.unitById('letters')!.lessons.expand((l) => l.words).map((w) => w.word).toSet();
      var checked = 0;
      for (final u in content.units) {
        for (final l in u.lessons.where((l) => l.odd.isNotEmpty)) {
          checked++;
          expect(l.odd.length, greaterThanOrEqualTo(3));
          for (final o in l.odd) {
            expect(letterWords, contains(o), reason: '${l.id}: $o');
            expect(unitWordsOf(content, l).map((w) => w.word), isNot(contains(o)), reason: '${l.id}: $o is not a word of the unit');
          }
        }
      }
      expect(checked, 8);
    });

    test('sentences: every phrase has its text and audio, and the gap replaces the word or its plural', () {
      final l = lesson('food-4');
      for (final w in l.words) {
        expect(w.phrase, isNotNull);
        expect(w.phraseText, isNotNull);
      }
      expect(sentenceWithGap(l.words.first), 'I like ____.'); // pizza
      expect(sentenceWithGap(lesson('food-1').words.first), 'I like ____.'); // apples
      expect(sentenceWithGap(lesson('number-1-3').words.first), '____ balloon.'); // One balloon.
      expect(sentenceWithGap(const LessonWord(word: 'cat', audio: 'a', image: 'i', phraseText: 'Nothing here.')), isNull);
    });

    test('opposites: every word has its opposite in the unit, and they are opposites of each other', () {
      final words = unitWordsOf(content, lesson('opposites-1'));
      for (final w in words) {
        final other = words.firstWhere((x) => x.word == w.opposite);
        expect(other.opposite, w.word);
      }
    });
  });

  group('rounds', () {
    test('sorting takes words of every bin and at most five', () {
      for (var seed = 0; seed < 20; seed++) {
        final l = lesson('transport-3');
        final picked = pickSortWords(l, content, Random(seed));
        expect(picked.length, 5);
        expect(picked.map((w) => w.group).toSet(), {'road', 'water', 'sky'});
        expect(picked.map((w) => w.word).toSet().length, picked.length);
      }
    });

    test('memory: each word twice, or each word with its opposite', () {
      final plain = buildMemoryCards(lesson('animals-1'), content, Random(1));
      expect(plain.length, 6);
      for (final p in plain.map((c) => c.pair).toSet()) {
        expect(plain.where((c) => c.pair == p).length, 2);
      }
      final opp = buildMemoryCards(lesson('opposites-1'), content, Random(1));
      expect(opp.length, 6);
      for (final p in opp.map((c) => c.pair).toSet()) {
        final two = opp.where((c) => c.pair == p).toList();
        expect(two.length, 2);
        expect(two[0].word.opposite, two[1].word.word);
      }
    });

    test('odd one out: three of the unit and one else; the odd one is never one of the three', () {
      for (var seed = 0; seed < 20; seed++) {
        final rounds = buildOddRounds(lesson('animals-2'), content, Random(seed));
        expect(rounds.length, 3);
        for (final r in rounds) {
          expect(r.options.length, 4);
          expect(r.group.map((w) => w.image), isNot(contains(r.odd.image)));
        }
      }
    });

    test('feelings: the rounds are the story pages about one feeling, with the feeling among three faces', () {
      final rounds = buildFeelingRounds(lesson('feelings-2'), content, Random(1));
      expect(rounds, isNotEmpty);
      for (final r in rounds) {
        expect(r.options.length, 3);
        expect(r.options.map((w) => w.word), contains(r.answer.word));
        expect(r.page.words, [r.answer.word]);
      }
    });
  });

  group('the games', () {
    Future<FakeAudio> pump(WidgetTester t, Widget child) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 1080 / 411;
      addTearDown(t.view.reset);
      final audio = FakeAudio();
      final overrides = await testOverrides(content: content);
      await t.pumpWidget(ProviderScope(overrides: [...overrides, audioServiceProvider.overrideWithValue(audio)], child: MaterialApp(home: Scaffold(body: child))));
      await t.pump();
      await t.pump();
      return audio;
    }

    testWidgets('count along: touching the balloons says one, two, three; every number is counted; three stars', (t) async {
      final l = lesson('number-1-3');
      ActivityResult? result;
      final audio = await pump(t, CountAlongActivity(lesson: l, track: content, onFinished: (r) => result = r, nextDelay: const Duration(milliseconds: 20)));
      final audioOf = {for (final w in l.words) w.word: 'asset:${w.audio}'};
      for (var n = 1; n <= 3; n++) {
        expect(find.byKey(Key('balloon-${n - 1}')), findsOneWidget);
        expect(find.byKey(Key('balloon-$n')), findsNothing, reason: 'round $n shows $n balloons');
        for (var i = 0; i < n; i++) {
          await t.tap(find.byKey(Key('balloon-$i')));
          await t.pump();
        }
        expect(t.widget<Text>(find.descendant(of: find.byKey(const Key('count-number')), matching: find.byType(Text))).data, '$n');
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(result?.stars, 3);
      final said = audio.played.where(audioOf.containsValue).toList();
      expect(said, [audioOf['one'], audioOf['one'], audioOf['two'], audioOf['one'], audioOf['two'], audioOf['three']]);
    });

    testWidgets('tracing numbers: a counting lesson traces its numerals, the first said by its word', (t) async {
      final l = lesson('number-1-3');
      final audio = await pump(t, TraceActivity(lesson: l, onFinished: (_) {}));
      expect(audio.played, ['asset:${l.audio.instructions['trace']}', 'asset:${l.words.first.audio}']); // how to, then the first number
      expect(find.byKey(const Key('trace-board')), findsOneWidget);
    });

    testWidgets('sort: the right bin says the word and moves on; a wrong bin costs a star; the last gives the stars', (t) async {
      final l = lesson('clothes-3');
      ActivityResult? result;
      await pump(t, SortActivity(lesson: l, track: content, random: Random(2), onFinished: (r) => result = r, nextDelay: const Duration(milliseconds: 20)));
      var first = true;
      for (var i = 0; i < 5; i++) {
        final shown = t.widget<AssetPicture>(find.descendant(of: find.byKey(const Key('sort-picture')), matching: find.byType(AssetPicture))).assetPath;
        final word = unitWordsOf(content, l).firstWhere((w) => w.image == shown && w.group != null);
        if (first) {
          final wrongBin = l.bins.firstWhere((b) => b.key != word.group);
          await t.tap(find.byKey(Key('bin-${wrongBin.key}')));
          await t.pump(const Duration(milliseconds: 700));
          first = false;
        }
        await t.tap(find.byKey(Key('bin-${word.group}')));
        await t.pump(const Duration(milliseconds: 100));
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(result?.stars, 2);
      expect(result?.attempts, 6);
    });

    testWidgets('sort: dragging the picture onto its bin works too', (t) async {
      final l = lesson('transport-3');
      ActivityResult? result;
      await pump(t, SortActivity(lesson: l, track: content, random: Random(3), onFinished: (r) => result = r, nextDelay: const Duration(milliseconds: 20)));
      final shown = t.widget<AssetPicture>(find.descendant(of: find.byKey(const Key('sort-picture')), matching: find.byType(AssetPicture))).assetPath;
      final word = unitWordsOf(content, l).firstWhere((w) => w.image == shown && w.group != null);
      await t.drag(find.byKey(const Key('sort-picture')), t.getCenter(find.byKey(Key('bin-${word.group}'))) - t.getCenter(find.byKey(const Key('sort-picture'))));
      await t.pump(const Duration(milliseconds: 200));
      await t.pump(const Duration(milliseconds: 200));
      final now = t.widget<AssetPicture>(find.descendant(of: find.byKey(const Key('sort-picture')), matching: find.byType(AssetPicture))).assetPath;
      expect(now, isNot(shown), reason: 'the next picture came');
      expect(result, isNull);
    });

    testWidgets('memory: pairs stay open, others close again; finishing with few turns gives three stars', (t) async {
      final l = lesson('animals-1');
      ActivityResult? result;
      final audio = await pump(t, MemoryActivity(lesson: l, track: content, random: Random(4), onFinished: (r) => result = r, closeAfter: const Duration(milliseconds: 20)));
      final cards = buildMemoryCards(l, content, Random(4)); // the same order
      for (final pair in cards.map((c) => c.pair).toSet()) {
        final idx = [for (final (i, c) in cards.indexed) if (c.pair == pair) i];
        await t.tap(find.byKey(Key('card-${idx[0]}')));
        await t.pump();
        await t.tap(find.byKey(Key('card-${idx[1]}')));
        await t.pump(const Duration(milliseconds: 700));
      }
      await t.pump(const Duration(seconds: 1));
      expect(result?.stars, 3);
      expect(audio.played.length, 7); // how to play, then each card said its word
    });

    testWidgets('memory: opposite words are the pair, a wrong pair closes again and counts', (t) async {
      final l = lesson('opposites-1');
      ActivityResult? result;
      await pump(t, MemoryActivity(lesson: l, track: content, random: Random(5), onFinished: (r) => result = r, closeAfter: const Duration(milliseconds: 20)));
      final cards = buildMemoryCards(l, content, Random(5));
      // a wrong pair first: two cards of different pairs
      final other = cards.indexWhere((c) => c.pair != cards.first.pair);
      await t.tap(find.byKey(const Key('card-0')));
      await t.pump();
      await t.tap(find.byKey(Key('card-$other')));
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(milliseconds: 100));
      for (final pair in cards.map((c) => c.pair).toSet()) {
        final idx = [for (final (i, c) in cards.indexed) if (c.pair == pair) i];
        await t.tap(find.byKey(Key('card-${idx[0]}')));
        await t.pump();
        await t.tap(find.byKey(Key('card-${idx[1]}')));
        await t.pump(const Duration(milliseconds: 700));
      }
      await t.pump(const Duration(seconds: 1));
      expect(result, isNotNull);
      expect(result!.attempts, 4); // one wrong pair + three right ones
      expect(result!.stars, 2);
    });

    testWidgets('odd one out: the odd picture ends the round, a wrong one costs a star, every tap says the word', (t) async {
      final l = lesson('animals-2');
      ActivityResult? result;
      final audio = await pump(t, OddOneOutActivity(lesson: l, track: content, random: Random(6), onFinished: (r) => result = r, nextDelay: const Duration(milliseconds: 20)));
      final rounds = buildOddRounds(l, content, Random(6));
      for (var i = 0; i < rounds.length; i++) {
        if (i == 0) {
          await t.tap(find.byKey(Key('odd-${rounds[0].group.first.word}')));
          await t.pump(const Duration(milliseconds: 700));
        }
        await t.tap(find.byKey(Key('odd-${rounds[i].odd.word}')));
        await t.pump(const Duration(milliseconds: 100));
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(result?.stars, 2);
      expect(audio.played.length, rounds.length + 2); // how to play, every tap says its word
    });

    testWidgets('sentences: the sentence is said with a gap on the screen and the picture fills it', (t) async {
      final l = lesson('food-4');
      ActivityResult? result;
      final audio = await pump(t, ListenAndTapActivity(lesson: l, track: content, sentences: true, random: Random(7), onFinished: (r) => result = r, nextDelay: const Duration(milliseconds: 20)));
      for (var i = 0; i < l.words.length; i++) {
        expect(find.byKey(const Key('sentence-text')), findsOneWidget);
        expect(t.widget<Text>(find.byKey(const Key('sentence-text'))).data, contains('____'));
        final said = l.words.firstWhere((w) => 'asset:${w.phrase}' == audio.played.last);
        await t.tap(find.byKey(Key('option-${said.word}')));
        await t.pump(const Duration(seconds: 1));
        await t.pump(const Duration(seconds: 1));
      }
      expect(result?.stars, 3);
    });

    testWidgets('mix colors: two colors, choose what they make; the color is said; two mixes make three stars', (t) async {
      final l = lesson('color-orange');
      ActivityResult? result;
      final audio = await pump(t, MixColorsActivity(lesson: l, track: content, random: Random(8), onFinished: (r) => result = r, nextDelay: const Duration(milliseconds: 20)));
      expect(find.byKey(const Key('mix-option-orange')), findsOneWidget);
      await t.tap(find.byKey(const Key('mix-option-orange')));
      await t.pump(const Duration(milliseconds: 100));
      expect(audio.played, ['asset:${l.audio.instructions['mix-colors']}', 'asset:${l.audio.colorName}']);
      await t.pump(const Duration(milliseconds: 100));
      expect(result, isNull); // a second mix
      final second = (colorRecipes.keys.where((k) => k != 'orange').toList()..shuffle(Random(8))).first;
      await t.tap(find.byKey(Key('mix-option-$second')));
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(milliseconds: 100));
      expect(result?.stars, 3);
    });

    testWidgets('build a picture: any shape goes to its own place; all placed finishes with three stars', (t) async {
      final l = lesson('shapes-1');
      ActivityResult? result;
      await pump(t, BuildPictureActivity(lesson: l, random: Random(9), onFinished: (r) => result = r));
      expect(find.byKey(const Key('slot-0')), findsOneWidget);
      for (final p in buildRecipes['shapes-1']!.reversed) {
        await t.tap(find.byKey(Key('piece-${p.word}')));
        await t.pump();
      }
      await t.pump(const Duration(seconds: 1));
      expect(result?.stars, 3);
    });

    testWidgets('turns: Dandoona takes a toy, then the child, four toys in all', (t) async {
      final l = lesson('toys-3');
      ActivityResult? result;
      await pump(t, TurnsActivity(lesson: l, track: content, random: Random(10), onFinished: (r) => result = r, dandoonaDelay: const Duration(milliseconds: 100)));
      for (var turn = 0; turn < 2; turn++) {
        expect(t.widget<Text>(find.descendant(of: find.byKey(const Key('turn-badge')), matching: find.byType(Text))).data, 'My turn!');
        await t.pump(const Duration(milliseconds: 200));
        expect(t.widget<Text>(find.descendant(of: find.byKey(const Key('turn-badge')), matching: find.byType(Text))).data, 'Your turn!');
        final free = unitWordsOf(content, l).where((w) => find.byKey(Key('toy-${w.word}')).evaluate().isNotEmpty && t.widget<Opacity>(find.descendant(of: find.byKey(Key('toy-${w.word}')), matching: find.byType(Opacity)).first).opacity == 1).first;
        await t.tap(find.byKey(Key('toy-${free.word}')));
        await t.pump(const Duration(milliseconds: 750));
      }
      await t.pump(const Duration(milliseconds: 850));
      expect(result?.stars, 3);
    });

    testWidgets('how does Dandoona feel: the story page is read, the right face finishes; a wrong face reads it again', (t) async {
      final l = lesson('feelings-2');
      ActivityResult? result;
      final audio = await pump(t, StoryFeelingActivity(lesson: l, track: content, random: Random(11), onFinished: (r) => result = r, nextDelay: const Duration(milliseconds: 20)));
      final rounds = buildFeelingRounds(l, content, Random(11));
      expect(audio.played.last, 'asset:${rounds.first.page.audio}');
      for (var i = 0; i < rounds.length; i++) {
        if (i == 0) {
          final wrong = rounds[0].options.firstWhere((w) => w.word != rounds[0].answer.word);
          await t.tap(find.byKey(Key('feeling-${wrong.word}')));
          await t.pump(const Duration(milliseconds: 700));
          expect(audio.played.last, 'asset:${rounds.first.page.audio}');
        }
        await t.tap(find.byKey(Key('feeling-${rounds[i].answer.word}')));
        await t.pump(const Duration(milliseconds: 100));
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(result?.stars, 2);
    });
  });
}
