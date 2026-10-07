import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/app.dart';
import 'package:kids_english_app/core/storage.dart';
import 'package:kids_english_app/features/audio/audio_service.dart';
import 'package:kids_english_app/features/content/content_models.dart';
import 'package:kids_english_app/features/onboarding/track_resolver.dart';
import 'package:kids_english_app/features/units/unit_logic.dart';
import 'package:kids_english_app/features/units/unit_meta.dart';

import 'helpers.dart';

void main() {
  final content = realContent();

  group('the track follows the age', () {
    final now = DateTime(2026, 10, 7);

    test('a four-year-old is a Little Learner; the month decides before and after the birthday', () {
      expect(resolveTrack(birthYear: 2022, birthMonth: 3, now: now).ageYears, 4);
      expect(resolveTrack(birthYear: 2022, birthMonth: 12, now: now).ageYears, 3); // still three until December
      expect(resolveTrack(birthYear: 2022, now: now).ageYears, 4); // no month: the year alone
      final c = resolveTrack(birthYear: 2022, birthMonth: 3, now: now);
      expect((c.trackId, c.resolvedTrackId, c.available), ('little-learners', 'little-learners', true));
    });

    test('ages 3 to 5 are Little Learners', () {
      for (final age in [3, 4, 5]) {
        expect(resolveTrack(birthYear: 2026 - age, birthMonth: 1, now: now).trackId, 'little-learners', reason: 'age $age');
      }
    });

    test('older children are named for the track that fits, and use Little Learners until it exists', () {
      final six = resolveTrack(birthYear: 2020, birthMonth: 1, now: now);
      expect((six.ageYears, six.trackId, six.available, six.resolvedTrackId), (6, 'explorers', false, 'little-learners'));
      final ten = resolveTrack(birthYear: 2016, birthMonth: 1, now: now);
      expect((ten.trackId, ten.resolvedTrackId), ('champions', 'little-learners'));
      final readyExplorers = resolveTrack(birthYear: 2020, birthMonth: 1, now: now, available: {'little-learners', 'explorers'});
      expect((readyExplorers.available, readyExplorers.resolvedTrackId), (true, 'explorers'));
    });
  });

  group('placement comes from the content file', () {
    test('all four answers are in the exported content, and they name real units', () {
      expect(content.placement.map((p) => p.level), [0, 1, 2, 3]);
      final unitIds = content.units.map((u) => u.id).toSet();
      for (final p in content.placement) {
        expect(unitIds, containsAll([...p.doneUnits, p.startUnit]), reason: p.key);
      }
    });

    test('"knows all letters" marks Letters done by placement and starts at Colors; "doesn\'t know any English" starts at Letters', () {
      final allLetters = content.placement.singleWhere((p) => p.key == 'all-letters');
      expect(allLetters.doneUnits, ['letters']);
      expect(allLetters.startUnit, 'colors');
      expect(content.placement.singleWhere((p) => p.key == 'none').startUnit, 'letters');
    });

    test('a file without placement (older exports) still loads', () {
      final json = jsonDecode('{"schemaVersion":2,"track":"t","units":[]}') as Map<String, dynamic>;
      expect(TrackContent.fromJson(json).placement, isEmpty);
    });
  });

  group('units done by placement', () {
    final units = content.units;

    test('Letters placed: it counts as done (no certificate), Colors opens, the rest wait', () {
      final s = computeUnitStatuses(units, (_) => false, placedUnits: {'letters'});
      expect(s[0].state, UnitState.done);
      expect(s[0].placed, isTrue);
      expect(s[1].state, UnitState.current);
      expect(s[2].state, UnitState.soon);
    });

    test('a placed unit the child also really finished is just done', () {
      final s = computeUnitStatuses(units, (id) => id.startsWith('letter-'), placedUnits: {'letters'});
      expect(s[0].placed, isFalse);
    });

    test('the placement is remembered per child, saved, and survives a restart', () async {
      final prefs = await mockPrefs();
      final c = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
      addTearDown(c.dispose);
      await c.read(unitMetaProvider.notifier).setPlaced('kid', {'letters'});
      expect(c.read(unitMetaProvider).of('kid').placed, {'letters'});
      expect(c.read(unitMetaProvider).of('other').placed, isEmpty);

      final again = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
      addTearDown(again.dispose);
      expect(again.read(unitMetaProvider).of('kid').placed, {'letters'});
      await again.read(unitMetaProvider.notifier).setPlaced('kid', {}); // answered again: back to nothing placed
      expect(again.read(unitMetaProvider).of('kid').placed, isEmpty);
    });

    testWidgets('on the map: Letters is done without a certificate button, Colors is the current unit', (t) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 1080 / 411;
      addTearDown(t.view.reset);
      final overrides = await testOverrides(content: content, prefs: {
        'settings.v1': '{"languageCode":"en","sessionMinutes":15,"unlockAll":false,"onboarded":true,"languageChosen":true}',
        'children.v1': '[{"id":"c1","name":"Omar","avatarKey":"bunny","birthYear":2022,"track":"little-learners","createdAt":"2026-01-01T00:00:00Z"}]',
        'meta.v2': '{"schema":2,"children":{"c1":{"certificates":{},"celebrated":[],"placed":["letters"]}}}',
      });
      await t.pumpWidget(ProviderScope(overrides: [...overrides, audioServiceProvider.overrideWithValue(FakeAudio())], child: const KidsEnglishApp()));
      await t.pumpAndSettle();
      await t.tap(find.text('Omar'));
      await t.pumpAndSettle();

      expect(find.byKey(const Key('unit-done-letters')), findsOneWidget);
      expect(find.byKey(const Key('unit-certificate-letters')), findsNothing); // placed, not earned
      expect(find.byKey(const Key('unit-play-colors')), findsOneWidget);
    });
  });
}
