import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/core/widgets.dart';
import 'package:kids_english_app/features/activities/activity_logic.dart';
import 'package:kids_english_app/features/activities/hand_demo.dart';
import 'package:kids_english_app/features/activities/phonics_activities.dart';
import 'package:kids_english_app/features/audio/audio_service.dart';
import 'package:kids_english_app/features/content/content_models.dart';
import 'package:kids_english_app/features/profiles/child_profile.dart';

import 'helpers.dart';

/// A short-a lesson with real pictures from the app's assets (cat, hat) and sun for contrast.
Lesson _lesson() => Lesson.fromJson({
      'id': 'sound-builders-a',
      'order': 1,
      'level': 'a1',
      'audio': {
        'intro': 'audio/x/intro.mp3',
        'praise': ['audio/x/p.mp3'],
        'instructions': {'sound-tap': 'audio/x/instr_sound_tap.mp3', 'word-builder': 'audio/x/instr_word_builder.mp3', 'read-and-pick': 'audio/x/instr_read.mp3'},
      },
      'words': [
        {'word': 'cat', 'audio': 'audio/x/word_cat.mp3', 'image': 'images/little_learners/letter_c/cat.webp', 'graphemes': ['c', 'a', 't']},
        {'word': 'hat', 'audio': 'audio/x/word_hat.mp3', 'image': 'images/little_learners/letter_h/hat.svg', 'graphemes': ['h', 'a', 't']},
        {'word': 'sun', 'audio': 'audio/x/word_sun.mp3', 'image': 'images/little_learners/letter_s/sun.svg', 'graphemes': ['s', 'u', 'n']},
      ],
      'activities': ['sound-tap', 'word-builder', 'read-and-pick'],
    });

TrackContent _track() => TrackContent.fromJson({
      'schemaVersion': 2,
      'track': 'explorers',
      'units': [
        {'id': 'sound-builders', 'order': 2, 'title': {'en': 'Sound Builders', 'ar': 'x'}, 'icon': 'sounds', 'color': 'blue', 'lessons': []},
      ],
      'phonemes': {for (final g in ['c', 'a', 't', 'h', 's', 'u', 'n']) g: 'audio/explorers/phonemes/phoneme_$g.mp3'},
    });

const _child = '[{"id":"c1","name":"Lina","avatarKey":"star","birthYear":2019,"birthMonth":2,"track":"explorers","createdAt":"2026-01-01T00:00:00Z"}]';

