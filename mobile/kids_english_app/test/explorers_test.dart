import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/app.dart';
import 'package:kids_english_app/features/audio/audio_service.dart';
import 'package:kids_english_app/features/content/content_repository.dart';
import 'package:kids_english_app/features/parent/parent_data.dart';
import 'package:kids_english_app/features/profiles/child_profile.dart';
import 'package:kids_english_app/features/progress/progress.dart';
import 'package:kids_english_app/features/rewards/chest_rewards.dart';
import 'package:kids_english_app/features/units/unit_logic.dart';
import 'package:kids_english_app/features/router_state.dart';
import 'package:kids_english_app/router.dart';

import 'helpers.dart';

String _child(String id, String name, String track) =>
    '{"id":"$id","name":"$name","avatarKey":"star","birthYear":2019,"birthMonth":3,"track":"$track","createdAt":"2026-01-01T00:00:00Z"}';

String _progress(Iterable<String> lessons, String child) => jsonEncode([
      for (final l in lessons)
        ProgressRecord(clientRecordId: 'r-$child-$l', childId: child, lessonId: l, activity: 'listen-and-tap', stars: 3, attempts: 1, timeSpentSeconds: 10, completedAt: DateTime.utc(2026, 9, 1)).toJson(),
    ]);

final _letters = [for (var i = 0; i < 26; i++) 'letter-${String.fromCharCode(97 + i)}'];

