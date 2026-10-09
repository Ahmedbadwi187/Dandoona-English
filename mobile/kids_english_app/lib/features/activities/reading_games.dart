import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/loading_action.dart';
import '../../core/palette.dart';
import '../../core/widgets.dart';
import '../content/content_models.dart';
import 'activity_logic.dart';
import 'hand_demo.dart';
import 'phonics_activities.dart';
import '../../core/type.dart';

/// Two more Explorers reading games on the words and sentences of a lesson: True or False and Sight Word Hunt. Like the others:
/// the hand demo the first time with Dandoona's instruction, "?" shows it again, a wrong try is tried again and costs a star.

// ----------------------------------------------------------------------------------------------------------- True or False
/// One round: a sentence, a picture, and whether the picture matches the sentence.
class TrueFalseRound {
  const TrueFalseRound(this.sentence, this.image, this.two, this.isTrue);
  final LessonSentence sentence;
  final String image;
  final bool two;
  final bool isTrue;
}

/// Up to [max] rounds, half of them true. A false round shows the wrong number of things when the sentence is about one or two
/// (is/are, has/have: "The cats are big." with one cat), otherwise the picture of another sentence.
List<TrueFalseRound> buildTrueFalseRounds(Lesson lesson, Random random, {int max = 6}) {
  final sentences = lesson.sentences.toList()..shuffle(random);
  final rounds = <TrueFalseRound>[];
  for (final (i, s) in sentences.take(max).indexed) {
    final wantTrue = i.isEven;
    if (wantTrue) {
      rounds.add(TrueFalseRound(s, s.image, s.two, true));
      continue;
    }
    final countWord = {'is', 'are', 'has', 'have'}.contains(s.gap?.toLowerCase()) || s.tokens.any((t) => const {'is', 'are'}.contains(t.toLowerCase()));
    final other = sentences.where((o) => o.image != s.image).toList();
    if (countWord) {
      rounds.add(TrueFalseRound(s, s.image, !s.two, false));
    } else if (other.isNotEmpty) {
      final o = other[random.nextInt(other.length)];
      rounds.add(TrueFalseRound(s, o.image, o.two, false));
    } else {
      rounds.add(TrueFalseRound(s, s.image, s.two, true));
    }
  }
  return rounds..shuffle(random);
}

/// True or False: read the sentence (nothing is said at first), look at the picture, and tap the green check if they go together
/// or the red cross if they do not. After the right answer Dandoona reads the sentence.
class TrueOrFalseActivity extends ConsumerStatefulWidget {
  const TrueOrFalseActivity({super.key, required this.lesson, required this.onFinished, this.random, this.nextDelay = const Duration(milliseconds: 1500)});

  final Lesson lesson;
  final FutureOr<void> Function(ActivityResult) onFinished;
  final Random? random;
  final Duration nextDelay;

  @override
  ConsumerState<TrueOrFalseActivity> createState() => _TrueOrFalseActivityState();
}

class _TrueOrFalseActivityState extends ConsumerState<TrueOrFalseActivity> with PhonicsGame {
  late final List<TrueFalseRound> _rounds = buildTrueFalseRounds(widget.lesson, widget.random ?? Random());
  final _yesKey = GlobalKey();
  final _noKey = GlobalKey();
  int _index = 0;
  int _mistakes = 0;
  String? _wrong; // 'yes' or 'no'
  String? _right;
  bool _locked = false;

  @override
  String get activity => 'true-or-false';
  @override
  Lesson get lesson => widget.lesson;

  /// The demo taps the answer that is right.
  @override
  List<DemoStep> get demoSteps => [DemoStep.tap(_rounds[_index].isTrue ? _yesKey : _noKey)];

  @override
  void initState() {
    super.initState();
    startGame();
  }

  @override
  void dispose() {
    speech.cancel();
    super.dispose();
  }

  /// Nothing is said at the start: the child reads.
  @override
  void startRound() {}

