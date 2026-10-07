import 'package:flutter/material.dart';

import '../../core/palette.dart';

/// How a unit looks on the map. The unit file (content) only names an icon key and a palette color; unknown names fall
/// back to a star and orange, so a new unit never needs a code change to show up.
IconData unitIcon(String key) => switch (key) {
  'letters' => Icons.abc_rounded,
  'colors' => Icons.palette_rounded,
  'numbers' => Icons.looks_one_rounded,
  'shapes' => Icons.category_rounded,
  'animals' => Icons.pets_rounded,
  'feelings' => Icons.emoji_emotions_rounded,
  'body' => Icons.accessibility_new_rounded,
  'actions' => Icons.directions_run_rounded,
  'food' => Icons.bakery_dining_rounded,
  'clothes' => Icons.checkroom_rounded,
  'toys' => Icons.toys_rounded,
  'family' => Icons.family_restroom_rounded,
  'home' => Icons.house_rounded,
  'opposites' => Icons.swap_horiz_rounded,
  'transport' => Icons.directions_bus_rounded,
  _ => Icons.star_rounded,
};

Color unitColor(String name) => switch (name) {
  'red' => Palette.red,
  'orange' => Palette.orange,
  'yellow' => Palette.yellow,
  'green' => Palette.green,
  'teal' => Palette.teal,
  'blue' => Palette.blue,
  'purple' => Palette.purple,
  'pink' => Palette.pink,
  'brown' => Palette.brown,
  _ => Palette.orange,
};

/// The soft tint of a unit color for the island's grass (open islands).
Color softTint(Color c) => Color.lerp(c, Palette.white, 0.30)!;

/// A muted, paler version for islands the child has not reached yet: still the unit's own color, so the map stays colorful.
Color mutedTint(Color c, {double amount = 0.55}) {
  final hsl = HSLColor.fromColor(c);
  return Color.lerp(hsl.withSaturation(hsl.saturation * 0.7).toColor(), Palette.white, amount)!;
}
