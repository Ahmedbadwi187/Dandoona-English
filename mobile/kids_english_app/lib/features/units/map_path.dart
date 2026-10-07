import '../content/content_models.dart' show ReviewStop;
import 'unit_logic.dart';
import 'unit_meta.dart';

/// What sits on the map's path: unit islands, the smaller stations between them, and the castle at the end.
enum StopKind { unit, story, chest, review, castle }

/// done: finished (story read, chest opened, review passed). current: the unit being learned. ready: a station or the castle
/// that can be played now. locked: not reached yet. soon: a unit whose lessons are not built yet.
enum StopState { done, current, ready, locked, soon }

class MapStop {
  const MapStop({required this.kind, required this.id, required this.state, this.unit, this.review});

  final StopKind kind;

  /// Unique on the path: the unit id for an island, `story-<unit>`, `chest-<unit>`, the review id, or `castle`.
  final String id;
  final StopState state;

  /// The unit itself (islands) or the unit a story or chest belongs to.
  final UnitStatus? unit;
  final ReviewStop? review;

  bool get isIsland => kind == StopKind.unit || kind == StopKind.castle;
}

/// The castle's own review: every unit of the track, passed once for the track certificate.
const castleId = 'castle';

/// Lays the units out on one path in their opening order. After each unit come its story (only when the unit has one)
/// and its treasure chest, then a review when the content file puts one there; the castle ends the path.
///
/// Rules: a unit opens when the previous unit is finished (see [computeUnitStatuses]) and every review before it is
/// passed. Stories and chests never block the way. A chest is ready as soon as its unit is done (also a unit done by
/// placement or before the stations existed), so nobody loses a chest they have earned. The parent's "unlock all" opens
/// every unit and review.
List<MapStop> buildMapPath({required List<UnitStatus> units, required List<ReviewStop> reviews, required ChildUnitMeta meta, bool unlockAll = false}) {
  final stops = <MapStop>[];
  var reviewsPassed = true;
  for (final s in units) {
    final id = s.unit.id;
    var state = switch (s.state) {
      UnitState.done => StopState.done,
      UnitState.current => StopState.current,
      UnitState.locked => StopState.locked,
      UnitState.soon => StopState.soon,
    };
    if (state == StopState.current && !reviewsPassed && !unlockAll) state = StopState.locked;
    stops.add(MapStop(kind: StopKind.unit, id: id, state: state, unit: s));
    final unitDone = state == StopState.done;

    if (s.unit.hasStory) {
      stops.add(
        MapStop(
          kind: StopKind.story,
          id: 'story-$id',
          unit: s,
          state: meta.stories.contains(id) ? StopState.done : (unitDone ? StopState.ready : StopState.locked),
        ),
      );
    }
    stops.add(
      MapStop(
        kind: StopKind.chest,
        id: 'chest-$id',
        unit: s,
        state: meta.chests.contains(id) ? StopState.done : (unitDone ? StopState.ready : StopState.locked),
      ),
    );

    for (final r in reviews.where((r) => r.after == id)) {
      final passed = meta.reviews.contains(r.id);
      final groupDone = r.units.every((u) => stops.any((x) => x.kind == StopKind.unit && x.id == u && x.state == StopState.done));
      stops.add(
        MapStop(kind: StopKind.review, id: r.id, review: r, state: passed ? StopState.done : ((groupDone || unlockAll) ? StopState.ready : StopState.locked)),
      );
      if (!passed) reviewsPassed = false;
    }
  }

  final allDone = stops.where((x) => x.kind == StopKind.unit).every((x) => x.state == StopState.done);
  stops.add(
    MapStop(
      kind: StopKind.castle,
      id: castleId,
      review: ReviewStop(id: castleId, units: [for (final s in units) s.unit.id]),
      state: meta.reviews.contains(castleId) ? StopState.done : ((allDone && reviewsPassed) ? StopState.ready : StopState.locked),
    ),
  );
  return stops;
}

/// Where Dandoona stands: the first unit being learned, or the first review or castle that is ready to play.
/// -1 when there is none (every stop done, or nothing built yet).
int currentStopIndex(List<MapStop> stops) => stops.indexWhere(
  (s) => (s.kind == StopKind.unit && s.state == StopState.current) || ((s.kind == StopKind.review || s.kind == StopKind.castle) && s.state == StopState.ready),
);

/// The stop a child must finish before a closed stop opens: the one Dandoona stands on (a unit, a review or the castle).
MapStop? blockingStop(List<MapStop> stops) {
  final i = currentStopIndex(stops);
  return i < 0 ? null : stops[i];
}
