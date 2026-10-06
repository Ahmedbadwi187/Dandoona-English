import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/core/storage.dart';
import 'package:kids_english_app/features/content/content_models.dart';
import 'package:kids_english_app/features/progress/progress.dart';
import 'package:kids_english_app/features/units/unit_logic.dart';
import 'package:kids_english_app/features/units/unit_meta.dart';

import 'helpers.dart';

CourseUnit _unit(String id, int order, int lessons, {String prefix = 'x'}) => CourseUnit(
      id: id,
      order: order,
      title: {'en': id, 'ar': id},
      icon: id,
      color: 'red',
      lessons: [
        for (var i = 1; i <= lessons; i++)
          Lesson(
            id: '$prefix$i',
            order: i,
            level: 'pre-a1',
            audio: const LessonAudio(intro: 'a.mp3', praise: ['p.mp3']),
            words: const [LessonWord(word: 'w', audio: 'w.mp3', image: 'w.svg')],
            activities: const ['listen-and-tap'],
          ),
      ],
    );

ProgressRecord _rec(String child, String lesson, DateTime when) => ProgressRecord(
      clientRecordId: '$child-$lesson',
      childId: child,
      lessonId: lesson,
      activity: 'listen-and-tap',
      stars: 3,
      attempts: 3,
      timeSpentSeconds: 10,
      completedAt: when,
    );

