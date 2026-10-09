import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/loading_action.dart';
import '../../core/palette.dart';
import '../../core/theme.dart';
import '../content/content_models.dart';
import 'activity_logic.dart';
import '../../core/widgets.dart';
import 'hand_demo.dart';
import 'phonics_activities.dart';
import '../../core/type.dart';

/// Explorers reading games past single words (ages 6-8): Find the Word (sight words), Sentence Builder and Fill the Gap.
/// Like the phonics games: the hand demo the first time with Dandoona's instruction, "?" shows it again, a wrong try is just
/// tried again and the stars count the tries. Grammar is never named: "is"/"are" and "a"/"an" are chosen by the picture.

/// A word on a card: the same look for sight words, sentence tiles and choices.
class WordCard extends StatelessWidget {
  const WordCard({super.key, required this.text, this.color = Palette.white, this.border = Palette.nightInk, this.faded = false, this.textStyle = kidTitle});
  final String text;
  final Color color;
  final Color border;
  final bool faded;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 72, minHeight: kMinTapTarget + 16),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: faded ? border.withValues(alpha: 0.3) : border, width: 4),
      boxShadow: faded ? null : [BoxShadow(color: Palette.nightInk.withValues(alpha: 0.18), offset: const Offset(0, 4), blurRadius: 4)],
    ),
    // as wide as its word (at least the minimum), the word in the middle
    child: Center(
      widthFactor: 1,
      heightFactor: 1,
      child: Text(
        text,
        style: textStyle.copyWith(fontWeight: FontWeight.w900, color: faded ? Palette.nightInk.withValues(alpha: 0.3) : Palette.nightInk),
      ),
    ),
  );
}

/// A card that shakes when [shaking] turns on.
class _Shake extends StatelessWidget {
  const _Shake({required this.shaking, required this.child});
  final bool shaking;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: shaking ? 1 : 0),
    duration: const Duration(milliseconds: 400),
    builder: (context, v, child) => Transform.translate(offset: Offset(sin(v * pi * 6) * 8, 0), child: child),
    child: child,
  );
}

// ----------------------------------------------------------------------------------------------------------- Find the Word
/// One round of Find the Word: the word heard, and the cards to find it among.
class FindRound {
  const FindRound(this.target, this.options);
  final SightWord target;
  final List<SightWord> options;
}

/// Every sight word once, each among two other sight words of the lesson.
List<FindRound> buildFindRounds(Lesson lesson, Random random) {
  final words = lesson.sightWords.toList()..shuffle(random);
  return [
    for (final w in words) FindRound(w, [w, ...(lesson.sightWords.where((o) => o.word != w.word).toList()..shuffle(random)).take(2)]..shuffle(random)),
  ];
}

/// Find the Word: Dandoona says a sight word ("the"), and the child taps it among three written words. A wrong card says
/// its own word, so the child hears the difference.
class FindTheWordActivity extends ConsumerStatefulWidget {
  const FindTheWordActivity({super.key, required this.lesson, required this.onFinished, this.random, this.nextDelay = const Duration(milliseconds: 1000)});

  final Lesson lesson;
  final FutureOr<void> Function(ActivityResult) onFinished;
  final Random? random;
  final Duration nextDelay;

  @override
  ConsumerState<FindTheWordActivity> createState() => _FindTheWordActivityState();
}

class _FindTheWordActivityState extends ConsumerState<FindTheWordActivity> with PhonicsGame {
  late final List<FindRound> _rounds = buildFindRounds(widget.lesson, widget.random ?? Random());
  final List<GlobalKey> _cardKeys = List.generate(3, (_) => GlobalKey());
  int _index = 0;
  int _mistakes = 0;
  String? _right;
  String? _wrong;
  bool _locked = false;

  @override
  String get activity => 'find-the-word';
  @override
  Lesson get lesson => widget.lesson;

  /// The demo taps the word that was said.
  @override
  List<DemoStep> get demoSteps {
    final r = _rounds[_index];
    return [DemoStep.tap(_cardKeys[r.options.indexWhere((o) => o.word == r.target.word)])];
  }

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

  @override
  void startRound() => unawaited(speech.say(then: _rounds[_index].target.audio));

