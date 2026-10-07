import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/features/content/content_models.dart';
import 'package:kids_english_app/features/units/map_path.dart';
import 'package:kids_english_app/features/units/unit_logic.dart';
import 'package:kids_english_app/features/units/unit_map_screen.dart';
import 'package:kids_english_app/features/units/unit_meta.dart';

CourseUnit _unit(String id, int order, {int lessons = 1, bool story = false}) => CourseUnit(
      id: id,
      order: order,
      title: {'en': id, 'ar': id},
      icon: id,
      color: 'red',
      hasStory: story,
      lessons: [
        for (var i = 0; i < lessons; i++)
          Lesson(
            id: '$id-$i',
            order: i + 1,
            level: 'pre-a1',
            audio: const LessonAudio(intro: 'x', praise: ['x']),
            words: const [],
            activities: const ['listen-and-tap'],
          ),
      ],
    );

final _units = [_unit('letters', 1, story: true), _unit('colors', 2, story: true), _unit('numbers', 3), _unit('shapes', 4), _unit('animals', 5, lessons: 0)];
const _reviews = [ReviewStop(id: 'review-1', units: ['letters', 'colors', 'numbers', 'shapes'])];

List<MapStop> _path({Set<String> done = const {}, ChildUnitMeta meta = const ChildUnitMeta(), bool unlockAll = false}) => buildMapPath(
      units: computeUnitStatuses(_units, (l) => done.any((u) => l.startsWith('$u-')), unlockAll: unlockAll, placedUnits: meta.placed),
      reviews: _reviews,
      meta: meta,
      unlockAll: unlockAll,
    );

StopState _state(List<MapStop> stops, String id) => stops.firstWhere((s) => s.id == id).state;

