import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../content/content_models.dart';
import '../content/content_repository.dart';
import '../profiles/child_profile.dart';
import '../units/unit_meta.dart';

/// A sticker: one word of a unit, with its picture and its voice. The picture and the audio come from the unit's own lessons
/// (bundled or from its pack), so a sticker needs no art or voice of its own; both are null while the pack is not on the phone.
class Sticker {
  const Sticker({required this.unitId, required this.word, this.image, this.audio});

  final String unitId;
  final String word;
  final String? image;
  final String? audio;

  String get key => '$unitId/$word';
}

LessonWord? _wordOf(CourseUnit unit, String word) {
  for (final l in unit.lessons) {
    for (final w in l.words) {
      if (w.word.toLowerCase() == word.toLowerCase()) return w;
    }
  }
  return null;
}

/// The stickers of [unit]'s chest, in the order of the plan (docs/chest-rewards.md).
List<Sticker> stickersOfUnit(CourseUnit unit) => [
      for (final word in unit.chest?.stickers ?? const <String>[])
        Sticker(unitId: unit.id, word: word, image: _wordOf(unit, word)?.image, audio: _wordOf(unit, word)?.audio),
    ];

/// What a child owns from chests. It is derived from the opened chests (nothing else is stored), so a child who opened a
/// chest before it held rewards gets them without doing anything.
class ChestInventory {
  const ChestInventory({required this.units, required this.opened});

  final List<CourseUnit> units;
  final Set<String> opened;

  bool isOpened(String unitId) => opened.contains(unitId);

  /// Outfit ids from the opened chests.
  Set<String> get outfits => {for (final u in units) if (u.chest != null && opened.contains(u.id)) u.chest!.accessory};

  /// The stickers of the opened chests.
  List<Sticker> get stickers => [for (final u in units) if (opened.contains(u.id)) ...stickersOfUnit(u)];

  /// Every sticker on the map, earned or not (the Sticker Book shows the missing ones as empty frames).
  List<Sticker> get allStickers => [for (final u in units) ...stickersOfUnit(u)];

  /// The unit whose chest holds the outfit [accessoryId].
  CourseUnit? unitOfOutfit(String accessoryId) {
    for (final u in units) {
      if (u.chest?.accessory == accessoryId) return u;
    }
    return null;
  }
}

/// The active child's chest inventory (empty when nobody is selected or the content is still loading).
final chestInventoryProvider = Provider<ChestInventory>((ref) {
  // An Explorers child keeps every Little Learners chest and outfit, and adds the Explorers ones.
  final little = ref.watch(contentProvider).asData?.value.units ?? const <CourseUnit>[];
  final explorers = ref.watch(activeTrackProvider) == explorersTrack ? (ref.watch(explorersContentProvider).asData?.value.units ?? const <CourseUnit>[]) : const <CourseUnit>[];
  final units = [...little, for (final u in explorers) if (!little.any((l) => l.id == u.id)) u];
  final childId = ref.watch(activeChildIdProvider);
  final opened = childId == null ? const <String>{} : ref.watch(unitMetaProvider).of(childId).chests;
  return ChestInventory(units: units, opened: opened);
});
