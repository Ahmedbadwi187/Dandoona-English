import 'package:flutter/material.dart';

import 'palette.dart';
import 'type.dart';

/// Minimum tap target for the child area (the 3-5 track needs large targets).
const double kMinTapTarget = 64;

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Palette.plum,
    brightness: Brightness.light,
    surface: Palette.cream,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    // Transparent: the quiet sky behind every screen (see SkyBackground.calm) shows through.
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Palette.ink,
      elevation: 0,
      centerTitle: true,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(kMinTapTarget, kMinTapTarget),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: parentSubtitle.copyWith(fontWeight: FontWeight.w700), // child screens give their buttons kidTitle themselves
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(kMinTapTarget, kMinTapTarget),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: const BorderSide(color: Palette.ink, width: 2),
        foregroundColor: Palette.ink,
        textStyle: parentSubtitle.copyWith(fontWeight: FontWeight.w700), // child screens give their buttons kidTitle themselves
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Palette.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    ),
    cardTheme: CardThemeData(
      color: Palette.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Palette.tan, width: 2),
      ),
    ),
  );
}
