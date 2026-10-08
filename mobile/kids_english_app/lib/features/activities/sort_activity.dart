import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/palette.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../audio/activity_speech.dart';
import '../audio/audio_service.dart';
import '../content/content_models.dart';
import 'activity_logic.dart';
import 'activity_widgets.dart';

/// Which words are sorted: words of the whole unit whose `group` is one of the lesson's bins, a few of each bin first so that every
/// bin is used, at most [count] in all, in random order.
List<LessonWord> pickSortWords(Lesson lesson, TrackContent track, Random random, {int count = 5}) {
  final binKeys = [for (final b in lesson.bins) b.key];
  final byBin = {for (final k in binKeys) k: [for (final w in unitWordsOf(track, lesson)) if (w.group == k) w]..shuffle(random)};
  final picked = <LessonWord>[];
  for (var round = 0; picked.length < count; round++) {
    var added = false;
    for (final k in binKeys) {
      if (picked.length < count && round < byBin[k]!.length) {
        picked.add(byBin[k]![round]);
        added = true;
      }
    }
    if (!added) break;
  }
  return picked..shuffle(random);
}

/// Drag the picture into the bin it belongs to (or tap the bin). A wrong bin shakes the picture back and costs a star; the right one
/// says the word and the next picture comes.
class SortActivity extends ConsumerStatefulWidget {
  const SortActivity({super.key, required this.lesson, required this.track, required this.onFinished, this.random, this.nextDelay = const Duration(milliseconds: 500)});

  final Lesson lesson;
  final TrackContent track;
  final ValueChanged<ActivityResult> onFinished;
  final Random? random;
  final Duration nextDelay;

  @override
  ConsumerState<SortActivity> createState() => _SortActivityState();
}

class _SortActivityState extends ConsumerState<SortActivity> {
  late final List<LessonWord> _words = pickSortWords(widget.lesson, widget.track, widget.random ?? Random());
  late final ActivitySpeech _speech;
  int _index = 0;
  int _mistakes = 0;
  String? _wrongBin;
  String? _rightBin;
  bool _locked = false;

  LessonWord get _word => _words[_index];

  @override
  void initState() {
    super.initState();
    _speech = ActivitySpeech(ref.read(audioServiceProvider));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_speech.say(instruction: widget.lesson.audio.instructions['sort'], then: _word.audio));
    });
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }

  Future<void> _drop(LessonBin bin) async {
    if (_locked) return;
    if (bin.key == _word.group) {
      _locked = true;
      setState(() => _rightBin = bin.key);
      await Future.wait([_speech.say(then: _word.audio), Future<void>.delayed(widget.nextDelay)]);
      if (!mounted) return;
      if (_index + 1 >= _words.length) {
        widget.onFinished(ActivityResult(stars: starsForMistakes(_mistakes), attempts: _words.length + _mistakes));
        return;
      }
      setState(() {
        _index++;
        _rightBin = null;
        _locked = false;
      });
      unawaited(_speech.say(then: _word.audio));
    } else {
      _mistakes++;
      setState(() => _wrongBin = bin.key);
      unawaited(_speech.say(then: _word.audio));
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mounted) setState(() => _wrongBin = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final picture = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), border: Border.all(color: Palette.ink, width: 5)),
      child: AssetPicture(_word.image, size: 180, semanticLabel: _word.word),
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          RoundDots(total: _words.length, index: _index),
          const SizedBox(height: 16),
          Draggable<LessonWord>(
            key: const Key('sort-picture'),
            data: _word,
            feedback: Material(color: Colors.transparent, child: Opacity(opacity: 0.9, child: picture)),
            childWhenDragging: Opacity(opacity: 0.3, child: picture),
            child: GestureDetector(onTap: () => unawaited(_speech.say(then: _word.audio)), child: picture),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            alignment: WrapAlignment.center,
            children: [
              for (final (i, bin) in widget.lesson.bins.indexed)
                DragTarget<LessonWord>(
                  onAcceptWithDetails: (_) => unawaited(_drop(bin)),
                  builder: (context, candidates, _) => GestureDetector(
                    key: Key('bin-${bin.key}'),
                    onTap: () => unawaited(_drop(bin)),
                    child: Container(
                      width: 150,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      constraints: const BoxConstraints(minHeight: kMinTapTarget),
                      decoration: BoxDecoration(
                        color: binColor(i).withValues(alpha: candidates.isEmpty ? 0.25 : 0.55),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: _rightBin == bin.key ? Palette.green : (_wrongBin == bin.key ? Palette.red : binColor(i)), width: _rightBin == bin.key ? 10 : 6),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(binIcon(bin.icon), size: 72, color: Palette.ink),
                          Text(Strings.en('bin_${bin.key}'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Palette.ink)),
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
