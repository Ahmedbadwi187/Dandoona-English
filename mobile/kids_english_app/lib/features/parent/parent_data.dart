import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../content/content_repository.dart';
import '../progress/progress.dart';
import '../settings/settings.dart';
import '../units/unit_logic.dart';
import '../units/unit_meta.dart';

/// What the parent screens say about one child's place in the course.
class ChildOverview {
  const ChildOverview({required this.statuses});

  final List<UnitStatus> statuses;

  /// The unit the child is working on now: the first open one that is not finished (null when everything is done or
  /// nothing is open).
  UnitStatus? get current => statuses.where((s) => s.state == UnitState.current).firstOrNull;

  int get unitsDone => statuses.where((s) => s.state == UnitState.done).length;
  int get unitsTotal => statuses.length;
}

/// The unit statuses of [childId], computed the same way as the child's own unit map. Null while the lessons load.
final childOverviewProvider = Provider.family<ChildOverview?, String>((ref, childId) {
  final track = ref.watch(contentProvider).asData?.value;
  if (track == null) return null;
  ref.watch(progressProvider);
  final progress = ref.read(progressProvider.notifier);
  final meta = ref.watch(unitMetaProvider);
  return ChildOverview(
    statuses: computeUnitStatuses(
      track.units,
      (lessonId) => progress.hasProgress(childId, lessonId),
      unlockAll: ref.watch(settingsProvider).unlockAll,
      placedUnits: meta.of(childId).placed,
    ),
  );
});
