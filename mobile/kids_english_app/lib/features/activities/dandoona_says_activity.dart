import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/palette.dart';
import '../../core/widgets.dart';
import '../audio/activity_speech.dart';
import '../audio/audio_service.dart';
import '../content/content_models.dart';
import 'activity_logic.dart';

/// "Dandoona says, jump!": the child does the action for real. A ring fills slowly (a gentle timer, nothing is lost when it runs out);
/// the green check moves on sooner. There are no wrong answers and no scores: finishing always gives all three stars.
class DandoonaSaysActivity extends ConsumerStatefulWidget {
  const DandoonaSaysActivity({super.key, required this.lesson, required this.onFinished, this.random, this.turn = const Duration(seconds: 7)});

  final Lesson lesson;
  final ValueChanged<ActivityResult> onFinished;
  final Random? random;

  /// How long one action is given before the next one comes by itself.
  final Duration turn;

  @override
  ConsumerState<DandoonaSaysActivity> createState() => _DandoonaSaysActivityState();
}

class _DandoonaSaysActivityState extends ConsumerState<DandoonaSaysActivity> with SingleTickerProviderStateMixin {
  late final Random _random = widget.random ?? Random();
  late final List<LessonWord> _words = [for (final w in widget.lesson.words) if (w.says != null) w]..shuffle(_random);
  late final ActivitySpeech _speech;
  late final AnimationController _ring = AnimationController(vsync: this, duration: widget.turn)..addStatusListener(_ringStatus);
  int _index = 0;
  bool _finished = false;

  LessonWord get _word => _words[_index];

  @override
  void initState() {
    super.initState();
    _speech = ActivitySpeech(ref.read(audioServiceProvider));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _begin(first: true);
    });
  }

  @override
  void dispose() {
    _ring.dispose();
    _speech.cancel();
    super.dispose();
  }

  void _begin({bool first = false}) {
    unawaited(_speech.say(instruction: first ? widget.lesson.audio.instructions['dandoona-says'] : null, then: _word.says));
    _ring.forward(from: 0);
  }

  void _ringStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed) _next();
  }

  void _next() {
    if (_finished || !mounted) return;
    _ring.stop();
    if (_index + 1 >= _words.length) {
      _finished = true;
      widget.onFinished(ActivityResult(stars: 3, attempts: _words.length));
      return;
    }
    setState(() => _index++);
    _begin();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _words.length; i++)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: i <= _index ? Palette.orange : Palette.tan),
                ),
            ],
          ),
          const SizedBox(height: 20),
          GestureDetector(
            key: const Key('says-picture'),
            onTap: () => unawaited(_speech.say(then: _word.says)),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(36), border: Border.all(color: Palette.orange, width: 6)),
              child: AssetPicture(_word.image, size: 260, semanticLabel: _word.word),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _ring,
                  builder: (context, _) => SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(key: const Key('says-ring'), value: _ring.value, strokeWidth: 10, color: Palette.green, backgroundColor: Palette.tan),
                  ),
                ),
                BigTap(
                  onTap: _next,
                  semanticLabel: 'Done',
                  child: Container(
                    key: const Key('says-done'),
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(color: Palette.green, shape: BoxShape.circle, border: Border.all(color: Palette.ink, width: 4)),
                    child: const Icon(Icons.check_rounded, size: 56, color: Palette.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