  Future<void> _tap(SightWord w) async {
    if (_locked || demo) return;
    unawaited(speech.say(then: w.audio));
    if (w.word != _rounds[_index].target.word) {
      _mistakes++;
      setState(() => _wrong = w.word);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mounted) setState(() => _wrong = null);
      return;
    }
    _locked = true;
    setState(() => _right = w.word);
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
    startRound();
  }

  @override
  Widget build(BuildContext context) {
    final round = _rounds[_index];
    return frame(
      index: _index,
      total: _rounds.length,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            BigTap(
              key: const Key('find-hear'),
              semanticLabel: 'Hear the word',
              onTap: () => speech.say(then: round.target.audio),
              child: const Icon(Icons.volume_up_rounded, size: 72, color: Palette.blue),
            ),
            const SizedBox(height: 28),
            for (var i = 0; i < round.options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: LoadingTap(
                  key: Key('find-${round.options[i].word}'),
                  onTap: () => _tap(round.options[i]),
                  child: KeyedSubtree(
                    key: _cardKeys[i],
                    child: _Shake(
                      shaking: _wrong == round.options[i].word,
                      child: SizedBox(
                        width: 240,
                        child: WordCard(
                          text: round.options[i].word,
                          textStyle: kidGameWord,
                          color: _right == round.options[i].word ? Palette.green : (_wrong == round.options[i].word ? Palette.pink : Palette.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------------------------------------- Sentence Builder
/// Sentence Builder: the picture, and the sentence heard; the child puts the word cards in order (tap or drag). A card that
/// does not come next shakes; the built sentence is read aloud.
class SentenceBuilderActivity extends ConsumerStatefulWidget {
  const SentenceBuilderActivity({super.key, required this.lesson, required this.onFinished, this.random, this.nextDelay = const Duration(milliseconds: 1600)});

  final Lesson lesson;
  final FutureOr<void> Function(ActivityResult) onFinished;
  final Random? random;
  final Duration nextDelay;

  @override
  ConsumerState<SentenceBuilderActivity> createState() => _SentenceBuilderActivityState();
}

class _SentenceBuilderActivityState extends ConsumerState<SentenceBuilderActivity> with PhonicsGame {
  late final Random _random = widget.random ?? Random();
  late final List<LessonSentence> _sentences = widget.lesson.sentences;
  late List<String> _tiles = _shuffled(_sentences[0]);
  final List<GlobalKey> _tileKeys = List.generate(8, (_) => GlobalKey());
  final List<GlobalKey> _slotKeys = List.generate(8, (_) => GlobalKey());
  final Set<int> _used = {};
  int _index = 0;
  int _placed = 0;
  int _mistakes = 0;
  int? _shaking;
  bool _done = false;

  /// The words in a new order (never the sentence's own order, when it has more than one word).
  List<String> _shuffled(LessonSentence s) {
    final tiles = s.tokens.toList();
    for (var i = 0; i < 5; i++) {
      tiles.shuffle(_random);
      if (tiles.join(' ') != s.tokens.join(' ')) break;
    }
    return tiles;
  }

  @override
  String get activity => 'sentence-builder';
  @override
  Lesson get lesson => widget.lesson;

  /// The demo drags the first word into the first slot.
  @override
  List<DemoStep> get demoSteps {
    final first = _tiles.indexOf(_sentences[_index].tokens[0]);
    return [if (first >= 0) DemoStep.drag(_tileKeys[first], _slotKeys[0])];
  }

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

  @override
  void startRound() => unawaited(speech.say(then: _sentences[_index].audio));

  Future<void> _place(int tile) async {
    if (_done || demo || _used.contains(tile)) return;
    final sentence = _sentences[_index];
    if (_tiles[tile] != sentence.tokens[_placed]) {
      _mistakes++;
      setState(() => _shaking = tile);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (mounted) setState(() => _shaking = null);
      return;
    }
    setState(() {
      _used.add(tile);
      _placed++;
    });
    if (_placed < sentence.tokens.length) return;
    setState(() => _done = true);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    unawaited(speech.say(then: sentence.audio));
    await Future<void>.delayed(widget.nextDelay);
    if (!mounted) return;
    if (_index + 1 >= _sentences.length) {
      await widget.onFinished(ActivityResult(stars: starsForMistakes(_mistakes), attempts: _sentences.length + _mistakes));
      return;
    }
    setState(() {
      _index++;
      _tiles = _shuffled(_sentences[_index]);
      _used.clear();
      _placed = 0;
      _done = false;
    });
    startRound();
  }

  @override
  Widget build(BuildContext context) {
    final sentence = _sentences[_index];
    return frame(
      index: _index,
      total: _sentences.length,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ManyPicture(sentence.image, two: sentence.two, size: 170),
                const SizedBox(width: 8),
                BigTap(
                  key: const Key('sentence-hear'),
                  semanticLabel: 'Hear the sentence',
                  onTap: () => speech.say(then: sentence.audio),
                  child: const Icon(Icons.volume_up_rounded, size: 40, color: Palette.blue),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // the slots, filled from left to right; the closing mark comes with the last word
            Wrap(
              spacing: 8,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                for (var i = 0; i < sentence.tokens.length; i++)
                  DragTarget<int>(
                    key: Key('sentence-slot-$i'),
                    onWillAcceptWithDetails: (d) => i == _placed,
                    onAcceptWithDetails: (d) => unawaited(_place(d.data)),
                    builder: (context, _, _) => KeyedSubtree(
                      key: _slotKeys[i],
                      child: i < _placed
                          ? WordCard(text: sentence.tokens[i], color: _done ? Palette.green : Palette.sunflower, textStyle: kidBody)
                          : WordCard(text: '    ', color: Palette.cream, border: i == _placed ? Palette.blue : Palette.tan, textStyle: kidBody),
                    ),
                  ),
                if (_done)
                  Text(
                    sentence.mark,
                    key: const Key('sentence-mark'),
                    style: kidGameWord.copyWith(fontWeight: FontWeight.w900, color: Palette.nightInk),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                for (var t = 0; t < _tiles.length; t++)
                  _used.contains(t)
                      ? WordCard(text: _tiles[t], faded: true, textStyle: kidBody)
                      : Draggable<int>(
                          data: t,
                          feedback: Material(
                            color: Colors.transparent,
                            child: WordCard(text: _tiles[t], color: Palette.sunflower, textStyle: kidBody),
                          ),
                          childWhenDragging: WordCard(text: _tiles[t], faded: true, textStyle: kidBody),
                          child: LoadingTap(
                            key: Key('sentence-tile-$t'),
                            onTap: () => _place(t),
                            child: KeyedSubtree(
                              key: _tileKeys[t],
                              child: _Shake(
                                shaking: _shaking == t,
                                child: WordCard(text: _tiles[t], color: _shaking == t ? Palette.pink : Palette.white, textStyle: kidBody),
                              ),
                            ),
                          ),
                        ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------------------------------------- Fill the Gap
/// Fill the Gap: the picture and a sentence with one word missing ("The cats ___ big."); the child reads it and taps the
/// word that fits ("is" / "are"). The picture tells which: one cat or two. The whole sentence is read after the answer.
class FillTheGapActivity extends ConsumerStatefulWidget {
  const FillTheGapActivity({super.key, required this.lesson, required this.onFinished, this.random, this.nextDelay = const Duration(milliseconds: 1600)});

  final Lesson lesson;
  final FutureOr<void> Function(ActivityResult) onFinished;
  final Random? random;
  final Duration nextDelay;

  @override
  ConsumerState<FillTheGapActivity> createState() => _FillTheGapActivityState();
}

class _FillTheGapActivityState extends ConsumerState<FillTheGapActivity> with PhonicsGame {
  late final Random _random = widget.random ?? Random();
  late final List<LessonSentence> _sentences = widget.lesson.sentences.where((s) => s.gap != null).toList()..shuffle(_random);
  late List<String> _choices = _sentences[0].choices.toList()..shuffle(_random);
  final _gapKey = GlobalKey();
  final List<GlobalKey> _choiceKeys = List.generate(3, (_) => GlobalKey());
  int _index = 0;
  int _mistakes = 0;
  String? _wrong;
  bool _filled = false;

  @override
  String get activity => 'fill-the-gap';
  @override
  Lesson get lesson => widget.lesson;

  /// The demo points at the gap, then at the word that fits.
  @override
  List<DemoStep> get demoSteps => [DemoStep.tap(_gapKey), DemoStep.tap(_choiceKeys[_choices.indexOf(_sentences[_index].gap!)])];

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

  Future<void> _tap(String choice) async {
    if (_filled || demo) return;
    final sentence = _sentences[_index];
    if (choice != sentence.gap) {
      _mistakes++;
      setState(() => _wrong = choice);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mounted) setState(() => _wrong = null);
      return;
    }
    setState(() => _filled = true);
    unawaited(speech.say(then: sentence.audio));
    await Future<void>.delayed(widget.nextDelay);
    if (!mounted) return;
    if (_index + 1 >= _sentences.length) {
      await widget.onFinished(ActivityResult(stars: starsForMistakes(_mistakes), attempts: _sentences.length + _mistakes));
      return;
    }
    setState(() {
      _index++;
      _choices = _sentences[_index].choices.toList()..shuffle(_random);
      _filled = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sentence = _sentences[_index];
    final tokens = sentence.tokens;
    final gapAt = tokens.indexWhere((t) => t.replaceAll(',', '').toLowerCase() == sentence.gap!.toLowerCase());
    final style = kidTitle.copyWith(fontWeight: FontWeight.w900, color: Palette.nightInk);
    return frame(
      index: _index,
      total: _sentences.length,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ManyPicture(sentence.image, two: sentence.two, size: 200),
            const SizedBox(height: 24),
            // the sentence, with the gap as an empty card until it is filled
            Wrap(
              key: const Key('gap-sentence'),
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (var i = 0; i < tokens.length; i++)
                  if (i == gapAt)
                    KeyedSubtree(
                      key: _gapKey,
                      child: WordCard(
                        key: const Key('gap-blank'),
                        text: _filled ? tokens[i] : '      ',
                        color: _filled ? Palette.green : Palette.cream,
                        border: _filled ? Palette.nightInk : Palette.blue,
                        textStyle: kidTitle,
                      ),
                    )
                  else
                    Text(i == tokens.length - 1 ? '${tokens[i]}${sentence.mark}' : tokens[i], style: style),
              ],
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                for (var c = 0; c < _choices.length; c++)
                  LoadingTap(
                    key: Key('gap-choice-${_choices[c]}'),
                    onTap: () => _tap(_choices[c]),
                    child: KeyedSubtree(
                      key: _choiceKeys[c],
                      child: _Shake(
                        shaking: _wrong == _choices[c],
                        child: WordCard(text: _choices[c], textStyle: kidGameWord, color: _wrong == _choices[c] ? Palette.pink : Palette.white),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
