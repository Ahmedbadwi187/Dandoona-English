import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/app.dart';
import 'package:kids_english_app/features/activities/listen_and_tap_activity.dart';
import 'package:kids_english_app/features/audio/audio_service.dart';
import 'package:kids_english_app/features/content/content_models.dart';
import 'package:kids_english_app/features/parent/child_detail_screen.dart';
import 'package:kids_english_app/features/profiles/child_profile.dart';
import 'package:kids_english_app/features/progress/progress.dart';
import 'package:kids_english_app/features/units/practice_screen.dart';
import 'package:kids_english_app/features/units/word_misses.dart';
import 'package:kids_english_app/router.dart';

import 'helpers.dart';

const _child = '[{"id":"c1","name":"Omar","avatarKey":"star","birthYear":2022,"track":"little-learners","createdAt":"2026-01-01T00:00:00Z"}]';
const _settings = '{"languageCode":"en","sessionMinutes":15,"unlockAll":false,"onboarded":true,"languageChosen":true}';

String _where(ProviderContainer c) => c.read(routerProvider).routerDelegate.currentConfiguration.last.matchedLocation;

void main() {
  final catalog = realContent();

  Future<(ProviderContainer, FakeAudio)> open(WidgetTester t, {Map<String, Object> misses = const {}}) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 1080 / 411;
    addTearDown(t.view.reset);
    final audio = FakeAudio();
    final overrides = await testOverrides(content: catalog, prefs: {'settings.v1': _settings, 'children.v1': _child, if (misses.isNotEmpty) 'misses.v1': jsonEncode(misses)});
    final c = ProviderContainer(overrides: [...overrides, audioServiceProvider.overrideWithValue(audio)]);
    addTearDown(c.dispose);
    await t.pumpWidget(UncontrolledProviderScope(container: c, child: const KidsEnglishApp()));
    await t.pumpAndSettle();
    return (c, audio);
  }

  group('the list of missed words', () {
    testWidgets('a miss adds one, getting it right takes one away, nothing is below zero, and it survives a restart', (t) async {
      final (c, _) = await open(t);
      final n = c.read(wordMissesProvider.notifier);
      await n.miss('c1', 'letter-a', 'apple');
      await n.miss('c1', 'letter-a', 'apple');
      await n.miss('c1', 'letter-b', 'ball');
      expect(n.of('c1').map((m) => '${m.word}:${m.count}'), ['apple:2', 'ball:1']); // most missed first
      await n.got('c1', 'letter-a', 'apple');
      expect(n.of('c1').map((m) => '${m.word}:${m.count}'), ['apple:1', 'ball:1']);
      await n.got('c1', 'letter-b', 'ball');
      await n.got('c1', 'letter-b', 'ball'); // already gone: nothing happens
      expect(n.of('c1').map((m) => m.word), ['apple']);
      await n.got('c1', 'letter-z', 'zebra'); // never missed
      expect(n.of('c1').length, 1);
      // read again from the saved data
      final again = ProviderContainer(overrides: await testOverrides(content: catalog, prefs: {'misses.v1': jsonEncode(c.read(wordMissesProvider))}));
      addTearDown(again.dispose);
      expect(again.read(wordMissesProvider.notifier).of('c1').map((m) => m.word), ['apple']);
    });

    testWidgets('removing the child forgets the words too', (t) async {
      final (c, _) = await open(t, misses: {'c1': {'letter-a|apple': 2}});
      expect(c.read(wordMissesProvider.notifier).of('c1'), isNotEmpty);
      await c.read(profilesProvider.notifier).remove('c1');
      expect(c.read(wordMissesProvider.notifier).of('c1'), isEmpty);
    });
  });

  group('the games report misses', () {
    Future<(FakeAudio, List<String>, List<String>)> game(WidgetTester t) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 1080 / 411;
      addTearDown(t.view.reset);
      final audio = FakeAudio();
      final overrides = await testOverrides(content: catalog);
      final missed = <String>[], right = <String>[];
      await t.pumpWidget(ProviderScope(
        overrides: [...overrides, audioServiceProvider.overrideWithValue(audio)],
        child: MaterialApp(
          home: Scaffold(
            body: ListenAndTapActivity(
              lesson: catalog.lessonById('letter-a')!,
              track: catalog,
              random: Random(3),
              nextDelay: const Duration(milliseconds: 20),
              onMiss: (w) => missed.add(w.word),
              onRight: (w) => right.add(w.word),
              onFinished: (_) {},
            ),
          ),
        ),
      ));
      await t.pump();
      await t.pump();
      return (audio, missed, right);
    }

    testWidgets('a word tapped wrongly twice is reported once; a word found at once is reported as right', (t) async {
      final (audio, missed, right) = await game(t);
      final lesson = catalog.lessonById('letter-a')!;
      LessonWord target() => lesson.words.firstWhere((w) => 'asset:${w.audio}' == audio.played.lastWhere((p) => p.startsWith('asset:') && lesson.words.any((w) => 'asset:${w.audio}' == p)));
      final first = target();
      final wrongKeys = [for (final w in lesson.words) if (w.word != first.word) w.word];
      // taps on pictures that are not in this round are ignored by find; pick any visible wrong option
      final visibleWrong = [for (final k in find.byWidgetPredicate((w) => w.key is ValueKey && '${w.key}'.startsWith("[<'option-")).evaluate().map((e) => (e.widget.key as ValueKey).value as String)) k]
          .where((k) => k != 'option-${first.word}')
          .toList();
      expect(visibleWrong, isNotEmpty);
      await t.tap(find.byKey(Key(visibleWrong[0])));
      await t.pump(const Duration(milliseconds: 100));
      await t.tap(find.byKey(Key(visibleWrong[1])));
      await t.pump(const Duration(milliseconds: 700));
      expect(missed, [first.word]); // reported once, although tapped wrongly twice
      await t.tap(find.byKey(Key('option-${first.word}')));
      await t.pump(const Duration(seconds: 2));
      expect(right, isEmpty, reason: 'this round had a wrong tap');
      expect(wrongKeys, isNotEmpty);
      final second = target();
      await t.tap(find.byKey(Key('option-${second.word}')));
      await t.pump(const Duration(seconds: 2));
      expect(right, [second.word]);
    });
  });

  group('Practice', () {
    test('the words wait most missed first, only those whose lesson is on the phone, at most five', () {
      final missed = [
        const MissedWord(lessonId: 'letter-a', word: 'apple', count: 3),
        const MissedWord(lessonId: 'animals-1', word: 'cat', count: 2), // a pack that is not installed in this catalog
        const MissedWord(lessonId: 'letter-b', word: 'ball', count: 2),
        const MissedWord(lessonId: 'letter-b', word: 'nothing', count: 1), // not a word of the lesson
        const MissedWord(lessonId: 'letter-c', word: 'cat', count: 1),
      ];
      final items = practiceItems(catalog, missed);
      expect(items.map((i) => i.word.word), ['apple', 'ball', 'cat']);
      expect(practiceItems(catalog, missed, max: 2).length, 2);
    });

    testWidgets('the map shows the Practice button only when words are waiting; the game gives words back and ends on the map', (t) async {
      final (c, _) = await open(t);
      expect(find.byKey(const Key('open-practice')), findsNothing);
      await c.read(wordMissesProvider.notifier).miss('c1', 'letter-a', 'apple');
      await t.pumpAndSettle();
      expect(find.byKey(const Key('open-practice')), findsOneWidget);

      await t.tap(find.byKey(const Key('open-practice')));
      await t.pumpAndSettle();
      expect(_where(c), '/practice');
      expect(find.byKey(const Key('practice-game')), findsOneWidget);
      // one word, three pictures: tap the apple (the only target)
      await t.tap(find.byKey(const Key('option-apple')));
      await t.pump(const Duration(seconds: 2));
      await t.pumpAndSettle();
      expect(c.read(wordMissesProvider.notifier).of('c1'), isEmpty); // found at once: taken off the list
      expect(find.byKey(const Key('practice-done')), findsOneWidget);
      await t.tap(find.byKey(const Key('practice-done')));
      await t.pumpAndSettle();
      expect(_where(c), '/map');
      expect(find.byKey(const Key('open-practice')), findsNothing);
    });

    testWidgets('a word missed again in Practice stays on the list', (t) async {
      final (c, _) = await open(t, misses: {'c1': {'letter-a|apple': 2}});
      c.read(routerProvider).push('/practice');
      await t.pumpAndSettle();
      final wrong = find.byWidgetPredicate((w) => w.key is ValueKey && '${w.key}'.startsWith("[<'option-") && '${w.key}' != "[<'option-apple'>]").first;
      await t.tap(wrong);
      await t.pump(const Duration(milliseconds: 700));
      await t.tap(find.byKey(const Key('option-apple')));
      await t.pump(const Duration(seconds: 2));
      await t.pumpAndSettle();
      expect(c.read(wordMissesProvider.notifier).of('c1').map((m) => '${m.word}:${m.count}'), ['apple:2']);
    });
  });

  group('the parent\'s Practice at home list', () {
    test('the words the child really missed come first, then the lessons that took the most tries, without repeats', () {
      final records = [
        ProgressRecord(clientRecordId: 'r1', childId: 'c1', lessonId: 'letter-d', activity: 'listen-and-tap', stars: 1, attempts: 5, timeSpentSeconds: 10, completedAt: DateTime.utc(2026, 9, 1)),
        ProgressRecord(clientRecordId: 'r2', childId: 'c1', lessonId: 'letter-a', activity: 'listen-and-tap', stars: 1, attempts: 5, timeSpentSeconds: 10, completedAt: DateTime.utc(2026, 9, 1)),
      ];
      final words = wordsToPractice(
        catalog,
        records,
        'c1',
        _FakeProgress(),
        missed: const [MissedWord(lessonId: 'letter-g', word: 'goat', count: 2), MissedWord(lessonId: 'letter-a', word: 'apple', count: 1)],
      );
      expect(words.map((w) => w.word), ['goat', 'apple', 'dog']); // then the lessons with the most tries (letter-d starts with dog); letter-a is not repeated
    });
  });
}

class _FakeProgress implements ProgressNotifier {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