  Future<void> _answer(bool yes) async {
    if (_locked || demo) return;
    final round = _rounds[_index];
    if (yes != round.isTrue) {
      _mistakes++;
      setState(() => _wrong = yes ? 'yes' : 'no');
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mounted) setState(() => _wrong = null);
      return;
    }
    _locked = true;
    setState(() => _right = yes ? 'yes' : 'no');
    unawaited(speech.say(then: round.sentence.audio));
    await Future<void>.delayed(widget.nextDelay);
    if (!mounted) return;
    if (_index + 1 >= _rounds.length) {
      await widget.onFinished(ActivityResult(stars: starsForMistakes(_mistakes), attempts: _rounds.length + _mistakes));
      return;
    }
    setState(() {
      _index++;
      _right = null;
      _locked = false;
    });
  }

  Widget _button(String key, GlobalKey gk, bool yes) {
    final shaking = _wrong == key;
    final done = _right == key;
    return LoadingTap(
      key: Key('tf-$key'),
      onTap: () => _answer(yes),
      child: KeyedSubtree(
        key: gk,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: shaking ? 1 : 0),
          duration: const Duration(milliseconds: 400),
          builder: (context, v, child) => Transform.translate(offset: Offset(sin(v * pi * 6) * 8, 0), child: child),
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: done ? Palette.green : (yes ? Palette.green.withValues(alpha: 0.35) : Palette.red.withValues(alpha: 0.35)),
              shape: BoxShape.circle,
              border: Border.all(color: shaking ? Palette.red : Palette.nightInk, width: 6),
            ),
            child: Icon(yes ? Icons.check_rounded : Icons.close_rounded, size: 80, color: Palette.nightInk),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final round = _rounds[_index];
    final tokens = round.sentence.tokens;
    return frame(
      index: _index,
      total: _rounds.length,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ManyPicture(round.image, two: round.two, size: 200, key: const Key('tf-picture')),
            const SizedBox(height: 20),
            Text(
              '${tokens.join(' ')}${round.sentence.mark}',
              key: const Key('tf-sentence'),
              textAlign: TextAlign.center,
              style: kidTitle.copyWith(fontWeight: FontWeight.w900, color: Palette.nightInk),
            ),
            const SizedBox(height: 32),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [_button('yes', _yesKey, true), const SizedBox(width: 36), _button('no', _noKey, false)]),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------------------------------------- Sight Word Hunt
/// Sight Word Hunt: the words of the lesson float about like bubbles; the child hears a word and taps its bubble, which pops. Every word
/// of the lesson is hunted once. A wrong bubble shakes and says its own word.
class SightWordHuntActivity extends ConsumerStatefulWidget {
  const SightWordHuntActivity({super.key, required this.lesson, required this.onFinished, this.random, this.drift, this.nextDelay = const Duration(milliseconds: 900)});

  final Lesson lesson;
  final FutureOr<void> Function(ActivityResult) onFinished;
  final Random? random;

  /// The bubbles drift gently; by default off in widget tests only (a repeating animation never settles there).
  final bool? drift;
  final Duration nextDelay;

  @override
  ConsumerState<SightWordHuntActivity> createState() => _SightWordHuntActivityState();
}

class _SightWordHuntActivityState extends ConsumerState<SightWordHuntActivity> with PhonicsGame, SingleTickerProviderStateMixin {
  late final Random _random = widget.random ?? Random();
  late final List<SightWord> _bubbles = widget.lesson.sightWords.toList()..shuffle(_random); // the order on the screen
  late final List<SightWord> _targets = widget.lesson.sightWords.toList()..shuffle(_random); // the order of the hunt
  late final AnimationController _drift = AnimationController(vsync: this, duration: const Duration(seconds: 6));
  final Map<String, GlobalKey> _keys = {};
  final Set<String> _popped = {};
  int _index = 0;
  int _mistakes = 0;
  String? _wrong;
  bool _locked = false;

  @override
  String get activity => 'sight-word-hunt';
  @override
  Lesson get lesson => widget.lesson;

  GlobalKey _keyOf(String w) => _keys.putIfAbsent(w, GlobalKey.new);

  /// The demo taps the bubble that was said.
  @override
  List<DemoStep> get demoSteps => [DemoStep.tap(_keyOf(_targets[_index].word))];

  @override
  void initState() {
    super.initState();
    if (widget.drift ?? !Platform.environment.containsKey('FLUTTER_TEST')) _drift.repeat();
    startGame();
  }

  @override
  void dispose() {
    _drift.dispose();
    speech.cancel();
    super.dispose();
  }

  @override
  void startRound() => unawaited(speech.say(then: _targets[_index].audio));

  Future<void> _tap(SightWord w) async {
    if (_locked || demo || _popped.contains(w.word)) return;
    if (w.word != _targets[_index].word) {
      _mistakes++;
      unawaited(speech.say(then: w.audio));
      setState(() => _wrong = w.word);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mounted) setState(() => _wrong = null);
      return;
    }
    _locked = true;
    unawaited(speech.say(then: w.audio));
    setState(() => _popped.add(w.word));
    await Future<void>.delayed(widget.nextDelay);
    if (!mounted) return;
    if (_index + 1 >= _targets.length) {
      await widget.onFinished(ActivityResult(stars: starsForMistakes(_mistakes), attempts: _targets.length + _mistakes));
      return;
    }
    setState(() {
      _index++;
      _locked = false;
    });
    startRound();
  }

  static const _colors = [Palette.blue, Palette.orange, Palette.green, Palette.pink, Palette.yellow, Palette.plum];

  @override
  Widget build(BuildContext context) {
    return frame(
      index: _index,
      total: _targets.length,
      child: Column(
        children: [
          const SizedBox(height: 8),
          BigTap(
            key: const Key('hunt-hear'),
            semanticLabel: 'Hear the word',
            onTap: () => speech.say(then: _targets[_index].audio),
            child: const Icon(Icons.volume_up_rounded, size: 64, color: Palette.blue),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                final cols = 2;
                final rows = (_bubbles.length / cols).ceil();
                final cellW = box.maxWidth / cols, cellH = box.maxHeight / rows;
                return AnimatedBuilder(
                  animation: _drift,
                  builder: (context, _) => Stack(
                    children: [
                      for (final (i, w) in _bubbles.indexed)
                        Positioned(
                          left: (i % cols) * cellW + cellW / 2 - 90 + sin((_drift.value + i / _bubbles.length) * 2 * pi) * 14,
                          top: (i ~/ cols) * cellH + cellH / 2 - 44 + cos((_drift.value * 2 + i / 3) * pi) * 12,
                          child: AnimatedScale(
                            scale: _popped.contains(w.word) ? 0 : 1,
                            duration: const Duration(milliseconds: 300),
                            child: LoadingTap(
                              key: Key('hunt-${w.word}'),
                              onTap: () => _tap(w),
                              child: KeyedSubtree(
                                key: _keyOf(w.word),
                                child: Container(
                                  width: 180,
                                  height: 88,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _wrong == w.word ? Palette.pink : _colors[i % _colors.length].withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(44),
                                    border: Border.all(color: Palette.nightInk, width: 5),
                                  ),
                                  child: Text(w.word, style: kidGameWord.copyWith(fontWeight: FontWeight.w900, color: Palette.nightInk)),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
