import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'palette.dart';

/// Dandoona's sky: a soft sky gradient with real cloud shapes that drift slowly across it. The child screens live here.
class SkyBackground extends StatefulWidget {
  const SkyBackground({super.key, required this.child, this.calm = false, this.mature = false});

  /// The Explorers (6-8) sky: the same world, a little deeper in color. Little Learners keeps the default.
  final bool mature;

  final Widget child;

  /// The quiet version behind every other screen (parent area, setup, settings): paler, fewer and fainter clouds that stand still.
  final bool calm;

  /// Tests turn the drift off (a repeating animation never lets a widget test settle).
  static bool drift = true;

  @override
  State<SkyBackground> createState() => _SkyBackgroundState();
}

class _SkyBackgroundState extends State<SkyBackground> with SingleTickerProviderStateMixin {
  // One slow lap every 3 minutes; each cloud has its own speed, height and size.
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 180));

  static const _clouds = [
    _Cloud(y: 0.08, scale: 1.0, speed: 1, phase: 0.05, opacity: 0.95),
    _Cloud(y: 0.26, scale: 0.7, speed: 2, phase: 0.55, opacity: 0.8),
    _Cloud(y: 0.52, scale: 1.2, speed: 1, phase: 0.30, opacity: 0.85),
    _Cloud(y: 0.72, scale: 0.8, speed: 3, phase: 0.80, opacity: 0.75),
    _Cloud(y: 0.90, scale: 1.1, speed: 2, phase: 0.15, opacity: 0.9),
  ];

  // Three faint clouds, high and low, for the quiet screens.
  static const _calmClouds = [
    _Cloud(y: 0.05, scale: 0.9, speed: 1, phase: 0.1, opacity: 0.55),
    _Cloud(y: 0.45, scale: 0.7, speed: 1, phase: 0.62, opacity: 0.35),
    _Cloud(y: 0.86, scale: 1.0, speed: 1, phase: 0.3, opacity: 0.4),
  ];

  @override
  void initState() {
    super.initState();
    if (SkyBackground.drift && !widget.calm) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // People who ask the phone for less motion get still clouds.
    final still = widget.calm || !SkyBackground.drift || MediaQuery.of(context).disableAnimations;
    if (still && _c.isAnimating) _c.stop();
    return DecoratedBox(
      key: Key(widget.calm ? 'sky-calm' : 'sky'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: widget.calm
              ? const [Color(0xFFDCEFF9), Color(0xFFF1F7F0), Palette.cream]
              : widget.mature
                  ? const [Color(0xFF8CC6E6), Color(0xFFCDE7F3), Color(0xFFF4EED6)]
                  : const [Color(0xFFBDE6FA), Color(0xFFE9F6FB), Palette.cream],
          stops: widget.calm ? const [0, 0.35, 0.8] : null,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: IgnorePointer(child: RepaintBoundary(child: CustomPaint(key: Key(widget.calm ? 'clouds-calm' : 'clouds'), painter: _CloudPainter(_c, widget.calm ? _calmClouds : _clouds))))),
          widget.child,
        ],
      ),
    );
  }
}

class _Cloud {
  const _Cloud({required this.y, required this.scale, required this.speed, required this.phase, required this.opacity});
  final double y; // fraction of the height
  final double scale;
  final int speed; // laps per animation lap
  final double phase; // where it starts (0..1)
  final double opacity;
}

class _CloudPainter extends CustomPainter {
  _CloudPainter(this.t, this.clouds) : super(repaint: t);

  final Animation<double> t;
  final List<_Cloud> clouds;

  static const _w = 190.0;

  @override
  void paint(Canvas canvas, Size size) {
    for (final c in clouds) {
      final w = _w * c.scale;
      final lap = (t.value * c.speed + c.phase) % 1.0;
      final x = lap * (size.width + w) - w; // enters on the left, leaves on the right
      _draw(canvas, Offset(x, size.height * c.y), c.scale, c.opacity);
    }
  }

  /// A cloud: a flat base with three overlapping puffs, and a soft shadow underneath.
  void _draw(Canvas canvas, Offset o, double s, double opacity) {
    final white = Paint()..color = Colors.white.withValues(alpha: opacity);
    final shade = Paint()..color = const Color(0xFFB9DDF0).withValues(alpha: opacity * 0.55);
    Path shape(double dy) => Path()
      ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(o.dx + 10 * s, o.dy + (34 + dy) * s, 170 * s, 36 * s), Radius.circular(18 * s)))
      ..addOval(Rect.fromCircle(center: Offset(o.dx + 62 * s, o.dy + (36 + dy) * s), radius: 30 * s))
      ..addOval(Rect.fromCircle(center: Offset(o.dx + 104 * s, o.dy + (24 + dy) * s), radius: 40 * s))
      ..addOval(Rect.fromCircle(center: Offset(o.dx + 142 * s, o.dy + (40 + dy) * s), radius: 26 * s));
    canvas.drawPath(shape(4), shade);
    canvas.drawPath(shape(0), white);
  }

  @override
  bool shouldRepaint(_CloudPainter old) => old.clouds != clouds;
}

/// Darker and lighter shades of an avatar color: the card border, the name and the badge are drawn from the same hue.
extension AvatarShades on Color {
  HSLColor get _hsl => HSLColor.fromColor(this);

  /// A mid shade for borders (never paler than the color itself would allow to be seen).
  Color get border => _hsl.withLightness(math.min(_hsl.lightness, 0.60)).withSaturation(math.max(_hsl.saturation, 0.45)).toColor();

  /// A dark shade for text.
  Color get dark => _hsl.withLightness(0.2).withSaturation(math.min(1.0, math.max(_hsl.saturation, 0.35))).toColor();

  /// A very light tint for the badge background.
  Color get tint => _hsl.withLightness(0.93).toColor();
}
