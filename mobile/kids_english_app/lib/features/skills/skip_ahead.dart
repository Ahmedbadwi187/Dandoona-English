import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage.dart';
import '../content/content_models.dart';
import '../progress/progress.dart';
import '../units/unit_meta.dart';
import 'skills.dart';

/// "[Name] seems to know this already. Skip ahead?": for a child whose parent answered "I'm not sure" about the skills. When the child passes a
/// review with every star on the first try, the parent area suggests marking the next unit the child has not played as done by placement.
/// It never nags: once per unit, and after two "not now" in a row it stops for that child until the parent turns it back on in Edit child.
/// Kept on the phone only (`skipahead.v1`).
class ChildSkip {
  const ChildSkip({this.pendingUnit, this.offered = const {}, this.declinedInRow = 0, this.off = false});

  /// The unit being suggested now (null = nothing to ask).
  final String? pendingUnit;

  /// Units already suggested (accepted or declined): never suggested again.
  final Set<String> offered;
  final int declinedInRow;

  /// Stopped after two "not now" in a row.
  final bool off;

  ChildSkip copyWith({String? pendingUnit, bool clearPending = false, Set<String>? offered, int? declinedInRow, bool? off}) => ChildSkip(
        pendingUnit: clearPending ? null : (pendingUnit ?? this.pendingUnit),
        offered: offered ?? this.offered,
        declinedInRow: declinedInRow ?? this.declinedInRow,
        off: off ?? this.off,
      );

  Map<String, dynamic> toJson() => {if (pendingUnit != null) 'pending': pendingUnit, 'offered': offered.toList()..sort(), 'declined': declinedInRow, 'off': off};

  factory ChildSkip.fromJson(Map<String, dynamic> j) => ChildSkip(
        pendingUnit: j['pending'] as String?,
        offered: ((j['offered'] as List<dynamic>?) ?? const []).cast<String>().toSet(),
        declinedInRow: (j['declined'] as int?) ?? 0,
        off: (j['off'] as bool?) ?? false,
      );
}

/// How many "not now" in a row stop the suggestions.
const skipDeclinesBeforeStop = 2;

class SkipAheadNotifier extends Notifier<Map<String, ChildSkip>> {
  static const key = 'skipahead.v1';

  @override
  Map<String, ChildSkip> build() {
    final raw = ref.read(sharedPreferencesProvider).readJson(key);
    if (raw is Map<String, dynamic>) {
      try {
        return {for (final e in raw.entries) e.key: ChildSkip.fromJson(e.value as Map<String, dynamic>)};
      } on Object {
        // unreadable: start again (nothing is lost, the suggestions simply begin again)
      }
    }
    return const {};
  }

  ChildSkip of(String childId) => state[childId] ?? const ChildSkip();

  /// The first unit after the review's units that the child has not played, is not already done by placement, has lessons, and was not suggested before.
  static String? nextUnitToSkip({required TrackContent track, required List<String> reviewUnits, required bool Function(String lessonId) played, required Set<String> placed, required Set<String> offered}) {
    final ids = [for (final u in track.units) u.id];
    final last = reviewUnits.map(ids.indexOf).fold<int>(-1, (a, b) => b > a ? b : a);
    for (final u in track.units.skip(last + 1)) {
      if (u.lessonIds.isEmpty) continue; // not built yet
      if (placed.contains(u.id) || offered.contains(u.id)) continue;
      if (u.lessonIds.any(played)) continue;
      return u.id;
    }
    return null;
  }

  /// A review was passed with all the stars on the first try. Suggests skipping only for "I'm not sure" children, once per unit, and not after two refusals in a row.
  Future<void> reviewPassedPerfectly({required String childId, required Set<String> skills, required TrackContent track, required List<String> reviewUnits}) async {
    if (!skills.contains(skillUnsure)) return;
    final mine = of(childId);
    if (mine.off || mine.pendingUnit != null) return;
    final progress = ref.read(progressProvider.notifier);
    final unit = nextUnitToSkip(
      track: track,
      reviewUnits: reviewUnits,
      played: (l) => progress.hasProgress(childId, l),
      placed: ref.read(unitMetaProvider).of(childId).placed,
      offered: mine.offered,
    );
    if (unit == null) return;
    await _put(childId, mine.copyWith(pendingUnit: unit));
  }

  /// Yes: the unit counts as done by placement (finished on the map, still open to play, no stars, its chest unlocked).
  Future<void> accept(String childId) async {
    final mine = of(childId);
    final unit = mine.pendingUnit;
    if (unit == null) return;
    final placed = ref.read(unitMetaProvider).of(childId).placed;
    await ref.read(unitMetaProvider.notifier).setPlaced(childId, {...placed, unit});
    await _put(childId, mine.copyWith(clearPending: true, offered: {...mine.offered, unit}, declinedInRow: 0));
  }

  /// Not now: not suggested again for that unit; two in a row stop the suggestions for this child.
  Future<void> decline(String childId) async {
    final mine = of(childId);
    final unit = mine.pendingUnit;
    final declined = mine.declinedInRow + 1;
    await _put(childId, mine.copyWith(clearPending: true, offered: {...mine.offered, ?unit}, declinedInRow: declined, off: declined >= skipDeclinesBeforeStop));
  }

  /// The parent turned the suggestions back on (Edit child).
  Future<void> turnOn(String childId) => _put(childId, of(childId).copyWith(off: false, declinedInRow: 0));

  Future<void> turnOff(String childId) => _put(childId, of(childId).copyWith(off: true, clearPending: true));

  Future<void> _put(String childId, ChildSkip next) async {
    state = {...state, childId: next};
    await ref.read(sharedPreferencesProvider).writeJson(key, state.map((k, v) => MapEntry(k, v.toJson())));
  }
}

final skipAheadProvider = NotifierProvider<SkipAheadNotifier, Map<String, ChildSkip>>(SkipAheadNotifier.new);
