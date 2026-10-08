import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/features/activities/activity_logic.dart';
import 'package:kids_english_app/features/activities/color_the_object_activity.dart';
import 'package:kids_english_app/features/activities/listen_and_tap_activity.dart';
import 'package:kids_english_app/features/activities/record_listen_activity.dart';
import 'package:kids_english_app/features/audio/audio_service.dart';
import 'package:kids_english_app/features/content/content_models.dart';

import 'helpers.dart';

void main() {
  final content = realContent();
  final colors = content.unitById('colors')!;
  final red = colors.lessons.first;

  group('the Colors unit in the bundled content', () {
    test('has ten lessons, one per color, each with the four activities and a spoken instruction for each', () {
      expect(colors.lessons.map((l) => l.color!.name), ['red', 'blue', 'yellow', 'green', 'orange', 'purple', 'pink', 'brown', 'black', 'white']);
      for (final l in colors.lessons) {
        expect(l.activities.where((a) => a != 'mix-colors'), ['listen-and-tap', 'match-picture', 'record-and-listen', 'color-the-object'], reason: l.id);
        for (final a in l.activities.where((a) => a != 'mix-colors')) { // the mixing game speaks only the colors
          expect(l.audio.instructions.containsKey(a), isTrue, reason: '${l.id} has no spoken instruction for $a');
        }
        expect(l.words, hasLength(3));
        expect(l.words.every((w) => w.phrase != null), isTrue);
        expect(l.audio.colorName, isNotNull);
      }
      expect(colors.audio, isNotNull);
    });

    test('every audio and image file the lesson file points at exists in the app assets (all units)', () {
      final missing = <String>[];
      void check(String? path) {
        if (path != null && !File('assets/$path').existsSync()) missing.add(path);
      }

      for (final u in content.units) {
        check(u.audio?.title);
        check(u.audio?.welcome);
        check(u.audio?.celebration);
        for (final l in u.lessons) {
          check(l.audio.intro);
          check(l.audio.phoneme);
          check(l.audio.colorName);
          l.audio.praise.forEach(check);
          l.audio.instructions.values.forEach(check);
          check(l.color?.swatch);
          check(l.color?.drawing);
          for (final w in l.words) {
            check(w.audio);
            check(w.image);
            check(w.phrase);
          }
        }
      }
      expect(missing, isEmpty);
    });

    test('each swatch is the lesson color and each drawing has a place to fill', () {
      for (final l in colors.lessons) {
        expect(File('assets/${l.color!.swatch}').readAsStringSync().toUpperCase(), contains(l.color!.hex.toUpperCase()), reason: l.id);
        expect(File('assets/${l.color!.drawing}').readAsStringSync(), contains(fillPlaceholder), reason: l.id);
      }
    });
  });

  group('listen-and-tap in the Colors unit', () {
    test('wrong pictures come only from the unit\'s other colors', () {
      final ownImages = red.words.map((w) => w.image).toSet();
      final otherColorImages = {for (final l in colors.lessons.skip(1)) ...l.words.map((w) => w.image)};
      for (var seed = 0; seed < 20; seed++) {
        for (final round in buildChoiceRounds(red, content, Random(seed))) {
          for (final o in round.options) {
            if (o.word == round.target.word) continue;
            expect(ownImages.contains(o.image), isFalse, reason: 'a same-colored picture is not a wrong answer');
            expect(otherColorImages.contains(o.image), isTrue, reason: '${o.word} is not from another color of the unit');
          }
        }
      }
    });

    testWidgets('Dandoona says the color, not the object', (t) async {
      final audio = FakeAudio();
      final overrides = await testOverrides(content: content);
      await t.pumpWidget(ProviderScope(
        overrides: [...overrides, audioServiceProvider.overrideWithValue(audio)],
        child: MaterialApp(home: Scaffold(body: ListenAndTapActivity(lesson: red, track: content, random: Random(1), onFinished: (_) {}))),
      ));
      await t.pump();
      expect(audio.played, ['asset:${red.audio.instructions['listen-and-tap']}', 'asset:${red.audio.colorName}']);
      await t.pumpWidget(const SizedBox());
    });
  });

  testWidgets('record-and-listen says the phrase ("A red apple.") in the Colors unit', (t) async {
    final audio = FakeAudio();
    final overrides = await testOverrides(content: content);
    await t.pumpWidget(ProviderScope(
      overrides: [...overrides, audioServiceProvider.overrideWithValue(audio), recorderServiceProvider.overrideWithValue(FakeRecorder())],
      child: MaterialApp(home: Scaffold(body: RecordListenActivity(lesson: red, onFinished: (_) {}))),
    ));
    await t.pump();
    expect(audio.played.last, 'asset:${red.words.first.phrase}');
  });

  group('color-the-object', () {
    Future<(FakeAudio, List<ActivityResult>)> pump(WidgetTester t, {Duration hintAfter = const Duration(seconds: 8), Lesson? lesson}) async {
      final audio = FakeAudio();
      final results = <ActivityResult>[];
      final overrides = await testOverrides(content: content);
      await t.pumpWidget(ProviderScope(
        overrides: [...overrides, audioServiceProvider.overrideWithValue(audio)],
        child: MaterialApp(
          home: Scaffold(
            body: ColorTheObjectActivity(
              lesson: lesson ?? red,
              track: content,
              random: Random(2),
              hintAfter: hintAfter,
              finishDelay: const Duration(milliseconds: 100),
              onFinished: results.add,
            ),
          ),
        ),
      ));
      await t.pump();
      // the drawing is read from the asset bundle (real I/O): wait until it is on screen
      for (var i = 0; i < 40 && find.byKey(const Key('drawing-empty')).evaluate().isEmpty; i++) {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await t.pump(const Duration(milliseconds: 10));
      }
      return (audio, results);
    }

    Finder swatch(String name) => find.byKey(Key('swatch-$name'));

    testWidgets('speaks its instruction when it starts, and the speaker button says it again', (t) async {
      final (audio, _) = await pump(t);
      expect(audio.played, ['asset:${red.audio.instructions['color-the-object']}']);
      await t.tap(find.byKey(const Key('hear-instruction')));
      await t.pump();
      expect(audio.played, hasLength(2));
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('offers the lesson color and three others from the unit; the drawing starts empty', (t) async {
      await pump(t);
      expect(find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('swatch-')), findsNWidgets(4));
      expect(swatch('red'), findsOneWidget);
      expect(find.byKey(const Key('drawing-empty')), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('picking a color says its name', (t) async {
      final (audio, _) = await pump(t);
      audio.played.clear();
      await t.tap(swatch('red'));
      await t.pump();
      expect(audio.played, ['asset:${red.audio.colorName}']);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('the right color fills the drawing and finishes with 3 stars', (t) async {
      final (_, results) = await pump(t);
      await t.tap(swatch('red'));
      await t.pump();
      await t.tap(find.byKey(const Key('color-drawing')));
      await t.pump();
      expect(find.byKey(const Key('drawing-#E5524A')), findsOneWidget);
      await t.pump(const Duration(milliseconds: 300));
      expect(results.single.stars, 3);
    });

    testWidgets('a wrong color is not scolded: the drawing stays empty, the right name is said again, and a star is lost', (t) async {
      final (audio, results) = await pump(t);
      final wrong = ['blue', 'yellow', 'green', 'orange', 'purple', 'pink', 'brown', 'black', 'white'].firstWhere((n) => swatch(n).evaluate().isNotEmpty);
      await t.tap(swatch(wrong));
      await t.pump();
      audio.played.clear();
      await t.tap(find.byKey(const Key('color-drawing')));
      await t.pump(const Duration(milliseconds: 800));
      expect(find.byKey(const Key('drawing-empty')), findsOneWidget);
      expect(audio.played, ['asset:${red.audio.colorName}']);
      expect(results, isEmpty);

      await t.tap(swatch('red'));
      await t.pump();
      await t.tap(find.byKey(const Key('color-drawing')));
      await t.pump(const Duration(milliseconds: 300));
      expect(results.single.stars, 2);
    });

    testWidgets('after a while with no tap the right color lights up and its name is said', (t) async {
      final (audio, _) = await pump(t, hintAfter: const Duration(milliseconds: 500));
      audio.played.clear();
      await t.pump(const Duration(milliseconds: 600));
      expect(audio.played, ['asset:${red.audio.colorName}']);
      final box = t.widget<Container>(find.descendant(of: swatch('red'), matching: find.byType(Container)).first);
      expect((box.decoration! as BoxDecoration).border!.top.width, 9);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('every Colors lesson loads its drawing', (t) async {
      for (final l in colors.lessons) {
        await pump(t, lesson: l);
        expect(find.byKey(const Key('drawing-empty')), findsOneWidget, reason: l.id);
        await t.pumpWidget(const SizedBox());
      }
    });
  });

}
