import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/palette.dart';

/// The small drawings of the unit map, painted in palette colors (no image files): the progress ring, the treasure chest,
/// the wardrobe button and the dashed path.

/// A ring around the current island's icon circle that fills as lessons are done.
class ProgressRingPainter extends CustomPainter {
  const ProgressRingPainter({required this.value, this.track = Palette.white, this.fill = Palette.green, this.width = 8});

  final double value; // 0..1
  final Color track;
  final Color fill;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(width / 2);
    final back = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    final front = Paint()
      ..color = fill
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    final edge = Paint()
      ..color = Palette.nightInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawOval(r, back);
    if (value > 0) canvas.drawArc(r, -math.pi / 2, 2 * math.pi * value.clamp(0, 1), false, front);
    canvas.drawOval(rect.deflate(1.25), edge);
    canvas.drawOval(rect.deflate(width + 1.25), edge);
  }

  @override
  bool shouldRepaint(ProgressRingPainter old) => old.value != value || old.fill != fill || old.track != track;
}

/// A treasure chest: closed (waiting), closed and shining (ready to open) or open with a glint inside.
class ChestPainter extends CustomPainter {
  const ChestPainter({required this.open, this.muted = false});

  final bool open;
  final bool muted;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    Color c(Color x) => muted ? Color.lerp(x, Palette.white, 0.5)! : x;
    final ink = Paint()
      ..color = c(Palette.nightInk)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.06
      ..strokeJoin = StrokeJoin.round;
    final wood = Paint()..color = c(Palette.brown);
    final gold = Paint()..color = c(Palette.sunflower);

    final body = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.08, h * 0.46, w * 0.84, h * 0.44), Radius.circular(w * 0.06));
    if (open) {
      // the lid stands up behind, and the treasure shows
      final lid = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.10, h * 0.10, w * 0.80, h * 0.30), Radius.circular(w * 0.10));
      canvas.drawRRect(lid, wood);
      canvas.drawRRect(lid, ink);
      canvas.drawOval(Rect.fromLTWH(w * 0.18, h * 0.36, w * 0.64, h * 0.22), gold);
      canvas.drawCircle(Offset(w * 0.38, h * 0.42), w * 0.06, Paint()..color = c(Palette.pink));
      canvas.drawCircle(Offset(w * 0.60, h * 0.40), w * 0.05, Paint()..color = c(Palette.teal));
    } else {
      final lid = Path()
        ..moveTo(w * 0.08, h * 0.48)
        ..lineTo(w * 0.08, h * 0.34)
        ..quadraticBezierTo(w * 0.50, h * 0.08, w * 0.92, h * 0.34)
        ..lineTo(w * 0.92, h * 0.48)
        ..close();
      canvas.drawPath(lid, wood);
      canvas.drawPath(lid, ink);
    }
    canvas.drawRRect(body, wood);
    canvas.drawRRect(body, ink);
    // metal bands and the lock plate
    final band = Paint()..color = c(Palette.sunflower);
    canvas.drawRect(Rect.fromLTWH(w * 0.20, h * 0.46, w * 0.08, h * 0.44), band);
    canvas.drawRect(Rect.fromLTWH(w * 0.72, h * 0.46, w * 0.08, h * 0.44), band);
    final plate = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w * 0.5, h * 0.56), width: w * 0.20, height: h * 0.22), Radius.circular(w * 0.04));
    canvas.drawRRect(plate, gold);
    canvas.drawRRect(plate, ink..strokeWidth = w * 0.045);
  }

  @override
  bool shouldRepaint(ChestPainter old) => old.open != open || old.muted != muted;
}

/// A little wardrobe with two doors (the button that opens Dandoona's wardrobe).
class WardrobePainter extends CustomPainter {
  const WardrobePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final ink = Paint()
      ..color = Palette.nightInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.07
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final body = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.14, h * 0.06, w * 0.72, h * 0.80), Radius.circular(w * 0.10));
    canvas.drawRRect(body, Paint()..color = Palette.plum);
    // the doors, a little lighter
    final door = Paint()..color = Color.lerp(Palette.plum, Palette.white, 0.35)!;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.22, h * 0.14, w * 0.25, h * 0.64), Radius.circular(w * 0.05)), door);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.53, h * 0.14, w * 0.25, h * 0.64), Radius.circular(w * 0.05)), door);
    canvas.drawRRect(body, ink);
    canvas.drawLine(Offset(w * 0.5, h * 0.10), Offset(w * 0.5, h * 0.82), ink);
    // handles
    final knob = Paint()..color = Palette.sunflower;
    canvas.drawCircle(Offset(w * 0.42, h * 0.46), w * 0.055, knob);
    canvas.drawCircle(Offset(w * 0.58, h * 0.46), w * 0.055, knob);
    // feet
    canvas.drawLine(Offset(w * 0.24, h * 0.86), Offset(w * 0.24, h * 0.95), ink);
    canvas.drawLine(Offset(w * 0.76, h * 0.86), Offset(w * 0.76, h * 0.95), ink);
  }

  @override
  bool shouldRepaint(WardrobePainter old) => false;
}

/// The dashed path through every stop's center, as soft curves.
class SkyPathPainter extends CustomPainter {
  SkyPathPainter(this.centers);

  final List<Offset> centers;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Palette.white.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < centers.length - 1; i++) {
      final a = centers[i], b = centers[i + 1];
      final mid = (a.dy + b.dy) / 2;
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..cubicTo(a.dx, mid, b.dx, mid, b.dx, b.dy);
      for (final m in path.computeMetrics()) {
        for (double d = 0; d < m.length; d += 22) {
          canvas.drawPath(m.extractPath(d, math.min(d + 10, m.length)), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(SkyPathPainter old) => old.centers != centers;
}
