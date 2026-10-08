import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/palette.dart';
import '../../core/theme.dart';
import '../audio/activity_speech.dart';
import '../audio/audio_service.dart';
import '../content/content_models.dart';
import 'activity_logic.dart';

const double _rasterSide = 240; // pixels the glyph and ink are rasterised at for scoring
const int _cell = 6;

void _paintGlyph(Canvas canvas, Size size, String letter, Color color) {
  final painter = TextPainter(
    text: TextSpan(
      text: letter,
      style: TextStyle(fontSize: size.height * 0.86, fontWeight: FontWeight.w900, color: color, height: 1.0),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, Offset((size.width - painter.width) / 2, (size.height - painter.height) / 2));
}

void _paintInk(Canvas canvas, List<List<Offset>> strokes, Color color, double width) {
  final paint = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  for (final stroke in strokes) {
    if (stroke.length == 1) {
      canvas.drawCircle(stroke.first, width / 2, Paint()..color = color);
      continue;
    }
    final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
    for (final p in stroke.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.letter);
  final String letter;
  @override
  void paint(Canvas canvas, Size size) => _paintGlyph(canvas, size, letter, Palette.tan);
  @override
  bool shouldRepaint(_GlyphPainter old) => old.letter != letter;
}

class _InkPainter extends CustomPainter {
  _InkPainter(this.strokes, this.width, this.version);
  final List<List<Offset>> strokes;
  final double width;
  final int version; // strokes are mutated in place, so repaint is driven by a counter
  @override
  void paint(Canvas canvas, Size size) => _paintInk(canvas, strokes, Palette.orange, width);
  @override
  bool shouldRepaint(_InkPainter old) => old.version != version || old.width != width;
}

/// Trace the big letter with a finger. The letter and the drawing are rasterised and compared (coverage of the
/// letter vs. ink far away from it). Too little ink: the board clears for another try; after 3 tries it gives 1 star.
class TraceActivity extends ConsumerStatefulWidget {
  const TraceActivity({super.key, required this.lesson, required this.onFinished, this.small = false});

  final Lesson lesson;
  final ValueChanged<ActivityResult> onFinished;

  /// Trace the small letter (a, b, c) instead of the capital (A, B, C).
  final bool small;

  @override
  ConsumerState<TraceActivity> createState() => _TraceActivityState();
}

class _TraceActivityState extends ConsumerState<TraceActivity> {
  late final ActivitySpeech _speech = ActivitySpeech(ref.read(audioServiceProvider));
  final List<List<Offset>> _strokes = [];
  int _version = 0;
  int _attempts = 0;
  bool _busy = false;
  bool _tryAgain = false;

  String get _letter => widget.small ? (widget.lesson.letter ?? '?').toLowerCase() : (widget.lesson.letter ?? '?');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sayInstruction());
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }

  void _sayInstruction() {
    if (mounted) unawaited(_speech.say(instruction: widget.lesson.audio.instructions[widget.small ? 'trace-small' : 'trace']));
  }

  void _clear() => setState(() {
        _strokes.clear();
        _version++;
      });

  Future<List<bool>> _mask(void Function(Canvas canvas) draw) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    draw(canvas);
    final image = await recorder.endRecording().toImage(_rasterSide.toInt(), _rasterSide.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return maskFromRgba(data!.buffer.asUint8List(), _rasterSide.toInt(), _rasterSide.toInt(), cell: _cell);
  }

  Future<void> _check(double side) async {
    if (_busy || _strokes.isEmpty) return;
    setState(() => _busy = true);
    final scale = _rasterSide / side;
    final glyph = await _mask((c) => _paintGlyph(c, const Size(_rasterSide, _rasterSide), _letter, Colors.black));
    final ink = await _mask((c) {
      c.scale(scale);
      _paintInk(c, _strokes, Colors.black, side * 0.11);
    });
    final score = scoreTrace(glyph: glyph, ink: ink, cols: (_rasterSide / _cell).ceil());
    _attempts++;
    if (!mounted) return;
    if (score.stars > 0 || _attempts >= 3) {
      widget.onFinished(ActivityResult(stars: score.stars == 0 ? 1 : score.stars, attempts: _attempts));
    } else {
      setState(() {
        _busy = false;
        _tryAgain = true;
        _strokes.clear();
        _version++;
      });
      unawaited(_speech.say(instruction: widget.lesson.audio.instructions['hint']));
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = [constraints.maxWidth - 32, constraints.maxHeight - 140, 420.0].reduce((a, b) => a < b ? a : b).clamp(180.0, 420.0);
        return Column(
          children: [
            const SizedBox(height: 8),
            Container(
              key: const Key('trace-board'),
              width: side,
              height: side,
              decoration: BoxDecoration(
                color: Palette.white,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: _tryAgain ? Palette.red : Palette.ink, width: 4),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: GestureDetector(
                  onPanStart: (d) => setState(() {
                    _tryAgain = false;
                    _strokes.add([d.localPosition]);
                    _version++;
                  }),
                  onPanUpdate: (d) => setState(() {
                    _strokes.last.add(d.localPosition);
                    _version++;
                  }),
                  child: CustomPaint(
                    painter: _GlyphPainter(_letter),
                    foregroundPainter: _InkPainter(_strokes, side * 0.11, _version),
                    size: Size(side, side),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filled(
                  key: const Key('trace-hear'),
                  style: IconButton.styleFrom(backgroundColor: Palette.blue, minimumSize: const Size(kMinTapTarget, kMinTapTarget)),
                  iconSize: 36,
                  onPressed: _sayInstruction,
                  icon: const Icon(Icons.volume_up_rounded, color: Palette.white),
                ),
                const SizedBox(width: 24),
                IconButton.filled(
                  key: const Key('trace-clear'),
                  style: IconButton.styleFrom(backgroundColor: Palette.gray, minimumSize: const Size(kMinTapTarget, kMinTapTarget)),
                  iconSize: 36,
                  onPressed: _busy ? null : _clear,
                  icon: const Icon(Icons.refresh_rounded, color: Palette.white),
                ),
                const SizedBox(width: 32),
                IconButton.filled(
                  key: const Key('trace-done'),
                  style: IconButton.styleFrom(backgroundColor: Palette.green, minimumSize: const Size(kMinTapTarget * 1.3, kMinTapTarget * 1.3)),
                  iconSize: 44,
                  onPressed: _busy || _strokes.isEmpty ? null : () => unawaited(_check(side)),
                  icon: const Icon(Icons.check_rounded, color: Palette.white),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
