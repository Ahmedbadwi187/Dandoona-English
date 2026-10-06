import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../content/content_repository.dart';
import '../profiles/child_profile.dart';
import '../progress/progress.dart';
import 'unit_meta.dart';

/// Runs the one-time migration of local progress to units (see [migrateUnitMeta]) as soon as the lessons are loaded.
/// Screens that show unit state wait for it, so a child who had finished Letters never sees it as unfinished.
final unitMigrationProvider = FutureProvider<void>((ref) async {
  final track = await ref.watch(contentProvider.future);
  await ref.read(unitMetaProvider.notifier).migrateIfNeeded(
        units: track.units,
        progress: ref.read(progressProvider),
        childIds: ref.read(profilesProvider).map((c) => c.id),
      );
});
