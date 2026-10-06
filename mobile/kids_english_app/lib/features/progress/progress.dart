import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage.dart';

/// One finished activity. Mirrors the API's ProgressRecord so offline records can sync later (Phase 4).
class ProgressRecord {
  const ProgressRecord({
    required this.clientRecordId,
    required this.childId,
    required this.lessonId,
    required this.activity,
    required this.stars,
    required this.attempts,
    required this.timeSpentSeconds,
    required this.completedAt,
  });

  /// Client-generated id so a retried sync is idempotent on the server.
  final String clientRecordId;
  final String childId;
  final String lessonId;
  final String activity; // trace | listen-and-tap | record-and-listen | match-picture
  final int stars; // 0-3
  final int attempts;
  final int timeSpentSeconds;
  final DateTime completedAt;

  Map<String, dynamic> toJson() => {
        'clientRecordId': clientRecordId,
        'childId': childId,
        'lessonId': lessonId,
        'activity': activity,
        'stars': stars,
        'attempts': attempts,
        'timeSpentSeconds': timeSpentSeconds,
        'completedAt': completedAt.toUtc().toIso8601String(),
      };

  factory ProgressRecord.fromJson(Map<String, dynamic> json) => ProgressRecord(
        clientRecordId: json['clientRecordId'] as String,
        childId: json['childId'] as String,
        lessonId: json['lessonId'] as String,
        activity: json['activity'] as String,
        stars: json['stars'] as int,
        attempts: json['attempts'] as int,
        timeSpentSeconds: json['timeSpentSeconds'] as int,
        completedAt: DateTime.parse(json['completedAt'] as String),
      );
}

class ProgressNotifier extends Notifier<List<ProgressRecord>> {
  @override
  List<ProgressRecord> build() {
    final raw = ref.read(sharedPreferencesProvider).readJson(PrefKeys.progress);
    if (raw is! List) return const [];
    final records = <ProgressRecord>[];
    for (final e in raw) {
      try {
        records.add(ProgressRecord.fromJson(e as Map<String, dynamic>));
      } on Object {
        // Skip an unreadable entry.
      }
    }
    return records;
  }

  Future<void> record(ProgressRecord r) async {
    if (state.any((x) => x.clientRecordId == r.clientRecordId)) return; // idempotent
    state = [...state, r];
    await _save();
  }

  Future<void> removeForChild(String childId) async {
    state = state.where((r) => r.childId != childId).toList();
    await _save();
  }

  /// Best stars per activity, summed. A lesson has up to 4 activities x 3 stars.
  int starsFor(String childId, String lessonId) {
    final best = <String, int>{};
    for (final r in state) {
      if (r.childId == childId && r.lessonId == lessonId) {
        final current = best[r.activity] ?? 0;
        if (r.stars > current) best[r.activity] = r.stars;
      }
    }
    return best.values.fold(0, (a, b) => a + b);
  }

  /// Total stars a child has earned: the best result per (lesson, activity), summed. Drives the accessory unlocks.
  int totalStars(String childId) {
    final best = <String, int>{};
    for (final r in state) {
      if (r.childId != childId) continue;
      final key = '${r.lessonId}|${r.activity}';
      if (r.stars > (best[key] ?? 0)) best[key] = r.stars;
    }
    return best.values.fold(0, (a, b) => a + b);
  }

  /// A lesson counts as started once any activity was finished.
  bool hasProgress(String childId, String lessonId) =>
      state.any((r) => r.childId == childId && r.lessonId == lessonId);

  Future<void> _save() =>
      ref.read(sharedPreferencesProvider).writeJson(PrefKeys.progress, state.map((r) => r.toJson()).toList());
}

final progressProvider = NotifierProvider<ProgressNotifier, List<ProgressRecord>>(ProgressNotifier.new);

/// Letter-map rule: the first lesson is open; each next one opens when the previous has progress
/// (or the parent turned on "unlock all").
bool isLessonUnlocked({
  required int index,
  required bool unlockAll,
  required bool previousHasProgress,
}) =>
    unlockAll || index == 0 || previousHasProgress;
