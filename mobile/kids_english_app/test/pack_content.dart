import 'package:kids_english_app/features/content/content_models.dart';

import 'helpers.dart';
import 'pack_helpers.dart';

/// The real catalog with the lessons of every pack unit read from the real packs, as the app has them once the packs are installed.
/// The pictures of a pack are downloaded files, so (when [bundledPictures]) each word gets a different picture that is bundled in the
/// app instead - one that is none of the Letters words the odd-one-out lessons use - so widgets can be pumped in a test.
TrackContent contentWithPacks({bool bundledPictures = true}) {
  final real = realContent();
  const reserved = {'apple', 'ball', 'car', 'hat', 'key', 'cat', 'tree', 'egg', 'fish', 'banana'};
  final spare = {
    for (final w in real.lessons.expand((l) => l.words))
      if (!reserved.contains(w.word)) w.image,
  }.toList();
  var n = 0;
  Lesson remap(Lesson l) {
    if (!bundledPictures) return l;
    final json = {
      'id': l.id,
      'order': l.order,
      'level': l.level,
    };
    // go through the manifest JSON so every field (bins, odd, groups...) is kept exactly as exported
    final raw = [for (final m in packManifestsLessons()) if (m['id'] == l.id) m].first;
    return Lesson.fromJson({
      ...raw,
      ...json,
      'words': [for (final w in raw['words'] as List<dynamic>) {...(w as Map<String, dynamic>), 'image': spare[n++ % spare.length]}],
    });
  }

  final units = <CourseUnit>[];
  for (final u in real.units) {
    if (u.lessons.isEmpty && hasPack(u.id)) {
      units.add(u.withLessons([for (final l in packLessons(u.id)) remap(l)]));
    } else {
      units.add(u);
    }
  }
  return real.withUnits(units);
}

List<Map<String, dynamic>> packManifestsLessons() => [
      for (final u in realContent().units)
        if (hasPack(u.id)) ...(packManifest(u.id)['lessons'] as List<dynamic>).cast<Map<String, dynamic>>(),
    ];