void main() {
  test('the path order: each unit, its story (when it has one) and its chest, a review where the content puts one, the castle last', () {
    expect(_path().map((s) => s.id), [
      'letters', 'story-letters', 'chest-letters', //
      'colors', 'story-colors', 'chest-colors',
      'numbers', 'chest-numbers',
      'shapes', 'chest-shapes', 'review-1',
      'animals', 'chest-animals',
      castleId,
    ]);
  });

  test('a new child: Letters is current, its story and chest wait, everything after is closed', () {
    final stops = _path();
    expect(_state(stops, 'letters'), StopState.current);
    expect(_state(stops, 'story-letters'), StopState.locked);
    expect(_state(stops, 'chest-letters'), StopState.locked);
    expect(_state(stops, 'colors'), StopState.locked);
    expect(_state(stops, 'animals'), StopState.soon);
    expect(_state(stops, castleId), StopState.locked);
    expect(stops[currentStopIndex(stops)].id, 'letters');
  });

  test('a child who finished Letters (also before the stations existed) gets the Letters story and chest ready; stories and chests never block', () {
    final stops = _path(done: {'letters'});
    expect(_state(stops, 'story-letters'), StopState.ready);
    expect(_state(stops, 'chest-letters'), StopState.ready);
    expect(_state(stops, 'colors'), StopState.current);
    expect(stops[currentStopIndex(stops)].id, 'colors');
  });

  test('opened chests and read stories stay done', () {
    final stops = _path(done: {'letters'}, meta: const ChildUnitMeta(chests: {'letters'}, stories: {'letters'}));
    expect(_state(stops, 'chest-letters'), StopState.done);
    expect(_state(stops, 'story-letters'), StopState.done);
  });

  test('a chest is ready for a unit done by placement too', () {
    final stops = _path(meta: const ChildUnitMeta(placed: {'letters'}));
    expect(_state(stops, 'chest-letters'), StopState.ready);
  });

  test('the review opens when its units are done, and must be passed before the next unit opens', () {
    final ready = _path(done: {'letters', 'colors', 'numbers', 'shapes'});
    expect(_state(ready, 'review-1'), StopState.ready);
    expect(ready[currentStopIndex(ready)].id, 'review-1'); // Dandoona waits at the review
    expect(blockingStop(ready)!.kind, StopKind.review);

    final notYet = _path(done: {'letters', 'colors', 'numbers'});
    expect(_state(notYet, 'review-1'), StopState.locked);
  });

  test('a unit after a review that is not passed stays closed, even when the unit before it is finished', () {
    final units = [_unit('letters', 1), _unit('colors', 2)];
    const reviews = [ReviewStop(id: 'review-1', units: ['letters'])];
    List<MapStop> path(ChildUnitMeta meta) =>
        buildMapPath(units: computeUnitStatuses(units, (l) => l.startsWith('letters-')), reviews: reviews, meta: meta);
    expect(_state(path(const ChildUnitMeta()), 'colors'), StopState.locked);
    expect(_state(path(const ChildUnitMeta(reviews: {'review-1'})), 'colors'), StopState.current);
  });

  test('a unit already finished stays done after a review is added before it (nobody loses progress)', () {
    final units = [_unit('letters', 1), _unit('colors', 2)];
    const reviews = [ReviewStop(id: 'review-1', units: ['letters'])];
    final stops = buildMapPath(units: computeUnitStatuses(units, (_) => true), reviews: reviews, meta: const ChildUnitMeta());
    expect(_state(stops, 'colors'), StopState.done);
  });

  test('the parent\'s "unlock all" opens the reviews too', () {
    final stops = _path(unlockAll: true);
    expect(_state(stops, 'review-1'), StopState.ready);
    expect(_state(stops, 'colors'), StopState.current);
  });

  test('the castle opens when every unit is done and every review passed', () {
    final units = [_unit('letters', 1), _unit('colors', 2)];
    const reviews = [ReviewStop(id: 'review-1', units: ['letters', 'colors'])];
    List<MapStop> path(ChildUnitMeta meta) => buildMapPath(units: computeUnitStatuses(units, (_) => true), reviews: reviews, meta: meta);
    expect(_state(path(const ChildUnitMeta()), castleId), StopState.locked);
    expect(_state(path(const ChildUnitMeta(reviews: {'review-1'})), castleId), StopState.ready);
    expect(_state(path(const ChildUnitMeta(reviews: {'review-1', castleId})), castleId), StopState.done);
  });

  group('saved data', () {
    test('meta saved before the stations existed still reads, with nothing passed or opened', () {
      final m = ChildUnitMeta.fromJson({'certificates': {'letters': '2026-09-01'}, 'celebrated': ['letters']});
      expect(m.certificates, {'letters': '2026-09-01'});
      expect(m.reviews, isEmpty);
      expect(m.chests, isEmpty);
      expect(m.stories, isEmpty);
    });

    test('merging from the server never takes anything away and keeps the earliest certificate date', () {
      const here = ChildUnitMeta(certificates: {'letters': '2026-09-05'}, chests: {'letters'}, reviews: {'review-1'});
      final merged = mergeAchievements(here, [
        (kind: 'certificate', key: 'letters', earnedAt: DateTime.utc(2026, 9, 1)),
        (kind: 'certificate', key: 'colors', earnedAt: DateTime.utc(2026, 9, 20)),
        (kind: 'story', key: 'letters', earnedAt: DateTime.utc(2026, 9, 2)),
      ]);
      expect(merged.certificates, {'letters': '2026-09-01', 'colors': '2026-09-20'});
      expect(merged.celebrated, {'letters', 'colors'}); // not celebrated again on this phone
      expect(merged.chests, {'letters'});
      expect(merged.reviews, {'review-1'});
      expect(merged.stories, {'letters'});
      // and what this phone sends back
      final out = achievementsOf(merged, DateTime.utc(2026, 10, 1));
      expect(out.where((a) => a.kind == 'certificate').map((a) => a.earnedAt), [DateTime.utc(2026, 9, 1), DateTime.utc(2026, 9, 20)]);
      expect(out.map((a) => '${a.kind}:${a.key}'), containsAll(['chest:letters', 'review:review-1', 'story:letters']));
    });

    test('the new sets round-trip, and are left out when empty (older app versions read the same file)', () {
      const m = ChildUnitMeta(reviews: {'review-1'}, chests: {'letters'}, stories: {'letters'});
      expect(ChildUnitMeta.fromJson(m.toJson()).chests, {'letters'});
      expect(const ChildUnitMeta().toJson().keys, ['certificates', 'celebrated']);
    });
  });

  group('layout', () {
    test('islands alternate sides, stations sit between them, the castle is in the middle, and the path only goes down', () {
      final stops = _path();
      final l = layoutStops(stops, 400);
      final islands = [for (var i = 0; i < stops.length; i++) if (stops[i].kind == StopKind.unit) l.centers[i].dx];
      expect(islands.take(4).map((x) => x.round()), [112, 288, 112, 288]);
      expect(l.centers.last.dx, 200);
      for (var i = 1; i < l.centers.length; i++) {
        expect(l.centers[i].dy, greaterThan(l.centers[i - 1].dy));
      }
      // the first station after Letters is between Letters and Colors
      expect(l.centers[1].dx, inExclusiveRange(112, 288));
      expect(l.height, greaterThan(l.centers.last.dy));
    });
  });
}