/// Pumps one game. [seen] = the child already saw its demo (so it starts straight away).
Future<(FakeAudio, List<ActivityResult>, ProviderContainer)> _game(WidgetTester t, Widget Function(ValueChanged<ActivityResult>) build, {String? seen}) async {
  t.view.physicalSize = const Size(1080, 2400);
  t.view.devicePixelRatio = 1080 / 411;
  addTearDown(t.view.reset);
  final audio = FakeAudio();
  final results = <ActivityResult>[];
  final overrides = await testOverrides(prefs: {
    'children.v1': _child,
    if (seen != null) 'demos.v1': '{"c1":["$seen"]}',
  });
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

/// A magic-e lesson: "cake" is c, a (saying its name), k, and a silent e; "ship" starts with one sound for two letters.
Lesson _magic() => Lesson.fromJson({
      'id': 'magic-e-a',
      'order': 1,
      'level': 'a1',
      'audio': {'intro': 'audio/x/intro.mp3', 'praise': ['audio/x/p.mp3'], 'instructions': {'sound-tap': 'audio/x/i1.mp3', 'word-builder': 'audio/x/i2.mp3'}},
      'words': [
        {'word': 'cake', 'audio': 'audio/x/word_cake.mp3', 'image': 'images/little_learners/letter_c/cat.webp', 'graphemes': ['c', 'a:ay', 'k', 'e:-']},
        {'word': 'ship', 'audio': 'audio/x/word_ship.mp3', 'image': 'images/little_learners/letter_h/hat.svg', 'graphemes': ['sh', 'i', 'p']},
        {'word': 'cat', 'audio': 'audio/x/word_cat.mp3', 'image': 'images/little_learners/letter_c/cat.webp', 'graphemes': ['c', 'a', 't']},
      ],
      'activities': ['sound-tap', 'word-builder'],
    });

TrackContent _magicTrack() => TrackContent.fromJson({
      'schemaVersion': 2,
      'track': 'explorers',
      'units': [],
      'phonemes': {for (final g in ['c', 'a', 'ay', 'k', 'sh', 'i', 'p', 't']) g: 'audio/explorers/phonemes/phoneme_$g.mp3'},
    });

void main() {
  test('a grapheme is its letters, and the sound they make (none for a silent letter)', () {
    expect(graphemeText('sh'), 'sh');
    expect(graphemeSound('sh'), 'sh');
    expect(graphemeText('a:ay'), 'a');
    expect(graphemeSound('a:ay'), 'ay');
    expect(graphemeText('e:-'), 'e');
    expect(graphemeSound('e:-'), isNull);
  });

  group('magic e and digraphs', () {
    testWidgets('Sound Tap: "a" in cake says its name, the magic e says nothing and looks quieter; "sh" is one box', (t) async {
      final (audio, _, _) = await _game(t, (done) => SoundTapActivity(lesson: _magic(), track: _magicTrack(), onFinished: done), seen: 'sound-tap');
      expect([for (var i = 0; i < 4; i++) t.widget<GraphemeTile>(find.descendant(of: find.byKey(Key('sound-box-$i')), matching: find.byType(GraphemeTile))).text], ['c', 'a', 'k', 'e']);
      expect(t.widget<GraphemeTile>(find.descendant(of: find.byKey(const Key('sound-box-3')), matching: find.byType(GraphemeTile))).silent, isTrue);
      audio.played.clear();
      await _tap(t, 'sound-box-1');
      expect(audio.played, ['asset:audio/explorers/phonemes/phoneme_ay.mp3']);
      await _tap(t, 'sound-box-3');
      expect(audio.played.length, 1); // silent
      await _tap(t, 'sound-box-0');
      await _tap(t, 'sound-box-2');
      await t.pump(const Duration(seconds: 3));
      await t.pumpAndSettle();
      expect(audio.played.last, 'asset:audio/x/word_cake.mp3'); // all four heard (the silent one too): the word is read
      expect(find.byKey(const Key('sound-box-3')), findsNothing); // ship: three boxes
      expect(t.widget<GraphemeTile>(find.descendant(of: find.byKey(const Key('sound-box-0')), matching: find.byType(GraphemeTile))).text, 'sh');
      await _tap(t, 'sound-box-0');
      expect(audio.played.last, 'asset:audio/explorers/phonemes/phoneme_sh.mp3');
    });

    test('Word Builder never offers a second tile that looks like one of the word\'s (no short "a" next to the long one)', () {
      for (var seed = 0; seed < 20; seed++) {
        final tiles = builderTiles(_magic().words[0], _magic(), Random(seed));
        expect(tiles.map(graphemeText).toSet().length, tiles.length);
        expect(tiles, containsAll(['c', 'a:ay', 'k', 'e:-']));
      }
    });

    testWidgets('Word Builder: the "a" tile builds cake and says /ay/ there', (t) async {
      final (audio, results, _) = await _game(t, (done) => WordBuilderActivity(lesson: _magic(), track: _magicTrack(), onFinished: done, random: Random(4)), seen: 'word-builder');
      final tiles = [for (var i = 0; i < 6; i++) if (find.byKey(Key('builder-tile-$i')).evaluate().isNotEmpty) t.widget<GraphemeTile>(find.descendant(of: find.byKey(Key('builder-tile-$i')), matching: find.byType(GraphemeTile))).text];
      audio.played.clear();
      for (final g in ['c', 'a', 'k', 'e']) {
        await _tap(t, 'builder-tile-${tiles.indexOf(g)}');
      }
      expect(audio.played, containsAllInOrder(['asset:audio/explorers/phonemes/phoneme_c.mp3', 'asset:audio/explorers/phonemes/phoneme_ay.mp3', 'asset:audio/explorers/phonemes/phoneme_k.mp3']));
      expect(audio.played.where((p) => p.contains('phoneme_e')), isEmpty);
      await t.pump(const Duration(seconds: 2));
      await t.pumpAndSettle();
      expect(audio.played, contains('asset:audio/x/word_cake.mp3'));
      expect(results, isEmpty);
    });
  });

  group('Sound Tap', () {
    testWidgets('each box says its sound; when all are heard, the word is read and the next word comes; always three stars', (t) async {
      final (audio, results, _) = await _game(t, (done) => SoundTapActivity(lesson: _lesson(), track: _track(), onFinished: done), seen: 'sound-tap');
      expect(audio.played.first, 'asset:audio/x/instr_sound_tap.mp3'); // Dandoona says what to do
      audio.played.clear();
      await _tap(t, 'sound-box-0');
      expect(audio.played, ['asset:audio/explorers/phonemes/phoneme_c.mp3']);
      await _tap(t, 'sound-box-1');
      await _tap(t, 'sound-box-2');
      await t.pump(const Duration(seconds: 3));
      await t.pumpAndSettle();
      expect(audio.played, containsAllInOrder(['asset:audio/explorers/phonemes/phoneme_a.mp3', 'asset:audio/explorers/phonemes/phoneme_t.mp3', 'asset:audio/x/word_cat.mp3']));
      for (final w in [1, 2]) {
        for (var i = 0; i < 3; i++) {
          await _tap(t, 'sound-box-$i');
        }
        await t.pump(const Duration(seconds: 3));
        await t.pumpAndSettle();
        if (w < 2) expect(results, isEmpty);
      }
      expect(results.single.stars, 3);
    });

    testWidgets('the first time, the hand shows it while Dandoona explains; then the child plays, and the demo is remembered', (t) async {
      final (audio, results, c) = await _game(t, (done) => SoundTapActivity(lesson: _lesson(), track: _track(), onFinished: done));
      expect(find.byKey(const Key('demo-hand')), findsNothing); // done after settling
      expect(audio.played.first, 'asset:audio/x/instr_sound_tap.mp3');
      expect(c.read(demoSeenProvider.notifier).seen('c1', 'sound-tap'), isTrue);
      expect(audio.played.where((p) => p.contains('phoneme')), isEmpty); // the demo pressed nothing
      await t.tap(find.byKey(const Key('demo-help'))); // "?" shows it again
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('demo-hand')), findsOneWidget);
      await t.pumpAndSettle();
    });
  });

  group('Read & Pick without articles', () {
    testWidgets('numbers, days and times are shown without "a" or "an" (a lesson with noArticle)', (t) async {
      final base = _lesson();
      final lesson = Lesson(id: base.id, order: 1, level: 'a1', audio: base.audio, words: base.words, activities: base.activities, noArticle: true);
      await _game(t, (done) => ReadAndPickActivity(lesson: lesson, onFinished: done, random: Random(2)), seen: 'read-and-pick');
      expect(find.byKey(const Key('read-word')), findsOneWidget);
      expect(find.byKey(const Key('read-article')), findsNothing);
    });
  });

  group('Spell It', () {
    testWidgets('the same game with the picture hidden: only the word is heard; the picture shows when the word is built', (t) async {
      final (audio, results, _) = await _game(t, (done) => WordBuilderActivity(lesson: _lesson(), track: _track(), onFinished: done, random: Random(3), spell: true), seen: 'spell-it');
      expect(audio.played, contains('asset:audio/x/word_cat.mp3'));
      expect(find.byKey(const Key('spell-hidden')), findsOneWidget);
      expect(find.byType(AssetPicture), findsNothing);
      final word = _lesson().words.firstWhere((w) => 'asset:${w.audio}' == audio.played.last);
      final tiles = [for (var i = 0; i < 5; i++) t.widget<GraphemeTile>(find.descendant(of: find.byKey(Key('builder-tile-$i')), matching: find.byType(GraphemeTile))).text];
      for (final g in word.word.split('')) {
        await _tap(t, 'builder-tile-${tiles.indexOf(g)}');
      }
      await t.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const Key('spell-hidden')), findsNothing); // built: the picture is shown
      expect(find.byType(AssetPicture), findsOneWidget);
      await t.pump(const Duration(seconds: 2));
      await t.pumpAndSettle();
      expect(results, isEmpty); // two more words
    });

    testWidgets('the demo of Spell It is its own (seen once per child, by its own name)', (t) async {
      final (_, _, c) = await _game(t, (done) => WordBuilderActivity(lesson: _lesson(), track: _track(), onFinished: done, random: Random(3), spell: true));
      expect(find.byType(HandDemo), findsOneWidget);
      expect(c.read(profilesProvider), isNotEmpty);
    });
  });

  group('Word Builder', () {
    testWidgets('the tiles are the word\'s sounds plus up to two from other words of the lesson', (t) async {
      final tiles = builderTiles(_lesson().words[0], _lesson(), Random(1));
      expect(tiles, containsAll(['c', 'a', 't']));
      expect(tiles.length, 5);
    });

    testWidgets('tap the tiles in order to build the word; a wrong tile shakes and costs a star, the word is said when built', (t) async {
      final (audio, results, _) = await _game(t, (done) => WordBuilderActivity(lesson: _lesson(), track: _track(), onFinished: done, random: Random(3)), seen: 'word-builder');
      expect(audio.played, contains('asset:audio/x/word_cat.mp3')); // the word is heard first
      Future<void> build(String word, {bool oneWrong = false}) async {
        final tiles = [for (var i = 0; i < 5; i++) t.widget<GraphemeTile>(find.descendant(of: find.byKey(Key('builder-tile-$i')), matching: find.byType(GraphemeTile))).text];
        if (oneWrong) {
          final wrong = tiles.indexWhere((g) => g != word[0]);
          await _tap(t, 'builder-tile-$wrong');
        }
        for (final g in word.split('')) {
          await _tap(t, 'builder-tile-${tiles.indexOf(g)}');
        }
        await t.pump(const Duration(seconds: 2));
        await t.pumpAndSettle();
      }

      audio.played.clear();
      await build('cat', oneWrong: true);
      expect(audio.played, containsAllInOrder(['asset:audio/explorers/phonemes/phoneme_c.mp3', 'asset:audio/x/word_cat.mp3']));
      await build('hat');
      await build('sun');
      expect(results.single.stars, 2); // one wrong tile
      expect(results.single.attempts, 4);
    });

    testWidgets('a tile can also be dragged into its slot', (t) async {
      final (audio, _, _) = await _game(t, (done) => WordBuilderActivity(lesson: _lesson(), track: _track(), onFinished: done, random: Random(3)), seen: 'word-builder');
      final tiles = [for (var i = 0; i < 5; i++) t.widget<GraphemeTile>(find.descendant(of: find.byKey(Key('builder-tile-$i')), matching: find.byType(GraphemeTile))).text];
      final c = find.byKey(Key('builder-tile-${tiles.indexOf('c')}'));
      await t.drag(c, t.getCenter(find.byKey(const Key('builder-slot-0'))) - t.getCenter(c));
      await t.pumpAndSettle();
      expect(audio.played, contains('asset:audio/explorers/phonemes/phoneme_c.mp3'));
      expect(t.widget<GraphemeTile>(find.descendant(of: find.byKey(const Key('builder-slot-0')), matching: find.byType(GraphemeTile))).text, 'c');
    });
  });

  group('Read & Pick: a/an and plurals', () {
    Lesson plural() => Lesson.fromJson({
          'id': 'sound-builders-a',
          'order': 1,
          'level': 'a1',
          'audio': {'intro': 'audio/x/intro.mp3', 'praise': ['audio/x/p.mp3'], 'instructions': {'read-and-pick': 'audio/x/instr_read.mp3'}},
          'words': [
            {'word': 'cat', 'audio': 'audio/x/word_cat.mp3', 'image': 'images/little_learners/letter_c/cat.webp', 'graphemes': ['c', 'a', 't'], 'plural': 'cats', 'pluralAudio': 'audio/x/plural_cat.mp3'},
            {'word': 'ant', 'audio': 'audio/x/word_ant.mp3', 'image': 'images/little_learners/letter_h/hat.svg', 'graphemes': ['a', 'n', 't']},
            {'word': 'sun', 'audio': 'audio/x/word_sun.mp3', 'image': 'images/little_learners/letter_s/sun.svg', 'graphemes': ['s', 'u', 'n']},
          ],
          'activities': ['read-and-pick'],
        });

    test('"an" before a word that starts with a vowel sound, "a" otherwise; the u in cube says "you", so "a cube"', () {
      LessonWord w(String word, List<String> g) => LessonWord(word: word, audio: '', image: '', graphemes: g);
      expect(articleFor(w('ant', ['a', 'n', 't'])), 'an');
      expect(articleFor(w('egg', ['e', 'gg:g'])), 'an');
      expect(articleFor(w('cat', ['c', 'a', 't'])), 'a');
      expect(articleFor(w('cube', ['c', 'u:ue', 'b', 'e:-'])), 'a');
    });

    test('after every word once, each plural is asked: two of the picture, one of it, and two of another', () {
      final rounds = buildReadRounds(plural(), Random(1));
      expect(rounds.length, 4);
      expect(rounds.take(3).every((r) => !r.plural), isTrue);
      final last = rounds.last;
      expect(last.plural, isTrue);
      expect(last.target.word, 'cats');
      expect(last.options.map((o) => (o.source.word, o.two)), containsAll([('cat', true), ('cat', false)]));
      expect(last.options.where((o) => o.two && o.source.word != 'cat').length, 1);
    });

    testWidgets('the plural round: no "a", two cats is right and says "One cat. Two cats!"; one cat says "cat"', (t) async {
      final (audio, results, _) = await _game(t, (done) => ReadAndPickActivity(lesson: plural(), onFinished: done, random: Random(1)), seen: 'read-and-pick');
      for (var r = 0; r < 3; r++) {
        final word = t.widget<Text>(find.byKey(const Key('read-word'))).data!;
        expect(t.widget<Text>(find.byKey(const Key('read-article'))).data, word == 'ant' ? 'an' : 'a');
        await _tap(t, 'read-$word');
        await t.pump(const Duration(seconds: 2));
        await t.pumpAndSettle();
      }
      expect(t.widget<Text>(find.byKey(const Key('read-word'))).data, 'cats');
      expect(find.byKey(const Key('read-article')), findsNothing);
      await _tap(t, 'read-cat');
      expect(audio.played.last, 'asset:audio/x/word_cat.mp3');
      await t.pump(const Duration(seconds: 1));
      await _tap(t, 'read-cats');
      expect(audio.played.last, 'asset:audio/x/plural_cat.mp3');
      await t.pump(const Duration(seconds: 2));
      await t.pumpAndSettle();
      expect(results.single.stars, 2);
    });
  });

  group('Read & Pick', () {
    testWidgets('the word is shown with no sound; its picture is the answer, and only then the word is heard', (t) async {
      final (audio, results, _) = await _game(t, (done) => ReadAndPickActivity(lesson: _lesson(), onFinished: done, random: Random(2)), seen: 'read-and-pick');
      expect(audio.played, ['asset:audio/x/instr_read.mp3']); // nothing reads the word aloud
      for (var r = 0; r < 3; r++) {
        final word = t.widget<Text>(find.byKey(const Key('read-word'))).data!;
        if (r == 0) {
          final other = ['cat', 'hat', 'sun'].firstWhere((w) => w != word);
          await _tap(t, 'read-$other'); // a wrong picture says its own word
          expect(audio.played.last, 'asset:audio/x/word_$other.mp3');
          await t.pump(const Duration(seconds: 1));
        }
        await _tap(t, 'read-$word');
        expect(audio.played.last, 'asset:audio/x/word_$word.mp3');
        await t.pump(const Duration(seconds: 2));
        await t.pumpAndSettle();
      }
      expect(results.single.stars, 2);
    });

    testWidgets('after its demo, the word the demo answered is asked last', (t) async {
      final (_, _, _) = await _game(t, (done) => ReadAndPickActivity(lesson: _lesson(), onFinished: done, random: Random(2)));
      final rounds = buildReadRounds(_lesson(), Random(2));
      expect(t.widget<Text>(find.byKey(const Key('read-word'))).data, isNot(rounds.first.target.word));
    });

    test('every word is asked once, with two other pictures of the lesson', () {
      final rounds = buildReadRounds(_lesson(), Random(5));
      expect(rounds.map((r) => r.target.word).toSet(), {'cat', 'hat', 'sun'});
      for (final r in rounds) {
        expect(r.options.length, 3);
        expect(r.options.map((o) => o.word), contains(r.target.word));
      }
    });
  });
}
