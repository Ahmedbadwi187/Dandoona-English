import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/app.dart';
import 'package:kids_english_app/features/audio/audio_service.dart';
import 'package:kids_english_app/features/content/content_models.dart';
import 'package:kids_english_app/features/progress/progress.dart';
import 'package:kids_english_app/features/units/review_logic.dart';
import 'package:kids_english_app/features/units/unit_meta.dart';
import 'package:kids_english_app/router.dart';

import 'helpers.dart';

const _child = '[{"id":"c1","name":"Omar","avatarKey":"star","birthYear":2022,"track":"little-learners","createdAt":"2026-01-01T00:00:00Z"}]';
const _settings = '{"languageCode":"en","sessionMinutes":15,"unlockAll":false,"onboarded":true,"languageChosen":true}';

String _where(ProviderContainer c) => c.read(routerProvider).routerDelegate.currentConfiguration.last.matchedLocation;

void main() {
  final content = realContent();
  const group1 = ['letters', 'colors', 'numbers', 'shapes'];

  group('review words', () {
    test('two words from each unit that is on the phone, never the same picture twice, at most eight', () {
      for (var seed = 0; seed < 30; seed++) {
        final words = reviewWords(content, group1, Random(seed));
        expect(words.length, 4); // Letters and Colors are bundled; the Numbers and Shapes packs are not on the phone in this test
        expect(words.map((w) => w.image).toSet().length, words.length);
        final letters = content.unitById('letters')!.lessons.expand((l) => l.words).map((w) => w.word).toSet();
        final colors = content.unitById('colors')!.lessons.expand((l) => l.words).map((w) => w.word).toSet();
        expect(words.where((w) => letters.contains(w.word)).length, greaterThanOrEqualTo(1));
        expect(words.where((w) => colors.contains(w.word)).length, greaterThanOrEqualTo(1));
      }
    });

    test('with the packs on the phone every unit gets its turn: eight words, two per unit', () {
      final numbers = CourseUnit(
        id: 'numbers',
        order: 3,
        title: const {'en': 'Numbers'},
        icon: 'numbers',
        color: 'blue',
        lessons: [content.lessonById('letter-a')!, content.lessonById('letter-b')!].map((l) => Lesson(id: 'n-${l.id}', order: 1, level: 'pre-a1', audio: l.audio, words: [for (final w in l.words) LessonWord(word: 'n${w.word}', audio: w.audio, image: 'n-${w.image}')], activities: l.activities)).toList(),
      );
      final track = content.withUnits([...content.units.where((u) => u.id != 'numbers'), numbers]);
      final words = reviewWords(track, group1, Random(3));
      expect(words.length, 6); // shapes is still missing: 2 + 2 + 2
      expect(words.where((w) => w.word.startsWith('n')).length, greaterThanOrEqualTo(2));
    });

    test('fewer than three words: there is no review yet', () {
      expect(buildReviewLesson(content, 'review-2', const ['animals', 'feelings'], Random(1)), isNull);
      final lesson = buildReviewLesson(content, 'review-1', group1, Random(1))!;
      expect(lesson.activities, ['listen-and-tap']);
      expect(lesson.words.length, 4);
      expect(lesson.audio.praise, isNotEmpty);
    });
  });

  testWidgets('a ready review opens the game, never fails, and passing it is remembered', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 1080 / 411;
    addTearDown(t.view.reset);
    final ids = [
      for (final u in content.units.where((u) => group1.contains(u.id))) ...u.lessonIds,
    ];
    final progress = jsonEncode([
      for (final l in ids)
        ProgressRecord(clientRecordId: 'r-$l', childId: 'c1', lessonId: l, activity: 'listen-and-tap', stars: 3, attempts: 3, timeSpentSeconds: 10, completedAt: DateTime.utc(2026, 9, 1)).toJson(),
    ]);
    final audio = FakeAudio();
    final overrides = await testOverrides(content: content, prefs: {'settings.v1': _settings, 'children.v1': _child, 'progress.v1': progress});
    final c = ProviderContainer(overrides: [...overrides, audioServiceProvider.overrideWithValue(audio)]);
    addTearDown(c.dispose);
    await t.pumpWidget(UncontrolledProviderScope(container: c, child: const KidsEnglishApp()));
    await t.pumpAndSettle();

    await Scrollable.ensureVisible(t.element(find.byKey(const Key('stop-review-1'))), alignment: 0.5);
    await t.pumpAndSettle();
    expect(c.read(unitMetaProvider).of('c1').reviews, isEmpty);
    await t.tap(find.byKey(const Key('stop-review-1')));
    await t.pumpAndSettle();
    expect(_where(c), '/review/review-1');
    expect(find.text('Review time!'), findsOneWidget);
    expect(find.byKey(const Key('review-game')), findsOneWidget);

    // the word of every audio file, to know what is being asked
    final byAudio = {for (final u in content.units) for (final l in u.lessons) for (final w in l.words) 'asset:${w.audio}': w.word};
    var rounds = 0;
    while (find.byKey(const Key('review-passed')).evaluate().isEmpty && rounds < 12) {
      final asked = byAudio[audio.played.reversed.firstWhere(byAudio.containsKey)]!;
      await t.tap(find.byKey(Key('option-$asked')));
      await t.pump(const Duration(milliseconds: 1500));
      await t.pumpAndSettle();
      rounds++;
    }
    expect(find.byKey(const Key('review-passed')), findsOneWidget);
    expect(rounds, 4);
    expect(find.text('You passed the review!'), findsOneWidget);
    expect(c.read(unitMetaProvider).of('c1').reviews, {'review-1'});

    await t.tap(find.byKey(const Key('review-done')));
    await t.pumpAndSettle();
    expect(_where(c), '/map');
  });

  testWidgets('a wrong tap does not fail the review (the word is just said again)', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 1080 / 411;
    addTearDown(t.view.reset);
    final audio = FakeAudio();
    final overrides = await testOverrides(content: content, prefs: {'settings.v1': _settings, 'children.v1': _child});
    final c = ProviderContainer(overrides: [...overrides, audioServiceProvider.overrideWithValue(audio)]);
    addTearDown(c.dispose);
    await t.pumpWidget(UncontrolledProviderScope(container: c, child: const KidsEnglishApp()));
    await t.pumpAndSettle();
    c.read(routerProvider).push('/review/review-1');
    await t.pumpAndSettle();
    final byAudio = {for (final u in content.units) for (final l in u.lessons) for (final w in l.words) 'asset:${w.audio}': w.word};
    final asked = byAudio[audio.played.reversed.firstWhere(byAudio.containsKey)]!;
    final options = t.widgetList(find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('option-'))).map((w) => (w.key as ValueKey<String>).value.substring(7)).toList();
    final wrong = options.firstWhere((o) => o != asked);
    final before = audio.played.length;
    await t.tap(find.byKey(Key('option-$wrong')));
    await t.pump(const Duration(milliseconds: 100));
    expect(audio.played.length, greaterThan(before)); // said again
    expect(find.byKey(const Key('review-passed')), findsNothing);
    expect(c.read(unitMetaProvider).of('c1').reviews, isEmpty);
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.byKey(const Key('review-back'))); // leaving stops the hint timer
    await t.pumpAndSettle();
  });
}