Future<ProviderContainer> _open(WidgetTester t, {required String children, String? progress}) async {
  t.view.physicalSize = const Size(1080, 2400);
  t.view.devicePixelRatio = 1080 / 411;
  addTearDown(t.view.reset);
  final overrides = await testOverrides(content: realContent(), explorers: realExplorersContent(), prefs: {
    'settings.v1': '{"languageCode":"en","sessionMinutes":15,"unlockAll":false,"onboarded":true}',
    'children.v1': children,
    'progress.v1': ?progress,
  });
  final container = ProviderContainer(overrides: [...overrides, audioServiceProvider.overrideWithValue(FakeAudio()), recorderServiceProvider.overrideWithValue(FakeRecorder())]);
  addTearDown(container.dispose);
  await t.pumpWidget(UncontrolledProviderScope(container: container, child: const KidsEnglishApp()));
  await t.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('an Explorers child sees the Explorers map: Letters first, then Sound Builders', (t) async {
    final c = await _open(t, children: '[${_child('e1', 'Lina', 'explorers')}]');
    expect(c.read(activeTrackProvider), explorersTrack);
    expect(find.byKey(const Key('unit-letters')), findsOneWidget);
    expect(find.byKey(const Key('unit-title-sound-builders')), findsOneWidget);
    expect(find.byKey(const Key('unit-colors')), findsNothing); // no Little Learners units on this map
  });

  testWidgets('Letters done in Little Learners counts in Explorers: the same lessons, so Sound Builders is next', (t) async {
    final c = await _open(t, children: '[${_child('e1', 'Lina', 'explorers')}]', progress: _progress(_letters, 'e1'));
    final track = await c.read(activeContentProvider.future);
    expect(track.track, explorersTrack);
    expect(find.byKey(const Key('unit-done-letters')), findsOneWidget);
  });

  testWidgets('a Little Learners child still gets the Little Learners catalog', (t) async {
    final c = await _open(t, children: '[${_child('c1', 'Omar', 'little-learners')}]');
    expect(c.read(activeTrackProvider), littleLearnersTrack);
    expect((await c.read(activeContentProvider.future)).track, 'little-learners');
    expect(find.byKey(const Key('unit-title-colors')), findsOneWidget);
  });

  test('the parent area reads each child\'s own track', () async {
    final overrides = await testOverrides(content: realContent(), explorers: realExplorersContent(), prefs: {
      'children.v1': '[${_child('c1', 'Omar', 'little-learners')},${_child('e1', 'Lina', 'explorers')}]',
    });
    final c = ProviderContainer(overrides: overrides);
    addTearDown(c.dispose);
    await c.read(trackContentProvider(littleLearnersTrack).future);
    await c.read(trackContentProvider(explorersTrack).future);
    final omar = c.read(childOverviewProvider('c1'))!;
    final lina = c.read(childOverviewProvider('e1'))!;
    expect(omar.statuses.map((s) => s.unit.id), contains('colors'));
    expect(lina.statuses.map((s) => s.unit.id).take(2), ['letters', 'sound-builders']);
    expect(lina.current!.unit.id, 'letters');
    expect(lina.statuses[1].state, isNot(UnitState.current)); // waits for Letters
  });

  test('an Explorers child keeps every Little Learners outfit and adds the explorer hat; a Little Learner sees no change', () async {
    final meta = '{"schema":2,"children":{"e1":{"certificates":{},"celebrated":[],"chests":["letters","colors","sound-builders"]},"c1":{"certificates":{},"celebrated":[],"chests":["letters","sound-builders"]}}}';
    final overrides = await testOverrides(content: realContent(), explorers: realExplorersContent(), prefs: {
      'children.v1': '[${_child('c1', 'Omar', 'little-learners')},${_child('e1', 'Lina', 'explorers')}]',
      'meta.v2': meta,
    });
    final c = ProviderContainer(overrides: overrides);
    addTearDown(c.dispose);
    await c.read(contentProvider.future);
    await c.read(explorersContentProvider.future);
    c.read(activeChildIdProvider.notifier).select('e1');
    expect(c.read(chestInventoryProvider).outfits, containsAll(['grad-cap', 'beret', 'explorer-hat']));
    c.read(activeChildIdProvider.notifier).select('c1');
    expect(c.read(chestInventoryProvider).outfits, {'grad-cap'}); // only Little Learners chests count for a Little Learner
  });

  testWidgets('the Explorers map has a review after Blends, after Vowel Teams, after My Sentences and after Grammar Starters', (t) async {
    final c = await _open(t, children: '[${_child('e1', 'Lina', 'explorers')}]');
    final track = await c.read(activeContentProvider.future);
    expect([for (final r in track.reviews) r.units.last], ['blends', 'vowel-teams', 'my-sentences', 'grammar-starters']);
    for (final r in ['review-1', 'review-2', 'review-3', 'review-4']) {
      expect(find.byKey(Key('stop-$r'), skipOffstage: false), findsOneWidget);
    }
  });

  test('phases 2 and 3: each new unit has its own outfit in its chest', () async {
    final meta = '{"schema":2,"children":{"e1":{"certificates":{},"celebrated":[],"chests":["digraphs","blends","magic-e","vowel-teams","sight-words-1","sight-words-2","my-sentences","word-families","everyday-english","numbers-time","grammar-starters"]}}}';
    final overrides = await testOverrides(content: realContent(), explorers: realExplorersContent(), prefs: {
      'children.v1': '[${_child('e1', 'Lina', 'explorers')}]',
      'meta.v2': meta,
    });
    final c = ProviderContainer(overrides: overrides);
    addTearDown(c.dispose);
    await c.read(contentProvider.future);
    await c.read(explorersContentProvider.future);
    c.read(activeChildIdProvider.notifier).select('e1');
    expect(c.read(chestInventoryProvider).outfits, containsAll(['headphones', 'bandana', 'wizard-hat', 'team-cap', 'book-hat', 'detective-cap', 'pencil-band', 'rainbow-band', 'sun-visor', 'clock-cap', 'quill-hat']));
  });

  testWidgets('the parent sees an Explorers child with the Explorers units (not the Little Learners ones) in the details', (t) async {
    final c = await _open(t, children: '[${_child('e1', 'Lina', 'explorers')},${_child('c1', 'Omar', 'little-learners')}]', progress: _progress(_letters, 'e1'));
    c.read(parentSessionProvider.notifier).unlock();
    c.read(routerProvider).go('/parent/child/e1');
    await t.pumpAndSettle();
    expect(find.byKey(const Key('detail-name')), findsOneWidget);
    await t.scrollUntilVisible(find.byKey(const Key('unit-row-sound-builders')), 300, scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const Key('unit-row-sound-builders')), findsOneWidget);
    expect(find.byKey(const Key('unit-row-animals'), skipOffstage: false), findsNothing); // a Little Learners unit
    c.read(routerProvider).go('/parent/child/c1');
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.byKey(const Key('unit-row-animals')), 300, scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const Key('unit-row-sound-builders'), skipOffstage: false), findsNothing);
  });
}
