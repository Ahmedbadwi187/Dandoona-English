import 'package:flutter/material.dart';

/// Mirrors /content/style/palette.json (the same colors the self-drawn SVGs and the OpenAI prompts use).
abstract final class Palette {
  static const cream = Color(0xFFFDF8E6);
  static const white = Color(0xFFFFFFFF);
  static const ink = Color(0xFF5A3A28);
  static const brown = Color(0xFFB8733F);
  static const tan = Color(0xFFF3D9AE);
  static const orange = Color(0xFFF0953A);
  static const yellow = Color(0xFFF7CF3E);
  static const green = Color(0xFF7DBE45);
  static const darkGreen = Color(0xFF4C9A3C);
  static const teal = Color(0xFF43B3B0);
  static const blue = Color(0xFF4A90D9);
  static const purple = Color(0xFF8E6BBF);
  static const pink = Color(0xFFF08FA5);
  static const red = Color(0xFFE5524A);
  static const gray = Color(0xFFB8B8B8);

  /// Colors cycled through for the letter map nodes.
  static const nodeColors = [red, orange, yellow, green, teal, blue, purple, pink];
}
