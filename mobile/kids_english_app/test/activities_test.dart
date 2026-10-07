import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/app.dart';
import 'package:kids_english_app/features/activities/activity_logic.dart';
import 'package:kids_english_app/features/activities/activity_screen.dart';
import 'package:kids_english_app/features/activities/listen_and_tap_activity.dart';
import 'package:kids_english_app/features/activities/match_picture_activity.dart';
import 'package:kids_english_app/features/activities/record_listen_activity.dart';
import 'package:kids_english_app/features/audio/audio_service.dart';
import 'package:kids_english_app/features/content/content_models.dart';
import 'package:kids_english_app/features/profiles/child_profile.dart';
import 'package:kids_english_app/features/progress/progress.dart';

import 'helpers.dart';

void main() {
  final content = realContent();
  final lessonA = content.lessonById('letter-a')!;

  group('star rules', () {
    test('0 mistakes = 3 stars, 1-2 = 2 stars, more = 1 star (never 0 for finishing)', () {
      expect(starsForMistakes(0), 3);
      expect(starsForMistakes(1), 2);
      expect(starsForMistakes(2), 2);
      expect(starsForMistakes(3), 1);
      expect(starsForMistakes(30), 1);
    });
  });

  group('round building', () {
    test('every word is a target once, with distinct pictures and the target among 3 options', () {
      for (var seed = 0; seed < 50; seed++) {
        for (final lesson in content.lessons) {
          final rounds = buildChoiceRounds(lesson, content, Random(seed));
          expect(rounds.map((r) => r.target.word).toSet(), lesson.words.map((w) => w.word).toSet());
          for (final r in rounds) {
            expect(r.options, hasLength(3));
            expect(r.options.where((o) => o.word == r.target.word), hasLength(1));
            expect(r.options.map((o) => o.image).toSet(), hasLength(3), reason: '${lesson.id}/${r.target.word}');
          }
        }
      }
    });

    test('with a tiny track the lesson\'s own other words are used as distractors', () {
      final tiny = TrackContent(
          track: 't', units: [CourseUnit(id: 'u', order: 1, title: const {'en': 'U'}, icon: '', color: '', lessons: [lessonA])]);
      final rounds = buildChoiceRounds(lessonA, tiny, Random(1));
      expect(rounds.every((r) => r.options.length == 3), isTrue);
    });

    test('match pairs: same words in both columns, different order', () {
      for (var seed = 0; seed < 30; seed++) {
        final p = buildMatchPairs(lessonA, Random(seed));
        expect(p.pictures.map((w) => w.word).toSet(), p.sounds.map((w) => w.word).toSet());
        expect(p.pictures.map((w) => w.word).join(), isNot(p.sounds.map((w) => w.word).join()));
      }
    });
  });

  group('trace scoring', () {
    const cols = 20;
    List<bool> grid(bool Function(int x, int y) on) => [for (var y = 0; y < cols; y++) for (var x = 0; x < cols; x++) on(x, y)];
    final glyph = grid((x, y) => x >= 6 && x < 14 && y >= 4 && y < 16);

    test('perfect overlap = 3 stars', () {
      final s = scoreTrace(glyph: glyph, ink: glyph, cols: cols);
      expect(s.coverage, 1.0);
      expect(s.spill, 0.0);
      expect(s.stars, 3);
    });

    test('half covered = 2 stars; a quarter = 1; almost nothing = 0', () {
      expect(scoreTrace(glyph: glyph, ink: grid((x, y) => x >= 6 && x < 10 && y >= 4 && y < 16), cols: cols).stars, 2);
      expect(scoreTrace(glyph: glyph, ink: grid((x, y) => x >= 6 && x < 8 && y >= 4 && y < 16), cols: cols).stars, 1);
      expect(scoreTrace(glyph: glyph, ink: grid((x, y) => x == 6 && y == 4), cols: cols).stars, 0);
      expect(scoreTrace(glyph: glyph, ink: List.filled(cols * cols, false), cols: cols).stars, 0);
    });

    test('scribbling far outside the letter is penalised even if the letter is covered', () {
      final everything = List.filled(cols * cols, true);
      final s = scoreTrace(glyph: glyph, ink: everything, cols: cols);
      expect(s.coverage, 1.0);
      expect(s.spill, greaterThan(0.3));
      expect(s.stars, lessThan(3));
    });

    test('maskFromRgba turns visible pixels into on-cells', () {
      const w = 12, h = 12;
      final rgba = Uint8List(w * h * 4);
      for (var y = 0; y < 6; y++) {
        for (var x = 0; x < 6; x++) {
          rgba[(y * w + x) * 4 + 3] = 255; // top-left 6x6 block opaque
        }
      }
      final mask = maskFromRgba(rgba, w, h, cell: 6);
      expect(mask, [true, false, false, false]);
    });
  });

  group('activities (fake audio/recorder, real lessons)', () {
    Future<(FakeAudio, FakeRecorder)> pumpActivity(WidgetTester tester, Widget Function() build) async {
      final audio = FakeAudio();
      final recorder = FakeRecorder();
      final overrides = await testOverrides(content: content);
      await tester.pumpWidget(ProviderScope(
        overrides: [...overrides, audioServiceProvider.overrideWithValue(audio), recorderServiceProvider.overrideWithValue(recorder)],
        child: MaterialApp(home: Scaffold(body: build())),
      ));
      await tester.pump();
      return (audio, recorder);
    }

    LessonWord targetOf(FakeAudio audio) {
      final last = audio.played.lastWhere((p) => p.startsWith('asset:')).substring(6);
      return lessonA.words.firstWhere((w) => w.audio == last);
    }

    testWidgets('listen-and-tap: plays each word, all-correct taps give 3 stars', (tester) async {
      ActivityResult? result;
      final (audio, _) = await pumpActivity(
          tester, () => ListenAndTapActivity(lesson: lessonA, track: content, random: Random(3), onFinished: (r) => result = r));

      for (var i = 0; i < lessonA.words.length; i++) {
        final target = targetOf(audio);
        await tester.tap(find.byKey(Key('option-${target.word}')));
        await tester.pump(const Duration(seconds: 1));
      }
      expect(result, isNotNull);
      expect(result!.stars, 3);
      expect(result!.attempts, lessonA.words.length);
      expect(audio.played.where((p) => lessonA.audio.praise.any((s) => p == 'asset:$s')), isNotEmpty); // praise was played
    });

    testWidgets('listen-and-tap: a wrong tap replays the word, costs a star, and does not advance', (tester) async {
      ActivityResult? result;
      final (audio, _) = await pumpActivity(
          tester, () => ListenAndTapActivity(lesson: lessonA, track: content, random: Random(3), onFinished: (r) => result = r));

      final target = targetOf(audio);
      final playsBefore = audio.played.length;
      final wrong = tester.widgetList<GestureDetector>(find.byWidgetPredicate((w) => w.key is Key && '${w.key}'.contains('option-') && !'${w.key}'.contains('option-${target.word}'))).first;
      await tester.tap(find.byKey(wrong.key!));
      await tester.pump(const Duration(milliseconds: 700));
      expect(audio.played.length, greaterThan(playsBefore)); // word replayed
      expect(targetOf(audio).word, target.word); // still the same round

      for (var i = 0; i < lessonA.words.length; i++) {
        await tester.tap(find.byKey(Key('option-${targetOf(audio).word}')));
        await tester.pump(const Duration(seconds: 1));
      }
      expect(result!.stars, 2);
      expect(result!.attempts, lessonA.words.length + 1);
    });

    testWidgets('match-picture: wrong pairing costs a star, all matched finishes', (tester) async {
      ActivityResult? result;
      final (_, _) = await pumpActivity(tester, () => MatchPictureActivity(lesson: lessonA, random: Random(5), onFinished: (r) => result = r));

      final words = lessonA.words.map((w) => w.word).toList();
      // wrong first: sound of word 0 on picture of word 1
      await tester.tap(find.byKey(Key('sound-${words[0]}')));
      await tester.pump();
      await tester.tap(find.byKey(Key('image-${words[1]}')));
      await tester.pump(const Duration(milliseconds: 700));
      expect(result, isNull);

      for (final w in words) {
        await tester.tap(find.byKey(Key('sound-$w')));
        await tester.pump();
        await tester.tap(find.byKey(Key('image-$w')));
        await tester.pump();
      }
      await tester.pump(const Duration(seconds: 1));
      expect(result!.stars, 2);
    });

    testWidgets('record-and-listen: records, plays the original then the recording, deletes the file, finishes with 3 stars', (tester) async {
      ActivityResult? result;
      final (audio, recorder) = await pumpActivity(tester, () => RecordListenActivity(lesson: lessonA, onFinished: (r) => result = r));

      for (var i = 0; i < lessonA.words.length; i++) {
        await tester.tap(find.byKey(const Key('record-mic'))); // start
        await tester.pump();
        expect(recorder.started, i + 1);
        await tester.tap(find.byKey(const Key('record-mic'))); // stop -> compare
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(result!.stars, 3);
      expect(recorder.created, hasLength(lessonA.words.length));
      expect(recorder.deleted, recorder.created); // every recording deleted right after play-back
      // order inside one round: original word, then the child's own voice
      final firstFile = audio.played.indexWhere((p) => p.startsWith('file:'));
      expect(audio.played[firstFile - 1], startsWith('asset:'));
    });

    testWidgets('record-and-listen: microphone denied shows a skip button that gives 1 star and records nothing', (tester) async {
      ActivityResult? result;
      final audio = FakeAudio();
      final recorder = FakeRecorder()..permission = false;
      final overrides = await testOverrides(content: content);
      await tester.pumpWidget(ProviderScope(
        overrides: [...overrides, audioServiceProvider.overrideWithValue(audio), recorderServiceProvider.overrideWithValue(recorder)],
        child: MaterialApp(home: Scaffold(body: RecordListenActivity(lesson: lessonA, onFinished: (r) => result = r))),
      ));
      await tester.tap(find.byKey(const Key('record-mic')));
      await tester.pump();
      expect(find.byIcon(Icons.mic_off_rounded), findsOneWidget);
      await tester.tap(find.byKey(const Key('record-skip')));
      expect(result!.stars, 1);
      expect(recorder.started, 0);
    });

    testWidgets('record-and-listen: a recorder failure is handled the same way (no crash)', (tester) async {
      final audio = FakeAudio();
      final recorder = FakeRecorder()..failOnStart = true;
      final overrides = await testOverrides(content: content);
      await tester.pumpWidget(ProviderScope(
        overrides: [...overrides, audioServiceProvider.overrideWithValue(audio), recorderServiceProvider.overrideWithValue(recorder)],
        child: MaterialApp(home: Scaffold(body: RecordListenActivity(lesson: lessonA, onFinished: (_) {}))),
      ));
      await tester.tap(find.byKey(const Key('record-mic')));
      await tester.pump();
      expect(find.byKey(const Key('record-skip')), findsOneWidget);
    });
  });

  group('host: progress is saved and the stars screen is shown', () {
    testWidgets('finishing listen-and-tap records progress for the active child and shows 3 stars', (tester) async {
      final audio = FakeAudio();
      final overrides = await testOverrides(content: content);
      final container = containerWith([...overrides, audioServiceProvider.overrideWithValue(audio), recorderServiceProvider.overrideWithValue(FakeRecorder())]);
      addTearDown(container.dispose);
      final kid = await container.read(profilesProvider.notifier).add(name: 'Omar', avatarKey: 'star', birthYear: 2022);
      container.read(activeChildIdProvider.notifier).select(kid.id);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ActivityScreen(lessonId: 'letter-a', activity: 'listen-and-tap')),
      ));
      await tester.pump();

      for (var i = 0; i < lessonA.words.length; i++) {
        final last = audio.played.lastWhere((p) => p.startsWith('asset:')).substring(6);
        final target = lessonA.words.firstWhere((w) => w.audio == last);
        await tester.tap(find.byKey(Key('option-${target.word}')));
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump(const Duration(seconds: 2));

      final records = container.read(progressProvider);
      expect(records, hasLength(1));
      expect(records.single.childId, kid.id);
      expect(records.single.lessonId, 'letter-a');
      expect(records.single.activity, 'listen-and-tap');
      expect(records.single.stars, 3);
      expect(find.byKey(const Key('result-done')), findsOneWidget);
      expect(container.read(progressProvider.notifier).starsFor(kid.id, 'letter-a'), 3);
    });

    testWidgets('an unknown activity or lesson shows the error text instead of crashing', (tester) async {
      final overrides = await testOverrides(content: content);
      await tester.pumpWidget(ProviderScope(
        overrides: [...overrides, audioServiceProvider.overrideWithValue(FakeAudio())],
        child: const MaterialApp(home: ActivityScreen(lessonId: 'letter-a', activity: 'dance')),
      ));
      await tester.pump();
      expect(find.text("Couldn't load the lessons"), findsOneWidget);
    });
  });

  group('lesson screen opens the activities', () {
    testWidgets('tapping a tile from the real app opens that activity', (tester) async {
      final overrides = await testOverrides(content: content, prefs: {
        'settings.v1': '{"languageCode":"ar","sessionMinutes":15,"unlockAll":false,"onboarded":true}',
        'children.v1': '[{"id":"c1","name":"Omar","avatarKey":"star","birthYear":2022,"track":"little-learners","createdAt":"2026-01-01T00:00:00Z"}]',
      });
      await tester.pumpWidget(ProviderScope(
        overrides: [...overrides, audioServiceProvider.overrideWithValue(FakeAudio()), recorderServiceProvider.overrideWithValue(FakeRecorder())],
        child: const KidsEnglishApp(),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('unit-letters'))); // the home screen is the unit map
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('node-letter-a')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('lesson-letter')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('activity-listen-and-tap')));
      await tester.tap(find.byKey(const Key('activity-listen-and-tap')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('hear-again')), findsOneWidget);
    });

    testWidgets('tapping a word picture says the word, tapping the big letter says its sound', (tester) async {
      final audio = FakeAudio();
      final overrides = await testOverrides(content: content, prefs: {
        'settings.v1': '{"languageCode":"ar","sessionMinutes":15,"unlockAll":false,"onboarded":true}',
        'children.v1': '[{"id":"c1","name":"Omar","avatarKey":"star","birthYear":2022,"track":"little-learners","createdAt":"2026-01-01T00:00:00Z"}]',
      });
      await tester.pumpWidget(ProviderScope(
        overrides: [...overrides, audioServiceProvider.overrideWithValue(audio), recorderServiceProvider.overrideWithValue(FakeRecorder())],
        child: const KidsEnglishApp(),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('unit-letters'))); // the home screen is the unit map
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('node-letter-a')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('speaker-badge')), findsNWidgets(4)); // the letter and its 3 pictures show that they can be pressed
      expect(audio.played.last, 'asset:audio/little_learners/letter_a/intro.mp3'); // the letter introduces itself when the lesson opens (after the unit's title was said on the map)
      audio.played.clear();

      await tester.ensureVisible(find.byKey(const Key('word-apple')));
      await tester.tap(find.byKey(const Key('word-apple')));
      await tester.pump();
      expect(audio.played, ['asset:audio/little_learners/letter_a/word_apple.mp3']);

      await tester.ensureVisible(find.byKey(const Key('lesson-letter-tap')));
      await tester.tap(find.byKey(const Key('lesson-letter-tap')));
      await tester.pump();
      expect(audio.played.length, 2);
    });
  });
}
