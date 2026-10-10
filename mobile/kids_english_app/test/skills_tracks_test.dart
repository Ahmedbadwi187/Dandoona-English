import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/features/content/content_repository.dart';
import 'package:kids_english_app/features/parent/parent_data.dart';
import 'package:kids_english_app/features/profiles/child_profile.dart';
import 'package:kids_english_app/features/progress/progress.dart';
import 'package:kids_english_app/features/skills/skills.dart';
import 'package:kids_english_app/features/skills/skip_ahead.dart';
import 'package:kids_english_app/features/units/unit_meta.dart';

import 'helpers.dart';

SkillsConfig _config() => SkillsConfig.fromJson(jsonDecode(File('assets/content/skills.json').readAsStringSync()) as Map<String, dynamic>);

Future<ProviderContainer> _container({Map<String, Object> prefs = const {}}) async {
  final overrides = await testOverrides(content: realContent(), explorers: realExplorersContent(), prefs: prefs);
  final c = ProviderContainer(overrides: overrides);
  addTearDown(c.dispose);
  return c;
}

void main() {
  final config = _config();

  group('children saved before the skills list', () {
    test('each gets the skills of their old answer, read back from the units it counted as done; nobody else is touched; the track stays', () async {
      final saved = <String, Set<String>>{};
      final n = await convertOldChildren(
        config: config,
        children: [
          (id: 'none', skills: null),
          (id: 'letters', skills: null),
          (id: 'reads', skills: null),
          (id: 'already', skills: {'colors'}),
        ],
        placedOf: (id) => switch (id) {
          'letters' => {'letters'},
          'reads' => {'letters', 'sound-builders'},
          _ => <String>{},
        },
        save: (id, skills) async => saved[id] = skills,
      );
      expect(n, 3);
      expect(saved['none'], {skillNone});
      expect(saved['letters'], {'all-letters', 'some-letters'});
      expect(saved['reads'], {'reads-words', 'all-letters', 'letter-sounds', 'some-letters'});
      expect(saved.containsKey('already'), isFalse);
    });

    test('the conversion keeps the track and the time of the last change (it is not an edit by the parent)', () async {
      final c = await _container(prefs: {
        'children.v1': '[{"id":"c1","name":"Lina","avatarKey":"star","birthYear":2019,"track":"explorers","createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-05-05T10:00:00.000Z"}]',
      });
      await c.read(profilesProvider.notifier).setSkillsQuietly('c1', {'colors'});
      final k = c.read(profilesProvider).single;
      expect(k.skills, {'colors'});
      expect(k.track, 'explorers');
      expect(k.updatedAt, DateTime.utc(2026, 5, 5, 10));
      // a child that already has skills is not overwritten
      await c.read(profilesProvider.notifier).setSkillsQuietly('c1', {'animals'});
      expect(c.read(profilesProvider).single.skills, {'colors'});
    });
  });

  group('editing the skills never removes real progress', () {
    test('marks on units the child played stay; marks on units never played can go; the other track\'s marks stay; new ones are added', () {
      final explorers = ['letters', 'sound-builders', 'digraphs', 'blends'];
      final after = placedAfterEdit(
        oldPlaced: {'letters', 'sound-builders', 'digraphs', 'colors'}, // colors belongs to the other track
        trackUnitIds: explorers,
        playedUnits: {'digraphs'}, // the child really played Digraphs
        plan: ['letters'], // the parent unchecked "reads words": only Letters is covered now
      );
      expect(after, {'letters', 'digraphs', 'colors'}); // Sound Builders (never played) lost its mark; Digraphs (played) kept it
    });

    test('unlocking more adds units without removing any', () {
      final after = placedAfterEdit(oldPlaced: {'letters'}, trackUnitIds: ['letters', 'sound-builders', 'digraphs'], playedUnits: {}, plan: ['letters', 'sound-builders']);
      expect(after, {'letters', 'sound-builders'});
    });
  });

  group('progress is kept per track', () {
    test('switching the active track keeps what the child did in each; Letters is shared; the active one is marked', () async {
      final c = await _container(prefs: {
        'children.v1': '[{"id":"c1","name":"Lina","avatarKey":"star","birthYear":2019,"birthMonth":2,"track":"explorers","createdAt":"2026-01-01T00:00:00Z"}]',
      });
      final letters = realContent().units.firstWhere((u) => u.id == 'letters').lessonIds;
      final sound = realExplorersContent().units.firstWhere((u) => u.id == 'sound-builders').lessonIds;
      final now = DateTime.now();
      var n = 0;
      ProgressRecord rec(String lesson) => ProgressRecord(clientRecordId: 'r${n++}', childId: 'c1', lessonId: lesson, activity: 'trace', stars: 3, attempts: 1, timeSpentSeconds: 30, completedAt: now);
      await c.read(progressProvider.notifier).addAll([for (final l in letters) rec(l), rec(sound.first)]);
      c.read(clockProvider);

      List<TrackProgress> tracks() => c.read(childTracksProvider('c1'));
      await c.read(trackContentProvider('explorers').future);
      await c.read(trackContentProvider('little-learners').future);

      var t = tracks();
      expect(t.first.track, 'explorers'); // the active track first
      expect(t.firstWhere((x) => x.active).track, 'explorers');
      expect(t.firstWhere((x) => x.track == 'explorers').unitsDone, 1); // Letters
      expect(t.firstWhere((x) => x.track == 'little-learners').unitsDone, 1); // Letters is shared
      expect(t.firstWhere((x) => x.track == 'explorers').activitiesThisWeek, letters.length + 1);
      expect(t.firstWhere((x) => x.track == 'little-learners').activitiesThisWeek, letters.length); // the Sound Builders lesson is not Little Learners

      await c.read(profilesProvider.notifier).update('c1', track: 'little-learners'); // the parent switches
      t = tracks();
      expect(t.firstWhere((x) => x.active).track, 'little-learners');
      expect(t.firstWhere((x) => x.track == 'explorers').activitiesThisWeek, letters.length + 1, reason: 'nothing was lost in Explorers');
      expect(c.read(progressProvider).length, letters.length + 1);

      await c.read(profilesProvider.notifier).update('c1', track: 'explorers'); // and back: where the child stopped
      expect(tracks().firstWhere((x) => x.active).track, 'explorers');
      expect(c.read(progressProvider).length, letters.length + 1);
    });

    test('the child\'s map follows the active track only (no other track is shown)', () async {
      final c = await _container(prefs: {
        'children.v1': '[{"id":"c1","name":"Lina","avatarKey":"star","birthYear":2019,"birthMonth":2,"track":"explorers","createdAt":"2026-01-01T00:00:00Z"}]',
      });
      c.read(activeChildIdProvider.notifier).select('c1');
      expect(c.read(activeTrackProvider), 'explorers');
      expect((await c.read(activeContentProvider.future)).track, 'explorers');
      await c.read(profilesProvider.notifier).update('c1', track: 'little-learners');
      expect(c.read(activeTrackProvider), 'little-learners');
      expect((await c.read(activeContentProvider.future)).track, 'little-learners');
    });
  });

  group('skip ahead', () {
    Future<(ProviderContainer, SkipAheadNotifier)> rig() async {
      final c = await _container(prefs: {
        'children.v1': '[{"id":"c1","name":"Lina","avatarKey":"star","birthYear":2019,"birthMonth":2,"track":"explorers","skills":["unsure"],"createdAt":"2026-01-01T00:00:00Z"}]',
      });
      return (c, c.read(skipAheadProvider.notifier));
    }

    Future<void> perfect(ProviderContainer c, SkipAheadNotifier n, List<String> reviewUnits, {Set<String> skills = const {skillUnsure}}) async {
      final track = await c.read(trackContentProvider('explorers').future);
      await n.reviewPassedPerfectly(childId: 'c1', skills: skills, track: track, reviewUnits: reviewUnits);
    }

    test('only "I am not sure" children get it; the first unit not played after the review is suggested', () async {
      final (c, n) = await rig();
      await perfect(c, n, ['sound-builders', 'digraphs', 'blends'], skills: {'colors'});
      expect(n.of('c1').pendingUnit, isNull);
      await perfect(c, n, ['sound-builders', 'digraphs', 'blends']);
      expect(n.of('c1').pendingUnit, 'magic-e');
    });

    test('a unit already played, or done by placement, is never suggested', () async {
      final (c, n) = await rig();
      final magic = realExplorersContent().units.firstWhere((u) => u.id == 'magic-e');
      await c.read(progressProvider.notifier).addAll([
        ProgressRecord(clientRecordId: 'p1', childId: 'c1', lessonId: magic.lessonIds.first, activity: 'trace', stars: 3, attempts: 1, timeSpentSeconds: 10, completedAt: DateTime.now()),
      ]);
      await c.read(unitMetaProvider.notifier).setPlaced('c1', {'vowel-teams'});
      await perfect(c, n, ['sound-builders', 'digraphs', 'blends']);
      expect(n.of('c1').pendingUnit, 'sight-words-1'); // magic-e was played, vowel-teams is placed
    });

    test('yes: the unit counts as done by placement (no stars) and is not offered again', () async {
      final (c, n) = await rig();
      await perfect(c, n, ['sound-builders', 'digraphs', 'blends']);
      await n.accept('c1');
      expect(c.read(unitMetaProvider).of('c1').placed, contains('magic-e'));
      expect(n.of('c1').pendingUnit, isNull);
      expect(n.of('c1').declinedInRow, 0);
      await perfect(c, n, ['sound-builders', 'digraphs', 'blends']);
      expect(n.of('c1').pendingUnit, 'vowel-teams', reason: 'one unit at a time, and magic-e is done');
    });

    test('once per unit; two "not now" in a row stop it for that child; the parent can turn it back on', () async {
      final (c, n) = await rig();
      await perfect(c, n, ['sound-builders', 'digraphs', 'blends']);
      await n.decline('c1');
      expect(n.of('c1').offered, {'magic-e'});
      expect(n.of('c1').off, isFalse);

      await perfect(c, n, ['sound-builders', 'digraphs', 'blends']);
      expect(n.of('c1').pendingUnit, 'vowel-teams', reason: 'not magic-e again');
      await n.decline('c1');
      expect(n.of('c1').off, isTrue); // two in a row

      await perfect(c, n, ['sound-builders', 'digraphs', 'blends']);
      expect(n.of('c1').pendingUnit, isNull, reason: 'it stopped');

      await n.turnOn('c1'); // Edit child
      expect(n.of('c1').off, isFalse);
      expect(n.of('c1').declinedInRow, 0);
      await perfect(c, n, ['sound-builders', 'digraphs', 'blends']);
      expect(n.of('c1').pendingUnit, 'sight-words-1', reason: 'magic-e and vowel-teams were offered already');
    });

    test('an acceptance between two refusals resets the count', () async {
      final (c, n) = await rig();
      await perfect(c, n, ['sound-builders', 'digraphs', 'blends']);
      await n.decline('c1');
      await perfect(c, n, ['sound-builders', 'digraphs', 'blends']);
      await n.accept('c1');
      expect(n.of('c1').declinedInRow, 0);
      await perfect(c, n, ['sound-builders', 'digraphs', 'blends']);
      await n.decline('c1');
      expect(n.of('c1').off, isFalse, reason: 'only one refusal in a row now');
    });

    test('the state survives a restart', () async {
      final (c, n) = await rig();
      await perfect(c, n, ['sound-builders', 'digraphs', 'blends']);
      expect(c.read(skipAheadProvider)['c1']!.pendingUnit, 'magic-e');
      final saved = c.read(skipAheadProvider.notifier).of('c1').toJson();
      expect(ChildSkip.fromJson(saved).pendingUnit, 'magic-e');
    });
  });
}
