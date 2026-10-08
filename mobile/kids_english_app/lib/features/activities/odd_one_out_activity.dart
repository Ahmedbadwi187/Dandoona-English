import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/palette.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../audio/activity_speech.dart';
import '../audio/audio_service.dart';
import '../content/content_models.dart';
import 'activity_logic.dart';
import 'activity_widgets.dart';

/// One round: [group] belong together, [odd] does not.
class OddRound {
  const OddRound(this.group, this.odd, this.options);
  final List<LessonWord> group;
  final LessonWord odd;
  final List<LessonWord> options; // shuffled, group + odd
}

/// Three rounds: three pictures of the unit and one picture of something else (a word of the Letters unit named in the lesson's `odd`).
List<OddRound> buildOddRounds(Lesson lesson, TrackContent track, Random random, {int rounds = 3}) {
  final unitWords = unitWordsOf(track, lesson);
  final oddWords = [
    for (final name in lesson.odd) ?track.unitById('letters')?.lessons.expand((l) => l.words).where((w) => w.word == name).firstOrNull,
  ]..shuffle(random);
  final result = <OddRound>[];
  for (var i = 0; i < rounds && i < oddWords.length; i++) {
    final pool = ([...unitWords]..shuffle(random)).where((w) => w.image != oddWords[i].image).take(3).toList();
    if (pool.length < 3) continue;
    result.add(OddRound(pool, oddWords[i], [...pool, oddWords[i]]..shuffle(random)));
  }
  return result;
}

/// Three pictures belong together and one does not: tap the one that does not belong. Every tap says the word of the picture.
class OddOneOutActivity extends ConsumerStatefulWidget {
  const OddOneOutActivity({super.key, required this.lesson, required this.track, required this.onFinished, this.random, this.nextDelay = const Duration(milliseconds: 700)});

  final Lesson lesson;
  final TrackContent track;
  final ValueChanged<ActivityResult> onFinished;
  final Random? random;
  final Duration nextDelay;

  @override
  ConsumerState<OddOneOutActivity> createState() => _OddOneOutActivityState();
}

class _OddOneOutActivityState extends ConsumerState<OddOneOutActivity> {
  late final List<OddRound> _rounds = buildOddRounds(widget.lesson, widget.track, widget.random ?? Random());
  late final ActivitySpeech _speech;
  int _index = 0;
  int _mistakes = 0;
  String? _wrong;
  String? _right;
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    _speech = ActivitySpeech(ref.read(audioServiceProvider));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_speech.say(instruction: widget.lesson.audio.instructions['odd-one-out']));
    });
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }

  Future<void> _tap(LessonWord w) async {
    if (_locked) return;
    final round = _rounds[_index];
    unawaited(_speech.say(then: w.audio));
    if (w.image == round.odd.image) {
      _locked = true;
      setState(() => _right = w.word);
      await Future<void>.delayed(widget.nextDelay);
      if (!mounted) return;
      if (_index + 1 >= _rounds.length) {
        widget.onFinished(ActivityResult(stars: starsForMistakes(_mistakes), attempts: _rounds.length + _mistakes));
        return;
      }
      setState(() {
        _index++;
        _right = null;
        _locked = false;
      });
    } else {
      _mistakes++;
      setState(() => _wrong = w.word);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mounted) setState(() => _wrong = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final round = _rounds[_index];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          RoundDots(total: _rounds.length, index: _index),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              for (final w in round.options)
                GestureDetector(
                  key: Key('odd-${w.word}'),
                  onTap: () => unawaited(_tap(w)),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(minWidth: kMinTapTarget, minHeight: kMinTapTarget),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: _right == w.word ? Palette.green : (_wrong == w.word ? Palette.red : Palette.tan), width: 6),
                    ),
                    child: AssetPicture(w.image, size: 140, semanticLabel: w.word),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
