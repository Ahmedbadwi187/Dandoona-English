import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/palette.dart';
import '../audio/activity_speech.dart';
import '../audio/audio_service.dart';
import '../content/content_models.dart';
import 'activity_logic.dart';
import 'activity_widgets.dart';

const _numberNames = ['one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten'];

/// Counting for real: for each number of the lesson that many balloons float on the screen; the child touches them one by one and
/// each touch says the next number ("one", "two", "three"). Nothing can go wrong, so finishing always gives three stars.
class CountAlongActivity extends ConsumerStatefulWidget {
  const CountAlongActivity({super.key, required this.lesson, required this.track, required this.onFinished, this.nextDelay = const Duration(milliseconds: 900)});

  final Lesson lesson;
  final TrackContent track;
  final ValueChanged<ActivityResult> onFinished;
  final Duration nextDelay;

  @override
  ConsumerState<CountAlongActivity> createState() => _CountAlongActivityState();
}

class _CountAlongActivityState extends ConsumerState<CountAlongActivity> {
  late final ActivitySpeech _speech;
  late final List<LessonWord> _numbers = [for (final w in widget.lesson.words) if (Lesson.numberOf(w.word) != null) w];
  final List<int> _counted = [];
  int _index = 0;
  bool _locked = false;

  int get _n => Lesson.numberOf(_numbers[_index].word)!;

  @override
  void initState() {
    super.initState();
    _speech = ActivitySpeech(ref.read(audioServiceProvider));
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }

  Future<void> _touch(int i) async {
    if (_locked || _counted.contains(i)) return;
    setState(() => _counted.add(i));
    final name = _numberNames[_counted.length - 1];
    unawaited(_speech.say(then: wordNamed(widget.track, widget.lesson, name)?.audio));
    if (_counted.length < _n) return;
    _locked = true;
    await Future<void>.delayed(widget.nextDelay);
    if (!mounted) return;
    if (_index + 1 >= _numbers.length) {
      widget.onFinished(ActivityResult(stars: 3, attempts: _numbers.length));
    } else {
      setState(() {
        _index++;
        _counted.clear();
        _locked = false;
      });
    }
  }

  static const _colors = [Palette.red, Palette.blue, Palette.yellow, Palette.green, Palette.orange, Palette.plum];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          RoundDots(total: _numbers.length, index: _index),
          const SizedBox(height: 16),
          Container(
            key: const Key('count-number'),
            width: 120,
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Palette.white, shape: BoxShape.circle, border: Border.all(color: Palette.ink, width: 5)),
            child: Text('${_counted.length}', style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: Palette.ink)),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < _n; i++)
                GestureDetector(
                  key: Key('balloon-$i'),
                  onTap: () => unawaited(_touch(i)),
                  child: AnimatedScale(
                    scale: _counted.contains(i) ? 0.8 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: SizedBox(
                      width: 84,
                      height: 110,
                      child: Column(
                        children: [
                          Container(
                            width: 78,
                            height: 92,
                            decoration: BoxDecoration(
                              color: _counted.contains(i) ? Palette.tan : _colors[(i + _index) % _colors.length],
                              borderRadius: const BorderRadius.all(Radius.elliptical(78, 92)),
                              border: Border.all(color: Palette.ink, width: 4),
                            ),
                            alignment: Alignment.center,
                            child: _counted.contains(i) ? Text('${_counted.indexOf(i) + 1}', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Palette.ink)) : null,
                          ),
                          Container(width: 3, height: 16, color: Palette.ink),
                        ],
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
