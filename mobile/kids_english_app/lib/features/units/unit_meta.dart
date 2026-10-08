import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage.dart';
import '../content/content_models.dart';
import '../progress/progress.dart';

/// What the app remembers per child about units, next to (not inside) the progress records: which unit
/// certificates were earned, and which unit celebrations were already shown.
/// Stored under `meta.v2`; `progress.v1` is never rewritten, so existing progress is untouched.
class ChildUnitMeta {
  const ChildUnitMeta({
    this.certificates = const {},
    this.celebrated = const {},
    this.placed = const {},
    this.reviews = const {},
    this.chests = const {},
    this.stories = const {},
  });

  /// unit id -> date earned (yyyy-MM-dd).
  final Map<String, String> certificates;
  final Set<String> celebrated;

  /// Units that count as done because of the parent's answer about the child's English (the placement), not because the
  /// child finished them: they open the next unit and give no certificate.
  final Set<String> placed;

  /// Map stops (added with the stations; older saved data has none of them, which reads as "not yet"):
  /// passed reviews (review ids), opened treasure chests and read stories (unit ids).
  final Set<String> reviews;
  final Set<String> chests;
  final Set<String> stories;

  ChildUnitMeta copyWith({
    Map<String, String>? certificates,
    Set<String>? celebrated,
    Set<String>? placed,
    Set<String>? reviews,
    Set<String>? chests,
    Set<String>? stories,
  }) => ChildUnitMeta(
    certificates: certificates ?? this.certificates,
    celebrated: celebrated ?? this.celebrated,
    placed: placed ?? this.placed,
    reviews: reviews ?? this.reviews,
    chests: chests ?? this.chests,
    stories: stories ?? this.stories,
  );

  Map<String, dynamic> toJson() => {
    'certificates': certificates,
    'celebrated': celebrated.toList()..sort(),
    if (placed.isNotEmpty) 'placed': placed.toList()..sort(),
    if (reviews.isNotEmpty) 'reviews': reviews.toList()..sort(),
    if (chests.isNotEmpty) 'chests': chests.toList()..sort(),
    if (stories.isNotEmpty) 'stories': stories.toList()..sort(),
  };

  static Set<String> _set(Object? raw) => ((raw as List<dynamic>?) ?? const []).cast<String>().toSet();

  factory ChildUnitMeta.fromJson(Map<String, dynamic> json) => ChildUnitMeta(
    certificates: ((json['certificates'] as Map<String, dynamic>?) ?? const {}).map((k, v) => MapEntry(k, v as String)),
    celebrated: _set(json['celebrated']),
    placed: _set(json['placed']),
    reviews: _set(json['reviews']),
    chests: _set(json['chests']),
    stories: _set(json['stories']),
  );
}

class UnitMeta {
  const UnitMeta({this.schema = currentSchema, this.children = const {}});

  static const currentSchema = 2;

  final int schema;
  final Map<String, ChildUnitMeta> children;

  ChildUnitMeta of(String childId) => children[childId] ?? const ChildUnitMeta();

  Map<String, dynamic> toJson() => {'schema': schema, 'children': children.map((k, v) => MapEntry(k, v.toJson()))};

  factory UnitMeta.fromJson(Map<String, dynamic> json) => UnitMeta(
    schema: (json['schema'] as int?) ?? 0,
    children: ((json['children'] as Map<String, dynamic>?) ?? const {}).map((k, v) => MapEntry(k, ChildUnitMeta.fromJson(v as Map<String, dynamic>))),
  );
}

/// What a child has earned, as (kind, key, date) for the server. Certificates carry their date; the other sets are not
/// dated on the device, so they go with [now] (the server keeps the earliest date any phone sent).
List<({String kind, String key, DateTime earnedAt})> achievementsOf(ChildUnitMeta m, DateTime now) => [
      for (final e in m.certificates.entries) (kind: 'certificate', key: e.key, earnedAt: DateTime.tryParse('${e.value}T00:00:00Z') ?? now),
      for (final k in m.chests) (kind: 'chest', key: k, earnedAt: now),
      for (final k in m.reviews) (kind: 'review', key: k, earnedAt: now),
      for (final k in m.stories) (kind: 'story', key: k, earnedAt: now),
      for (final k in m.placed) (kind: 'placed', key: k, earnedAt: now),
    ];

/// Adds what the server knows (from any of the family's phones) to this phone's record: nothing is ever taken away, a
/// certificate keeps the earliest date, and a certificate from another phone is not celebrated again here.
ChildUnitMeta mergeAchievements(ChildUnitMeta m, Iterable<({String kind, String key, DateTime earnedAt})> items) {
  final certificates = {...m.certificates};
  final celebrated = {...m.celebrated}, chests = {...m.chests}, reviews = {...m.reviews}, stories = {...m.stories}, placed = {...m.placed};
  for (final a in items) {
    switch (a.kind) {
      case 'certificate':
        final date = dateOnly(a.earnedAt.toUtc());
        final known = certificates[a.key];
        if (known == null || date.compareTo(known) < 0) certificates[a.key] = date;
        celebrated.add(a.key);
      case 'chest':
        chests.add(a.key);
      case 'review':
        reviews.add(a.key);
      case 'story':
        stories.add(a.key);
      case 'placed':
        placed.add(a.key);
    }
  }
  return m.copyWith(certificates: certificates, celebrated: celebrated, chests: chests, reviews: reviews, stories: stories, placed: placed);
}

