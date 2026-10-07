import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'content_models.dart';
import 'packs.dart';

const littleLearnersAsset = 'assets/content/little_learners.json';

Future<TrackContent> loadTrackContent(AssetBundle bundle, {String path = littleLearnersAsset}) async {
  final raw = await bundle.loadString(path);
  return TrackContent.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

final assetBundleProvider = Provider<AssetBundle>((ref) => rootBundle);

/// The Little Learners lessons: the bundled JSON (no network), with the lessons of every content pack already on this
/// device. Reloads when a pack finishes downloading.
final contentProvider = FutureProvider<TrackContent>((ref) async {
  final bundled = await loadTrackContent(ref.watch(assetBundleProvider));
  ref.watch(installedPacksProvider);
  final repo = ref.watch(packRepositoryProvider);
  if (repo == null || !bundled.units.any((u) => u.pack != null)) return bundled;
  return bundled.withUnits([
    for (final u in bundled.units)
      if (u.needsDownload) _loadPack(repo, u) ?? u else u,
  ]);
});

CourseUnit? _loadPack(PackRepository repo, CourseUnit unit) {
  try {
    return repo.load(unit);
  } on Object {
    return null; // a damaged pack reads as "not downloaded": it is fetched again
  }
}
