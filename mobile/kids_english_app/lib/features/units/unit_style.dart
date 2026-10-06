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
      'body' => Icons.accessibility_new_rounded,
      'food' => Icons.bakery_dining_rounded,
      'family' => Icons.family_restroom_rounded,
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
