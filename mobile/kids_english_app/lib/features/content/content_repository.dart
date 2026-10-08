import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'content_models.dart';
import 'packs.dart';
import '../profiles/child_profile.dart';

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

// ---- Tracks ---------------------------------------------------------------------------------------------------------
// Little Learners (3-5) is [contentProvider], unchanged. Explorers (6-8) has its own catalog; a child uses the catalog of
// their track. Screens in the child area read [activeContentProvider]; the parent area, which shows several children,
// reads [trackContentProvider] with each child's track.

const littleLearnersTrack = 'little-learners';
const explorersTrack = 'explorers';
const explorersAsset = 'assets/content/explorers.json';

/// Explorers (6-8) is part of the app unless it is built out: `flutter build ... --dart-define=ENABLE_EXPLORERS=false` makes a
/// Little Learners only release (the Explorers catalog stays in the files but nothing in the app offers, chooses or opens it).
const explorersEnabled = bool.fromEnvironment('ENABLE_EXPLORERS', defaultValue: true);

/// The tracks that have lessons in this app.
const availableTracks = explorersEnabled ? {littleLearnersTrack, explorersTrack} : {littleLearnersTrack};

/// The Explorers lessons, read from the bundled JSON (no network). Its Letters unit is the Little Learners one (same
/// lessons and files), so a child who already knows them keeps that progress.
final explorersContentProvider = FutureProvider<TrackContent>((ref) => loadTrackContent(ref.watch(assetBundleProvider), path: explorersAsset));

/// The catalog of a track; an unknown track reads as Little Learners.
final trackContentProvider = FutureProvider.family<TrackContent, String>((ref, track) =>
    explorersEnabled && track == explorersTrack ? ref.watch(explorersContentProvider.future) : ref.watch(contentProvider.future));

/// The track of the child who is playing (Little Learners when nobody is chosen yet).
final activeTrackProvider = Provider<String>((ref) {
  final id = ref.watch(activeChildIdProvider);
  final child = ref.watch(profilesProvider).where((p) => p.id == id).firstOrNull;
  return explorersEnabled ? (child?.track ?? littleLearnersTrack) : littleLearnersTrack;
});

/// The catalog of the child who is playing.
final activeContentProvider = FutureProvider<TrackContent>((ref) => ref.watch(trackContentProvider(ref.watch(activeTrackProvider)).future));