void main() {
  group('content: units', () {
    final v2 = {
      'schemaVersion': 2,
      'track': 'little-learners',
      'mascot': 'images/mascot/mascot.webp',
      'units': [
        {
          'id': 'colors',
          'order': 2,
          'title': {'en': 'Colors', 'ar': 'الألوان'},
          'icon': 'colors',
          'color': 'orange',
          'audio': {'title': 't.mp3', 'celebration': 'c.mp3'},
          'lessons': <Map<String, dynamic>>[],
        },
        {
          'id': 'letters',
          'order': 1,
          'title': {'en': 'Letters', 'ar': 'الحروف'},
          'icon': 'letters',
          'color': 'red',
          'lessons': [
            {
              'id': 'letter-a',
              'order': 1,
              'level': 'pre-a1',
              'letter': 'A',
              'audio': {'intro': 'i.mp3', 'praise': ['p.mp3']},
              'words': [
                {'word': 'apple', 'audio': 'a.mp3', 'image': 'a.svg'}
              ],
              'activities': ['trace'],
            }
          ],
        },
      ],
    };

    test('schemaVersion 2: units are ordered, lessons live inside them, new units need no code', () {
      final c = TrackContent.fromJson(v2);
      expect(c.units.map((u) => u.id), ['letters', 'colors']);
      expect(c.units.first.titleFor('ar'), 'الحروف');
      expect(c.units[1].comingSoon, isTrue);
      expect(c.units[1].audio!.celebration, 'c.mp3');
      expect(c.lessons.map((l) => l.id), ['letter-a']);
      expect(c.unitOfLesson('letter-a')!.id, 'letters');
      expect(c.lessonById('letter-a')!.letter, 'A');
    });

    test('schemaVersion 1 (before units) still loads as one Letters unit', () {
      final v1 = {
        'schemaVersion': 1,
        'track': 'little-learners',
        'lessons': (v2['units']! as List).last['lessons'],
      };
      final c = TrackContent.fromJson(v1);
      expect(c.units.single.id, 'letters');
      expect(c.lessons.single.id, 'letter-a');
    });

    test('an unknown schema version is refused', () {
      expect(() => TrackContent.fromJson({'schemaVersion': 9, 'track': 't'}), throwsFormatException);
    });

    test('the bundled lesson file has the Letters unit with 26 lessons and every other unit listed as coming soon', () {
      final c = realContent();
      expect(c.units.first.id, 'letters');
      expect(c.units.first.lessons, hasLength(26));
      expect(c.units.map((u) => u.id), containsAllInOrder(['letters', 'colors', 'numbers', 'shapes', 'animals', 'my-body', 'food', 'my-family']));
      expect(c.units.first.audio, isNotNull);
    });
  });

  group('a unit opens only when the previous unit is finished', () {
    final units = [_unit('letters', 1, 3, prefix: 'l'), _unit('colors', 2, 2, prefix: 'c'), _unit('numbers', 3, 0), _unit('shapes', 4, 2, prefix: 's')];

    List<UnitState> states(Set<String> started, {bool unlockAll = false}) =>
        computeUnitStatuses(units, started.contains, unlockAll: unlockAll).map((s) => s.state).toList();

    test('a new child: Letters is current, everything after waits', () {
      expect(states({}), [UnitState.current, UnitState.locked, UnitState.soon, UnitState.locked]);
    });

    test('part of Letters done: still current, with a progress count', () {
      final s = computeUnitStatuses(units, {'l1', 'l2'}.contains);
      expect(s.first.state, UnitState.current);
      expect((s.first.done, s.first.total), (2, 3));
      expect(s[1].state, UnitState.locked);
    });

    test('Letters finished: it is done and Colors opens', () {
      expect(states({'l1', 'l2', 'l3'}), [UnitState.done, UnitState.current, UnitState.soon, UnitState.locked]);
    });

    test('a unit without lessons is "coming soon" and keeps later units closed even if they were played', () {
      expect(states({'l1', 'l2', 'l3', 'c1', 'c2', 's1'}), [UnitState.done, UnitState.done, UnitState.soon, UnitState.locked]);
    });

    test('the parent\'s "unlock all" opens every unit that has lessons', () {
      expect(states({}, unlockAll: true), [UnitState.current, UnitState.current, UnitState.soon, UnitState.current]);
    });
  });

  group('migration of local progress to units', () {
    final letters = _unit('letters', 1, 3, prefix: 'l');
    final colors = _unit('colors', 2, 2, prefix: 'c');
    final day = DateTime.utc(2026, 9, 1, 12);

    test('children who finished Letters get its certificate and celebration; progress records are not touched', () {
      final progress = [
        _rec('done', 'l1', day),
        _rec('done', 'l2', day.add(const Duration(days: 1))),
        _rec('done', 'l3', day.add(const Duration(days: 2))),
        _rec('part', 'l1', day),
        _rec('part', 'l2', day),
      ];
      final before = jsonEncode(progress.map((r) => r.toJson()).toList());

      final meta = migrateUnitMeta(existing: const UnitMeta(schema: 0), units: [letters, colors], progress: progress, childIds: ['done', 'part', 'new']);

      expect(meta.schema, 2);
      expect(meta.of('done').certificates, {'letters': '2026-09-03'});
      expect(meta.of('done').celebrated, {'letters'});
      expect(meta.of('part').certificates, isEmpty);
      expect(meta.of('new').certificates, isEmpty);
      expect(jsonEncode(progress.map((r) => r.toJson()).toList()), before); // progress carried over unchanged
    });

    test('it is idempotent and never overwrites a certificate that was already earned', () {
      final progress = [for (final l in ['l1', 'l2', 'l3']) _rec('a', l, day)];
      final first = migrateUnitMeta(existing: const UnitMeta(schema: 0), units: [letters], progress: progress, childIds: ['a']);
      final again = migrateUnitMeta(existing: first, units: [letters], progress: progress, childIds: ['a']);
      expect(identical(first, again), isTrue);

      final earlier = const UnitMeta(schema: 0, children: {'a': ChildUnitMeta(certificates: {'letters': '2025-01-01'})});
      final kept = migrateUnitMeta(existing: earlier, units: [letters], progress: progress, childIds: ['a']);
      expect(kept.of('a').certificates['letters'], '2025-01-01');
    });

    test('the notifier migrates once from the stored v1 progress and persists meta.v2', () async {
      final prefs = await mockPrefs({
        'progress.v1': jsonEncode([for (final l in ['l1', 'l2', 'l3']) _rec('kid', l, day).toJson()]),
      });
      final container = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
      addTearDown(container.dispose);

      expect(container.read(unitMetaProvider).schema, 0);
      await container.read(unitMetaProvider.notifier).migrateIfNeeded(
            units: [letters, colors],
            progress: container.read(progressProvider),
            childIds: ['kid'],
          );
      expect(container.read(unitMetaProvider).of('kid').certificates.keys, ['letters']);

      final stored = jsonDecode(prefs.getString('meta.v2')!) as Map<String, dynamic>;
      expect(stored['schema'], 2);

      // a fresh start reads what was saved and does not migrate again
      final again = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
      addTearDown(again.dispose);
      expect(again.read(unitMetaProvider).schema, 2);
      expect(again.read(unitMetaProvider).of('kid').celebrated, {'letters'});
    });

    test('awarding a certificate is recorded once and removed with the child', () async {
      final prefs = await mockPrefs();
      final container = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
      addTearDown(container.dispose);
      final n = container.read(unitMetaProvider.notifier);
      await n.awardCertificate('kid', 'colors', DateTime(2026, 10, 7));
      await n.awardCertificate('kid', 'colors', DateTime(2027, 1, 1)); // second call keeps the first date
      expect(container.read(unitMetaProvider).of('kid').certificates, {'colors': '2026-10-07'});
      await n.removeForChild('kid');
      expect(container.read(unitMetaProvider).of('kid').certificates, isEmpty);
    });
  });
}