String dateOnly(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Migration for children who used the app before units existed (their progress is `progress.v1`, unchanged):
/// for every unit a child had already finished, the certificate counts as earned and the celebration as seen, so
/// nothing they achieved is lost and nothing is celebrated twice. Pure and idempotent: running it on its own output
/// changes nothing.
UnitMeta migrateUnitMeta({
  required UnitMeta existing,
  required List<CourseUnit> units,
  required List<ProgressRecord> progress,
  required Iterable<String> childIds,
}) {
  if (existing.schema >= UnitMeta.currentSchema) return existing;
  final children = {...existing.children};
  for (final childId in childIds) {
    final mine = progress.where((r) => r.childId == childId).toList();
    var meta = existing.of(childId);
    for (final unit in units) {
      if (unit.lessons.isEmpty) continue;
      final records = mine.where((r) => unit.lessons.any((l) => l.id == r.lessonId)).toList();
      final finished = unit.lessons.every((l) => records.any((r) => r.lessonId == l.id));
      if (!finished || meta.certificates.containsKey(unit.id)) continue;
      final when = records.map((r) => r.completedAt).reduce((a, b) => a.isAfter(b) ? a : b);
      meta = meta.copyWith(certificates: {...meta.certificates, unit.id: dateOnly(when.toLocal())}, celebrated: {...meta.celebrated, unit.id});
    }
    children[childId] = meta;
  }
  return UnitMeta(children: children);
}

class UnitMetaNotifier extends Notifier<UnitMeta> {
  @override
  UnitMeta build() {
    final raw = ref.read(sharedPreferencesProvider).readJson(PrefKeys.unitMeta);
    if (raw is Map<String, dynamic>) {
      try {
        return UnitMeta.fromJson(raw);
      } on Object {
        // unreadable: start again (the migration below rebuilds what progress proves)
      }
    }
    return const UnitMeta(schema: 0);
  }

  /// Runs the migration once (schema 0 -> 2) when the lessons are known.
  Future<void> migrateIfNeeded({required List<CourseUnit> units, required List<ProgressRecord> progress, required Iterable<String> childIds}) async {
    if (state.schema >= UnitMeta.currentSchema) return;
    state = migrateUnitMeta(existing: state, units: units, progress: progress, childIds: childIds);
    await _save();
  }

  Future<void> awardCertificate(String childId, String unitId, DateTime when) async {
    final meta = state.of(childId);
    if (meta.certificates.containsKey(unitId)) return;
    _put(childId, meta.copyWith(certificates: {...meta.certificates, unitId: dateOnly(when)}));
    await _save();
  }

  /// The treasure chest after [unitId] was opened. What it held is derived from this (see ChestInventory), never stored twice.
  Future<void> openChest(String childId, String unitId) async {
    final meta = state.of(childId);
    if (meta.chests.contains(unitId)) return;
    _put(childId, meta.copyWith(chests: {...meta.chests, unitId}));
    await _save();
  }

  /// The story after [unitId] was read to the end.
  Future<void> readStory(String childId, String unitId) async {
    final meta = state.of(childId);
    if (meta.stories.contains(unitId)) return;
    _put(childId, meta.copyWith(stories: {...meta.stories, unitId}));
    await _save();
  }

  /// A review (or the castle) on the map was passed: it opens the unit after it.
  Future<void> passReview(String childId, String reviewId) async {
    final meta = state.of(childId);
    if (meta.reviews.contains(reviewId)) return;
    _put(childId, meta.copyWith(reviews: {...meta.reviews, reviewId}));
    await _save();
  }

  /// Replaces the units counted as done by placement (the parent answered the English-level question again).
  Future<void> setPlaced(String childId, Set<String> unitIds) async {
    _put(childId, state.of(childId).copyWith(placed: unitIds));
    await _save();
  }

  Future<void> markCelebrated(String childId, String unitId) async {
    final meta = state.of(childId);
    if (meta.celebrated.contains(unitId)) return;
    _put(childId, meta.copyWith(celebrated: {...meta.celebrated, unitId}));
    await _save();
  }

  /// Brings in a child's achievements from the server (see [mergeAchievements]).
  Future<void> merge(String childId, Iterable<({String kind, String key, DateTime earnedAt})> items) async {
    final merged = mergeAchievements(state.of(childId), items);
    _put(childId, merged);
    await _save();
  }

  Future<void> removeForChild(String childId) async {
    state = UnitMeta(schema: state.schema, children: {...state.children}..remove(childId));
    await _save();
  }

  void _put(String childId, ChildUnitMeta meta) => state = UnitMeta(schema: state.schema, children: {...state.children, childId: meta});

  Future<void> _save() => ref.read(sharedPreferencesProvider).writeJson(PrefKeys.unitMeta, state.toJson());
}

final unitMetaProvider = NotifierProvider<UnitMetaNotifier, UnitMeta>(UnitMetaNotifier.new);
