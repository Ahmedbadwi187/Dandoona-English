import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/features/content/content_models.dart';
import 'package:kids_english_app/features/rewards/chest_rewards.dart';

import 'helpers.dart';

/// The lessons of a pack unit as the app has them once the pack is downloaded (the newest version in the index).
List<Lesson> _packLessons(String unit) {
  final index = jsonDecode(File('../../packs/little_learners/index.json').readAsStringSync()) as Map<String, dynamic>;
  final entry = (index['packs'] as List<dynamic>).cast<Map<String, dynamic>>().firstWhere((p) => p['unit'] == unit);
  final manifest = jsonDecode(File('../../packs/little_learners/$unit/v${entry['version']}/manifest.json').readAsStringSync()) as Map<String, dynamic>;
  return [for (final l in manifest['lessons'] as List<dynamic>) Lesson.fromJson(l as Map<String, dynamic>)];
}

void main() {
  final catalog = realContent();
  // every unit that has content today, with its lessons (bundled ones from the catalog, packs as they are downloaded)
  final built = [
    for (final u in catalog.units)
      if (u.lessons.isNotEmpty) u else if (u.pack != null && Directory('../../packs/little_learners/${u.id}').existsSync()) u.withLessons(_packLessons(u.id)),
  ];

  test('the units with content are Letters, Colors, Numbers, Shapes, Animals and Feelings (update this list when a unit is built)', () {
    expect(built.map((u) => u.id), ['letters', 'colors', 'numbers', 'shapes', 'animals', 'feelings']);
  });

  test('every built unit has a complete chest: its outfit is drawn and every sticker has a picture and a voice', () {
    for (final u in built) {
      expect(u.chest, isNotNull, reason: u.id);
      expect(File('assets/images/accessories/${u.chest!.accessory}.svg').existsSync(), isTrue, reason: '${u.id}: outfit ${u.chest!.accessory} is bundled in the app');
      final stickers = stickersOfUnit(u);
      expect(stickers.length, inInclusiveRange(3, 4), reason: u.id);
      for (final s in stickers) {
        expect(s.image, isNotNull, reason: '${u.id}/${s.word} has a picture');
        expect(s.audio, isNotNull, reason: '${u.id}/${s.word} has a voice');
      }
    }
  });

  test('no two chests hold the same outfit, and the units that are not built yet already have theirs planned', () {
    final outfits = catalog.units.map((u) => u.chest!.accessory).toList();
    expect(outfits.toSet().length, outfits.length);
    expect(catalog.units.length, 15);
    expect(catalog.units.where((u) => !built.any((b) => b.id == u.id)).every((u) => u.chest != null && u.chest!.stickers.length >= 3), isTrue);
  });
}
