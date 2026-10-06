import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/palette.dart';
import '../../core/widgets.dart';
import '../audio/activity_speech.dart';
import '../audio/audio_service.dart';
import '../content/content_models.dart';
import '../content/content_repository.dart';
import 'activity_logic.dart';

/// The placeholder in a lesson's `colorable.svg` that the chosen color replaces.
const fillPlaceholder = '#FILLME';

/// What the drawing looks like before it is colored in (a light neutral, so every color shows).
const _unfilled = '#E9E4D6';

Color colorFromHex(String hex) => Color(int.parse(hex.substring(1), radix: 16) | 0xFF000000);

/// One color the child can pick: its name, #RRGGBB value and the clip that says its name.
class ColorChoice {
  const ColorChoice({required this.name, required this.hex, required this.audio});
  final String name;
  final String hex;
  final String audio;
}

/// The lesson's own color plus up to [count] - 1 other colors of the same unit, shuffled.
List<ColorChoice> buildColorChoices(Lesson lesson, TrackContent track, Random random, {int count = 4}) {
  final own = lesson.color!;
  final unit = track.unitOfLesson(lesson.id);
  final others = [
    for (final l in unit?.lessons ?? const <Lesson>[])
      if (l.id != lesson.id && l.color != null && l.audio.colorName != null)
        ColorChoice(name: l.color!.name, hex: l.color!.hex, audio: l.audio.colorName!),
  ]..shuffle(random);
  return [
    ColorChoice(name: own.name, hex: own.hex, audio: lesson.audio.colorName ?? lesson.audio.intro),
    ...others.take(count - 1),
  ]..shuffle(random);
}

/// Pick a color, then tap the drawing to fill it. Dandoona says which color to use; picking a color says its name.
/// A wrong color is not scolded: the drawing stays empty and the right color's name is said again.
class ColorTheObjectActivity extends ConsumerStatefulWidget {
  const ColorTheObjectActivity({
    super.key,
    required this.lesson,
    required this.track,
    required this.onFinished,
    this.random,
    this.hintAfter = const Duration(seconds: 8),
    this.finishDelay = const Duration(milliseconds: 1400),
  });

  final Lesson lesson;
  final TrackContent track;
  final ValueChanged<ActivityResult> onFinished;
  final Random? random;

  /// After this long without a tap, the right color lights up and its name is said.
  final Duration hintAfter;
  final Duration finishDelay;

  @override
  ConsumerState<ColorTheObjectActivity> createState() => _ColorTheObjectActivityState();
}

class _ColorTheObjectActivityState extends ConsumerState<ColorTheObjectActivity> {
  late final LessonColor _target = widget.lesson.color!;
  late final List<ColorChoice> _choices = buildColorChoices(widget.lesson, widget.track, widget.random ?? Random());
  late final ActivitySpeech _speech = ActivitySpeech(ref.read(audioServiceProvider));
  late final IdleHint _idle = IdleHint(widget.hintAfter, _showHint);

  String? _template;
  String? _selected; // color name
  String? _filledHex;
  String? _wrong; // color name flashing red
  bool _hinting = false;
  bool _done = false;
  int _mistakes = 0;

  ColorChoice get _right => _choices.firstWhere((c) => c.name == _target.name);

  @override
  void initState() {
    super.initState();
    unawaited(_loadDrawing());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _sayInstruction();
      _idle.arm();
    });
  }

  Future<void> _loadDrawing() async {
    try {
      final svg = await ref.read(assetBundleProvider).loadString('assets/${_target.drawing}', cache: false);
      if (mounted) setState(() => _template = svg);
    } on Object catch (e) {
      debugPrint('color-the-object: could not load ${_target.drawing}: $e');
      // A missing drawing leaves an empty board; the activity cannot be finished, so report a neutral result.
      if (mounted) widget.onFinished(const ActivityResult(stars: 1, attempts: 1));
    }
  }

  @override
  void dispose() {
    _idle.cancel();
    _speech.cancel();
    super.dispose();
  }

  void _sayInstruction() => unawaited(_speech.say(instruction: widget.lesson.audio.instructions['color-the-object']));

  /// Nothing happened for a while: light up the right color and say its name.
  void _showHint() {
    if (!mounted || _done) return;
    setState(() => _hinting = true);
    unawaited(_speech.say(then: _right.audio));
    _idle.arm();
  }

  void _pick(ColorChoice c) {
    if (_done) return;
    setState(() {
      _selected = c.name;
      _hinting = false;
    });
    unawaited(_speech.say(then: c.audio));
    _idle.arm();
  }

  Future<void> _tapDrawing() async {
    if (_done || _template == null) return;
    _idle.arm();
    final picked = _selected;
    if (picked == null) {
      // Not picked yet: say the instruction again (the swatches are what to tap).
      setState(() => _hinting = true);
      _sayInstruction();
      return;
    }
    if (picked == _target.name) {
      _done = true;
      _idle.cancel();
      setState(() {
        _filledHex = _target.hex;
        _hinting = false;
      });
      unawaited(_speech.say(then: _right.audio));
      await Future<void>.delayed(widget.finishDelay);
      if (mounted) widget.onFinished(ActivityResult(stars: starsForMistakes(_mistakes), attempts: 1 + _mistakes));
    } else {
      _mistakes++;
      setState(() {
        _wrong = picked;
        _selected = null;
      });
      unawaited(_speech.say(then: _right.audio));
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (mounted) setState(() => _wrong = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final template = _template;
    final shownHex = _filledHex;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          BigTap(
            onTap: _sayInstruction,
            semanticLabel: 'Hear the instruction again',
            child: Container(
              key: const Key('hear-instruction'),
              width: 88,
              height: 88,
              decoration: BoxDecoration(color: Palette.blue, shape: BoxShape.circle, border: Border.all(color: Palette.ink, width: 4)),
              child: const Icon(Icons.volume_up_rounded, size: 52, color: Palette.white),
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            key: const Key('color-drawing'),
            behavior: HitTestBehavior.opaque,
            onTap: _tapDrawing,
            child: Container(
              width: 300,
              height: 300,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Palette.white,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: shownHex != null ? Palette.green : Palette.tan, width: 6),
              ),
              child: template == null
                  ? const SizedBox.shrink()
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      child: SvgPicture.string(
                        template.replaceAll(fillPlaceholder, shownHex ?? _unfilled),
                        key: Key('drawing-${shownHex ?? 'empty'}'),
                        semanticsLabel: widget.lesson.color!.name,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 18,
            runSpacing: 18,
            alignment: WrapAlignment.center,
            children: [
              for (final c in _choices)
                BigTap(
                  key: Key('swatch-${c.name}'),
                  semanticLabel: c.name,
                  onTap: () => _pick(c),
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: colorFromHex(c.hex),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _wrong == c.name
                            ? Palette.red
                            : _selected == c.name
                                ? Palette.yellow
                                : _hinting && c.name == _target.name
                                    ? Palette.orange
                                    : Palette.ink,
                        width: _selected == c.name || _wrong == c.name || (_hinting && c.name == _target.name) ? 9 : 4,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
