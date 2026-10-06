import '../content/content_models.dart';

/// done: finished. current: open and not finished. locked: waiting for the previous unit. soon: no lessons yet.
enum UnitState { done, current, locked, soon }

class UnitStatus {
  const UnitStatus({required this.unit, required this.state, required this.done, required this.total});

  final CourseUnit unit;
  final UnitState state;

  /// Lessons with progress, and the unit's lesson count (the progress bar, e.g. 4/10).
  final int done;
  final int total;
}

/// A unit is finished when every lesson has progress: the same rule the lesson path uses to open the next lesson,
/// so nobody who already worked through a unit loses anything.
bool isUnitFinished(CourseUnit unit, bool Function(String lessonId) hasProgress) =>
    unit.lessons.isNotEmpty && unit.lessons.every((l) => hasProgress(l.id));

/// A unit opens only when the previous unit is finished (or the parent turned on "unlock all").
/// A unit with no lessons yet is "soon" and never counts as finished, so later units stay closed.
List<UnitStatus> computeUnitStatuses(List<CourseUnit> units, bool Function(String lessonId) hasProgress, {bool unlockAll = false}) {
  final result = <UnitStatus>[];
  var previousFinished = true;
  for (final unit in units) {
    final total = unit.lessons.length;
    final done = unit.lessons.where((l) => hasProgress(l.id)).length;
    if (unit.comingSoon) {
      result.add(UnitStatus(unit: unit, state: UnitState.soon, done: 0, total: 0));
      previousFinished = false;
      continue;
    }
    final finished = isUnitFinished(unit, hasProgress);
    final state = finished
        ? UnitState.done
        : (unlockAll || previousFinished)
            ? UnitState.current
            : UnitState.locked;
    result.add(UnitStatus(unit: unit, state: state, done: done, total: total));
    previousFinished = finished;
  }
  return result;
}
