import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/features/activities/activity_logic.dart';
import 'package:kids_english_app/features/activities/habitat_activity.dart';
import 'package:kids_english_app/features/activities/listen_and_tap_activity.dart';
import 'package:kids_english_app/features/audio/audio_service.dart';
import 'package:kids_english_app/features/content/content_models.dart';

import 'helpers.dart';
import 'pack_helpers.dart';

void main() {
  final lessons = packLessons('animals');
    // The widget tests use pictures that are bundled in the app (the pack pictures are downloaded files): one different one per animal.
  final bundled = [for (final w in realContent().lessons.expand((l) => l.words)) w.image].toSet().toList();
  var n = 0;
  final shown = [
    for (final l in packManifest('animals')['lessons'] as List<dynamic>)
      Lesson.fromJson({
        ...(l as Map<String, dynamic>),
        'words': [for (final w in l['words'] as List<dynamic>) {...(w as Map<String, dynamic>), 'image': bundled[n++]}],
      }),
  ];
  final words = lessons.expand((l) => l.words).toList();
  final shownUnit = CourseUnit(id: 'animals', order: 5, title: const {'en': 'Animals'}, icon: 'animals', color: 'teal', lessons: shown);
  final content = TrackContent(track: 'little-learners', units: [...sampleContent().units, shownUnit]);

  group('the data of the Animals pack', () {
    test('every animal has a home and the sentence said when it gets there; the animals that make a sound have it as a file of the pack', () {
      final files = packFiles('animals');
      for (final w in words) {
        expect(const ['house', 'farm', 'water', 'wild'], contains(w.home), reason: w.word);
        expect(files, contains(w.lives), reason: '${w.word} lives');
        if (w.sound != null) expect(files, contains(w.sound), reason: '${w.word} sound');
      }
      expect(words.where((w) => w.sound == null).map((w) => w.word), ['rabbit', 'zebra']); // they are quiet animals
      expect(words.firstWhere((w) => w.word == 'cow').home, 'farm');
      expect(words.firstWhere((w) => w.word == 'fish').home, 'water');
      expect(words.firstWhere((w) => w.word == 'lion').home, 'wild');
      expect(words.firstWhere((w) => w.word == 'cat').home, 'house');
    });

    test('every lesson offers both new activities and says how to play them', () {
      for (final l in lessons) {
        expect(l.activities, containsAll(['animal-sounds', 'habitat']), reason: l.id);
        expect(l.audio.instructions.keys, containsAll(['animal-sounds', 'habitat']), reason: l.id);
        expect(packFiles('animals'), containsAll([l.audio.instructions['animal-sounds'], l.audio.instructions['habitat']]));
      }
    });
  });

  group('sound rounds', () {
    test('only animals that make a sound are asked; the choices are other animals; no two animals share a sound', () {
      final pictures = shown.expand((l) => l.words).map((w) => w.image).toSet();
      expect(words.where((w) => w.sound != null).map((w) => w.sound).toSet().length, words.where((w) => w.sound != null).length);
      for (var seed = 0; seed < 20; seed++) {
        for (final l in shown) {
          final rounds = buildSoundRounds(l, content, Random(seed));
          expect(rounds.map((r) => r.target.word).toSet(), {for (final w in l.words) if (w.sound != null) w.word}, reason: l.id);
          for (final r in rounds) {
            expect(r.options.length, 3);
            expect(r.options.where((o) => o.word == r.target.word).length, 1);
            for (final o in r.options) {
              expect(pictures, contains(o.image));
            }
          }
        }
      }
    });
  });

  group('the activities', () {
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

    testWidgets('animal sounds: the instruction and then the sound are played (not the name); the right animal finishes with 3 stars; a wrong one costs a star', (t) async {
      final lesson = shown.first; // cat, dog, rabbit
      ActivityResult? result;
      final audio = await pump(t, ListenAndTapActivity(lesson: lesson, track: content, sounds: true, random: Random(2), onFinished: (r) => result = r, nextDelay: const Duration(milliseconds: 50)));
      final bySound = {for (final w in lesson.words) if (w.sound != null) 'asset:${w.sound}': w};
      expect(audio.played.first, 'asset:${lesson.audio.instructions['animal-sounds']}');
      expect(bySound, contains(audio.played.last));
      expect(lesson.words.map((w) => 'asset:${w.audio}'), isNot(contains(audio.played.last)));

      // two rounds (cat and dog; the rabbit is quiet): first one right
      var target = bySound[audio.played.last]!;
      await t.tap(find.byKey(Key('option-${target.word}')));
      await t.pump(const Duration(seconds: 2));
      await t.pump(const Duration(seconds: 2));
      expect(result, isNull); // one more round
      target = bySound[audio.played.lastWhere(bySound.containsKey)]!;
      await t.tap(find.byKey(Key('option-${target.word}')));
      await t.pump(const Duration(seconds: 2));
      expect(result, isNotNull);
      expect(result!.stars, 3);
      expect(result!.attempts, 2);
    });

    testWidgets('habitat: an animal in a wrong home is shaken off (a star less); in its home it says where it lives; all animals done finishes', (t) async {
      final lesson = shown[1]; // cow, pig, horse: all on the farm
      ActivityResult? result;
      final audio = await pump(t, HabitatActivity(lesson: lesson, random: Random(1), onFinished: (r) => result = r, nextDelay: const Duration(milliseconds: 50)));
      expect(audio.played.first, 'asset:${lesson.audio.instructions['habitat']}');

      await t.tap(find.byKey(const Key('home-water'))); // wrong
      await t.pump(const Duration(milliseconds: 700));
      expect(result, isNull);
      for (var i = 0; i < lesson.words.length; i++) {
        audio.played.clear();
        await t.tap(find.byKey(const Key('home-farm')));
        await t.pump(const Duration(seconds: 1));
        expect(audio.played.where((p) => lesson.words.any((w) => p == 'asset:${w.lives}')), hasLength(1)); // "A cow lives on the farm."
        await t.pump(const Duration(seconds: 1));
      }
      expect(result, isNotNull);
      expect(result!.stars, 2); // one mistake
      expect(result!.attempts, lesson.words.length + 1);
    });

    testWidgets('habitat: each home is big enough to press and there are four of them', (t) async {
      await pump(t, HabitatActivity(lesson: shown.first, onFinished: (_) {}));
      for (final h in habitatHomes) {
        final size = t.getSize(find.byKey(Key('home-${h.key}')));
        expect(size.width, greaterThanOrEqualTo(64));
        expect(size.height, greaterThanOrEqualTo(64));
      }
      expect(habitatHomes.length, 4);
    });
  });
}
