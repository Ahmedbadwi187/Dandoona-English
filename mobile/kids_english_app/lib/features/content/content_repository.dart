import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'content_models.dart';

const littleLearnersAsset = 'assets/content/little_learners.json';

Future<TrackContent> loadTrackContent(AssetBundle bundle, {String path = littleLearnersAsset}) async {
  final raw = await bundle.loadString(path);
  return TrackContent.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

final assetBundleProvider = Provider<AssetBundle>((ref) => rootBundle);

/// The Little Learners lessons, read from the bundled JSON (no network).
final contentProvider = FutureProvider<TrackContent>(
  (ref) => loadTrackContent(ref.watch(assetBundleProvider)),
);
