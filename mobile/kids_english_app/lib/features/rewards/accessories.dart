import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/widgets.dart';

/// Mascot accessories earned with stars. The art is self-drawn SVG (content/art/accessories, exported by the
/// asset tool) positioned to fit the mascot's square frame.
class Accessory {
  const Accessory(this.id, this.unlockStars);

  final String id;
  final int unlockStars;

  String get assetPath => 'assets/images/accessories/$id.svg';
}

const List<Accessory> accessories = [
  Accessory('party-hat', 5),
  Accessory('glasses', 15),
  Accessory('bow', 30),
  Accessory('crown', 50),
  Accessory('bowtie', 80),
];

Accessory? accessoryById(String? id) {
  for (final a in accessories) {
    if (a.id == id) return a;
  }
  return null;
}

/// Any outfit by id: a star outfit, or one from a treasure chest (those come from the units file; their drawing is
/// `assets/images/accessories/<id>.svg` and they never unlock by stars, see ChestInventory).
Accessory? outfitById(String? id) => id == null ? null : (accessoryById(id) ?? Accessory(id, 0));

bool isUnlocked(Accessory a, int totalStars) => totalStars >= a.unlockStars;

/// Accessories whose threshold was crossed when the star total went from [before] to [after].
List<Accessory> newlyUnlocked(int before, int after) =>
    accessories.where((a) => before < a.unlockStars && after >= a.unlockStars).toList();

/// The mascot with the child's chosen accessory on top. The overlay is not clipped, so it may sit on the head.
class MascotStage extends StatelessWidget {
  const MascotStage({super.key, required this.mascotAsset, required this.size, this.accessoryId, this.markWorn = true});

  final String mascotAsset;
  final double size;
  final String? accessoryId;

  /// Only the big stage carries the `worn-<id>` key (thumbnails would duplicate it).
  final bool markWorn;

  @override
  Widget build(BuildContext context) {
    final accessory = outfitById(accessoryId);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          AssetPicture(mascotAsset, size: size),
          if (accessory != null)
            Positioned.fill(
              child: SvgPicture.asset(accessory.assetPath, key: markWorn ? Key('worn-${accessory.id}') : null, fit: BoxFit.contain),
            ),
        ],
      ),
    );
  }
}
