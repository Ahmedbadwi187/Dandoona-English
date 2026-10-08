import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/app.dart';
import 'package:kids_english_app/features/audio/audio_service.dart';
import 'package:kids_english_app/features/progress/progress.dart';
import 'package:kids_english_app/features/units/unit_meta.dart';
import 'package:kids_english_app/router.dart';

import 'helpers.dart';
import 'pack_helpers.dart';

const _child = '[{"id":"c1","name":"Omar","avatarKey":"star","birthYear":2022,"track":"little-learners","createdAt":"2026-01-01T00:00:00Z"}]';
const _settings = '{"languageCode":"en","sessionMinutes":15,"unlockAll":false,"onboarded":true,"languageChosen":true}';
final _letters = [for (var i = 0; i < 26; i++) 'letter-${String.fromCharCode(97 + i)}'];

String _progress(Iterable<String> lessons) => jsonEncode([
      for (final l in lessons)
        ProgressRecord(clientRecordId: 'r-$l', childId: 'c1', lessonId: l, activity: 'listen-and-tap', stars: 3, attempts: 3, timeSpentSeconds: 10, completedAt: DateTime.utc(2026, 9, 1)).toJson(),
    ]);

String _where(ProviderContainer c) => c.read(routerProvider).routerDelegate.currentConfiguration.last.matchedLocation;

void main() {
  final catalog = realContent();

  group('the stories of the course', () {
    test('every unit has a five-page story; each page has a sentence, its spoken file in the app, and only words of its unit', () {
      for (final u in catalog.units) {
        expect(u.story, isNotNull, reason: u.id);
        expect(u.story!.pages.length, 5, reason: u.id);
        final lessons = u.lessons.isNotEmpty ? u.lessons : packLessons(u.id);
        final words = {for (final l in lessons) for (final w in l.words) w.word.toLowerCase()};
        for (final (i, p) in u.story!.pages.indexed) {
          expect(p.text.trim(), isNotEmpty, reason: '${u.id} page ${i + 1}');
          expect(File('assets/${p.audio}').existsSync(), isTrue, reason: '${u.id} page ${i + 1}: ${p.audio} is bundled');
          expect(p.words.length, lessThanOrEqualTo(3));
          for (final w in p.words) {
            expect(words, contains(w.toLowerCase()), reason: '${u.id} page ${i + 1}: $w is a word of the unit');
          }
          expect([null, 'waving', 'jumping', 'clapping', 'thinking', 'pointing-up', 'base'], contains(p.pose), reason: '${u.id} page ${i + 1}');
        }
      }
    });

    test('the story is part of the unit and survives the unit getting its lessons from a pack', () {
      final numbers = catalog.unitById('numbers')!;
      expect(numbers.story!.pages.first.text, 'Dandoona has one balloon.');
      expect(numbers.withLessons(packLessons('numbers')).story, isNotNull);
    });
  });

  testWidgets('a ready story on the map opens: each page is read aloud, pictures say their word, the end is remembered', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 1080 / 411;
    addTearDown(t.view.reset);
    final audio = FakeAudio();
    final overrides = await testOverrides(content: catalog, prefs: {'settings.v1': _settings, 'children.v1': _child, 'progress.v1': _progress(_letters)});
    final c = ProviderContainer(overrides: [...overrides, audioServiceProvider.overrideWithValue(audio)]);
    addTearDown(c.dispose);
    await t.pumpWidget(UncontrolledProviderScope(container: c, child: const KidsEnglishApp()));
    await t.pumpAndSettle();

    await Scrollable.ensureVisible(t.element(find.byKey(const Key('stop-story-letters'))), alignment: 0.5);
    await t.pumpAndSettle();
    expect(c.read(unitMetaProvider).of('c1').stories, isEmpty);
    audio.played.clear();
    await t.tap(find.byKey(const Key('stop-story-letters')));
    await t.pumpAndSettle();
    expect(_where(c), '/story/letters');

    final pages = catalog.unitById('letters')!.story!.pages;
    expect(find.text(pages[0].text), findsOneWidget);
    expect(audio.played, ['asset:${pages[0].audio}']); // read aloud when the page opens
    expect(find.byKey(const Key('story-dot-4')), findsOneWidget);

    await t.tap(find.byKey(const Key('story-next')));
    await t.pumpAndSettle();
    expect(find.text(pages[1].text), findsOneWidget);
    expect(audio.played.last, 'asset:${pages[1].audio}');
    expect(find.byKey(const Key('story-picture-apple')), findsOneWidget);
    expect(find.byKey(const Key('story-picture-banana')), findsOneWidget);
    await t.tap(find.byKey(const Key('story-picture-apple'))); // a picture says its word
    await t.pump();
    expect(audio.played.last, startsWith('asset:audio/little_learners/letter_a/'));
    await t.tap(find.byKey(const Key('story-text'))); // the sentence again
    await t.pump();
    expect(audio.played.last, 'asset:${pages[1].audio}');

    for (var i = 2; i < pages.length; i++) {
      await t.tap(find.byKey(const Key('story-next')));
      await t.pumpAndSettle();
    }
    expect(find.text(pages.last.text), findsOneWidget);
    expect(find.byKey(const Key('story-next')), findsNothing);
    expect(find.text('The end!'), findsOneWidget);
    expect(c.read(unitMetaProvider).of('c1').stories, isEmpty); // not yet: only the last button ends it
    await t.tap(find.byKey(const Key('story-done')));
    await t.pumpAndSettle();
    expect(c.read(unitMetaProvider).of('c1').stories, {'letters'});
    expect(_where(c), '/map');

    // read again later: opens the same story, nothing is lost
    await Scrollable.ensureVisible(t.element(find.byKey(const Key('stop-story-letters'))), alignment: 0.5);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('stop-story-letters')));
    await t.pumpAndSettle();
    expect(_where(c), '/story/letters');
    expect(find.text(pages[0].text), findsOneWidget);
    await t.tap(find.byKey(const Key('story-back')));
    await t.pumpAndSettle();
    expect(c.read(unitMetaProvider).of('c1').stories, {'letters'});
  });

  testWidgets('a story whose pack is not on the phone yet waits (Almost ready!) instead of showing empty pages', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 1080 / 411;
    addTearDown(t.view.reset);
    final overrides = await testOverrides(content: catalog, prefs: {'settings.v1': _settings, 'children.v1': _child});
    final c = ProviderContainer(overrides: [...overrides, audioServiceProvider.overrideWithValue(FakeAudio())]);
    addTearDown(c.dispose);
    await t.pumpWidget(UncontrolledProviderScope(container: c, child: const KidsEnglishApp()));
    await t.pumpAndSettle();
    c.read(routerProvider).push('/story/animals');
    await t.pumpAndSettle();
    expect(find.byKey(const Key('story-waiting')), findsOneWidget);
    expect(find.text('Almost ready!'), findsOneWidget);
  });
}
