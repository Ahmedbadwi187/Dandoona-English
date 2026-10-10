import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../content/content_repository.dart';
import '../profiles/child_profile.dart';
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

/// One child's place in one track: units done and what the child played in the last 7 days.
class TrackProgress {
  const TrackProgress({required this.track, required this.unitsDone, required this.unitsTotal, required this.activitiesThisWeek, required this.active});
  final String track;
  final int unitsDone;
  final int unitsTotal;
  final int activitiesThisWeek;

  /// The track the child plays now (the one on the child's map).
  final bool active;
}

/// The child's progress in every released track, so the dashboard and the child's page can show them side by side. The active track comes
/// first. Letters is shared by both tracks (same lessons, same progress), so it counts in both.
final childTracksProvider = Provider.family<List<TrackProgress>, String>((ref, childId) {
  final child = ref.watch(profilesProvider).where((p) => p.id == childId).firstOrNull;
  if (child == null) return const [];
  ref.watch(progressProvider);
  final progress = ref.read(progressProvider.notifier);
  final records = ref.read(progressProvider);
  final meta = ref.watch(unitMetaProvider).of(childId);
  final since = ref.read(clockProvider)().subtract(const Duration(days: 7));
  final out = <TrackProgress>[];
  for (final track in [child.track, ...availableTracks.where((t) => t != child.track)]) {
    final content = ref.watch(trackContentProvider(track)).asData?.value;
    if (content == null) continue;
    final statuses = computeUnitStatuses(content.units, (l) => progress.hasProgress(childId, l), placedUnits: meta.placed);
    final lessons = {for (final l in content.units.expand((u) => u.lessonIds)) l};
    out.add(TrackProgress(
      track: track,
      unitsDone: statuses.where((s) => s.state == UnitState.done).length,
      unitsTotal: statuses.length,
      activitiesThisWeek: records.where((r) => r.childId == childId && r.completedAt.isAfter(since) && lessons.contains(r.lessonId)).length,
      active: track == (explorersEnabled ? child.track : littleLearnersTrack),
    ));
  }
  return out;
});

/// The unit statuses of [childId], computed the same way as the child's own unit map. Null while the lessons load.
final childOverviewProvider = Provider.family<ChildOverview?, String>((ref, childId) {
  final child = ref.watch(profilesProvider).where((p) => p.id == childId).firstOrNull;
  final track = ref.watch(trackContentProvider(child?.track ?? littleLearnersTrack)).asData?.value;
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
