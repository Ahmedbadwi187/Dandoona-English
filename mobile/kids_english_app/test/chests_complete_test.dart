import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/features/rewards/chest_rewards.dart';

import 'helpers.dart';
import 'pack_helpers.dart';

void main() {
  final catalog = realContent();
  // every unit that has content today, with its lessons (bundled ones from the catalog, packs as they are downloaded)
  final built = [
    for (final u in catalog.units)
      if (u.lessons.isNotEmpty) u else if (u.pack != null && hasPack(u.id)) u.withLessons(packLessons(u.id)),
  ];

  test('the units with content are all fifteen (update this list if a unit is added)', () {
    expect(built.map((u) => u.id), ['letters', 'colors', 'numbers', 'shapes', 'animals', 'feelings', 'my-body', 'actions', 'food', 'clothes', 'toys', 'my-family', 'my-home', 'opposites', 'transport']);
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
