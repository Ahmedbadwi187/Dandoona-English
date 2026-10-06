import 'package:flutter/material.dart';

import 'palette.dart';

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
    scaffoldBackgroundColor: Palette.cream,
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.cream,
      foregroundColor: Palette.ink,
      elevation: 0,
      centerTitle: true,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(kMinTapTarget, kMinTapTarget),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(kMinTapTarget, kMinTapTarget),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: const BorderSide(color: Palette.ink, width: 2),
        foregroundColor: Palette.ink,
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
