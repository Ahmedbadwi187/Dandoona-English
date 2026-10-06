import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/palette.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../audio/audio_service.dart';
import '../content/content_models.dart';
import 'activity_logic.dart';

/// Hear a word, tap its picture. A wrong tap replays the word (no scolding); a right tap plays a praise line.
class ListenAndTapActivity extends ConsumerStatefulWidget {
  const ListenAndTapActivity({
    super.key,
    required this.lesson,
    required this.track,
    required this.onFinished,
    this.random,
    this.nextDelay = const Duration(milliseconds: 900),
  });

  final Lesson lesson;
  final TrackContent track;
  final ValueChanged<ActivityResult> onFinished;
  final Random? random;
  final Duration nextDelay;

  @override
  ConsumerState<ListenAndTapActivity> createState() => _ListenAndTapActivityState();
}

class _ListenAndTapActivityState extends ConsumerState<ListenAndTapActivity> {
  late final Random _random = widget.random ?? Random();
  late final List<ChoiceRound> _rounds = buildChoiceRounds(widget.lesson, widget.track, _random);
  int _index = 0;
  int _mistakes = 0;
  String? _wrongWord;
  String? _rightWord;
  bool _locked = false;

  ChoiceRound get _round => _rounds[_index];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _playTarget());
  }

  void _playTarget() {
    if (mounted) unawaited(ref.read(audioServiceProvider).playAsset(_round.target.audio));
  }

  Future<void> _tap(LessonWord option) async {
    if (_locked) return;
    if (option.word == _round.target.word) {
      _locked = true;
      setState(() => _rightWord = option.word);
      final praise = widget.lesson.audio.praise;
      if (praise.isNotEmpty) unawaited(ref.read(audioServiceProvider).playAsset(praise[_random.nextInt(praise.length)]));
      await Future<void>.delayed(widget.nextDelay);
      if (!mounted) return;
      if (_index + 1 >= _rounds.length) {
        widget.onFinished(ActivityResult(stars: starsForMistakes(_mistakes), attempts: _rounds.length + _mistakes));
      } else {
        setState(() {
          _index++;
          _rightWord = null;
          _locked = false;
        });
        _playTarget();
      }
    } else {
      _mistakes++;
      setState(() => _wrongWord = option.word);
      _playTarget();
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mounted) setState(() => _wrongWord = null);
    }
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
              for (var i = 0; i < _rounds.length; i++)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: i <= _index ? Palette.orange : Palette.tan),
                ),
            ],
          ),
          const SizedBox(height: 24),
          BigTap(
            onTap: _playTarget,
            semanticLabel: 'Hear the word again',
            child: Container(
              key: const Key('hear-again'),
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: Palette.blue,
                shape: BoxShape.circle,
                border: Border.all(color: Palette.ink, width: 4),
              ),
              child: const Icon(Icons.volume_up_rounded, size: 64, color: Palette.white),
            ),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              for (final option in _round.options)
                GestureDetector(
                  key: Key('option-${option.word}'),
                  onTap: () => _tap(option),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(minWidth: kMinTapTarget, minHeight: kMinTapTarget),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: _rightWord == option.word
                            ? Palette.green
                            : _wrongWord == option.word
                                ? Palette.red
                                : Palette.tan,
                        width: 6,
                      ),
                    ),
                    child: AssetPicture(option.image, size: 150, semanticLabel: option.word),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
