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
import '../profiles/child_profile.dart';
import 'activity_logic.dart';
import 'activity_widgets.dart';
import 'hand_demo.dart';

/// Explorers phonics games (ages 6-8): Sound Tap, Word Builder, Read & Pick. Each starts, the first time a child meets it,
/// with the hand demo while Dandoona says the game's instruction; the "?" button shows the demo again. No game ever fails:
/// a wrong try is simply heard and tried again; the stars count the tries.

/// Shared start of a phonics game: the demo the first time (with the instruction), otherwise just the instruction; then
/// the first round's own prompt.
mixin _PhonicsGame<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  late final ActivitySpeech speech = ActivitySpeech(ref.read(audioServiceProvider));
  bool demo = false;

  String get activity;
  Lesson get lesson;
  List<DemoStep> get demoSteps;

  /// Said when a round starts (the word, for the games that are heard).
  void startRound();

  void startGame() {
    speech; // made now, never first inside dispose
    final childId = ref.read(activeChildIdProvider);
    final seen = childId != null && ref.read(demoSeenProvider.notifier).seen(childId, activity);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (seen) {
        unawaited(speech.say(instruction: lesson.audio.instructions[activity]).then((_) {
          if (mounted && !demo) startRound();
        }));
      } else {
        showDemo();
      }
    });
  }

  void showDemo() {
    setState(() => demo = true);
    unawaited(speech.say(instruction: lesson.audio.instructions[activity]));
  }

  void demoDone() {
    if (!demo) return;
    setState(() => demo = false);
    final childId = ref.read(activeChildIdProvider);
    if (childId != null) unawaited(ref.read(demoSeenProvider.notifier).markSeen(childId, activity));
    startRound();
  }

  Widget frame({required Widget child, required int index, required int total}) => HandDemo(
        running: demo,
        steps: demoSteps,
        onDone: demoDone,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: RoundDots(total: total, index: index)),
                DemoHelpButton(onTap: showDemo),
              ],
            ),
            Expanded(child: child),
          ],
        ),
      );

  /// Says the sound of [grapheme]; a silent letter says nothing.
  void playPhoneme(TrackContent track, String grapheme) {
    final key = graphemeSound(grapheme);
    final clip = key == null ? null : track.phonemes[key];
    if (clip != null) unawaited(speech.say(then: clip));
  }
}

/// A letter (or letters) on a tile, the same look for boxes, tiles and slots.
class GraphemeTile extends StatelessWidget {
  const GraphemeTile({super.key, required this.text, this.color = Palette.white, this.border = Palette.nightInk, this.size = 84, this.faded = false, this.silent = false});

  /// Tiles are built from a word's graphemes: [GraphemeTile.of] shows only the letters and marks a silent one.
  factory GraphemeTile.of(String grapheme, {Key? key, Color color = Palette.white, Color border = Palette.nightInk, double size = 84, bool faded = false}) =>
      GraphemeTile(key: key, text: graphemeText(grapheme), color: color, border: border, size: size, faded: faded, silent: grapheme.isNotEmpty && graphemeSound(grapheme) == null);

  final String text;
  final Color color;
  final Color border;
  final double size;
  final bool faded;

  /// A silent letter (the magic e): lighter letter, so the child sees it makes no sound of its own.
  final bool silent;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: faded ? border.withValues(alpha: 0.3) : border, width: 4),
          boxShadow: faded ? null : [BoxShadow(color: Palette.nightInk.withValues(alpha: 0.18), offset: const Offset(0, 4), blurRadius: 4)],
        ),
        child: Text(text,
            style: TextStyle(
              fontSize: size * (text.length > 2 ? 0.4 : 0.55),
              fontWeight: FontWeight.w900,
              color: faded || silent ? Palette.nightInk.withValues(alpha: silent && !faded ? 0.45 : 0.3) : Palette.nightInk,
            )),
      );
}

// ----------------------------------------------------------------------------------------------------------- Sound Tap
/// Sound Tap: the picture and the word in boxes, one box per sound. Each tap says that sound; when every box has been
/// heard, Dandoona reads the whole word and the next word comes. Exploring cannot go wrong: always three stars.
class SoundTapActivity extends ConsumerStatefulWidget {
  const SoundTapActivity({super.key, required this.lesson, required this.track, required this.onFinished, this.nextDelay = const Duration(milliseconds: 1400)});

  final Lesson lesson;
  final TrackContent track;
  final ValueChanged<ActivityResult> onFinished;
  final Duration nextDelay;

  @override
  ConsumerState<SoundTapActivity> createState() => _SoundTapActivityState();
}

class _SoundTapActivityState extends ConsumerState<SoundTapActivity> with _PhonicsGame {
  late final List<LessonWord> _words = widget.lesson.words.where((w) => w.graphemes.isNotEmpty).toList();
  late final List<GlobalKey> _boxKeys = List.generate(8, (_) => GlobalKey());
  int _index = 0;
  final Set<int> _heard = {};
  bool _reading = false;
  int _taps = 0;

  @override
  String get activity => 'sound-tap';
  @override
  Lesson get lesson => widget.lesson;
  @override
  List<DemoStep> get demoSteps => [for (var i = 0; i < _words[_index].graphemes.length; i++) DemoStep.tap(_boxKeys[i])];

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
  void startRound() {}

  Future<void> _tap(int i) async {
    if (_reading || demo) return;
    _taps++;
    final word = _words[_index];
    playPhoneme(widget.track, word.graphemes[i]);
    setState(() => _heard.add(i));
    if (_heard.length < word.graphemes.length) return;
    // every sound heard: blend them into the word
    setState(() => _reading = true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    unawaited(speech.say(then: word.audio));
    await Future<void>.delayed(widget.nextDelay);
    if (!mounted) return;
    if (_index + 1 >= _words.length) {
      widget.onFinished(ActivityResult(stars: 3, attempts: _taps));
      return;
    }
    setState(() {
      _index++;
      _heard.clear();
      _reading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final word = _words[_index];
    return frame(
      index: _index,
      total: _words.length,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            AnimatedScale(
              scale: _reading ? 1.08 : 1,
              duration: const Duration(milliseconds: 300),
              child: AssetPicture(word.image, size: 200, semanticLabel: word.word),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              alignment: WrapAlignment.center,
              children: [
                for (var i = 0; i < word.graphemes.length; i++)
                  GestureDetector(
                    key: Key('sound-box-$i'),
                    onTap: () => unawaited(_tap(i)),
                    child: KeyedSubtree(
                      key: _boxKeys[i],
                      child: GraphemeTile.of(
                        word.graphemes[i],
                        color: _reading ? Palette.green : (_heard.contains(i) ? Palette.sunflower : Palette.white),
                        size: 92,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // the dots under the boxes: which sounds are still to hear
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < word.graphemes.length; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: _heard.contains(i) ? Palette.green : Palette.tan),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------------------------------------- Word Builder
/// The letter tiles of one round: the word's own graphemes and up to two more from the lesson's other words (never one
/// that looks like a tile already there), shuffled.
List<String> builderTiles(LessonWord word, Lesson lesson, Random random) {
  final own = {for (final g in word.graphemes) graphemeText(g)};
  final extra = <String, String>{
    for (final w in lesson.words)
      if (w.word != word.word)
        for (final g in w.graphemes)
          if (!own.contains(graphemeText(g))) graphemeText(g): g,
  }.values.toList()
    ..shuffle(random);
  return [...word.graphemes, ...extra.take(2)]..shuffle(random);
}

/// Word Builder: hear the word and see its picture, then put the letter tiles in order into the empty slots (tap a tile
/// or drag it). A tile that does not come next shakes and says its sound; the word is said when it is built.
class WordBuilderActivity extends ConsumerStatefulWidget {
  const WordBuilderActivity({super.key, required this.lesson, required this.track, required this.onFinished, this.random, this.nextDelay = const Duration(milliseconds: 1200)});

  final Lesson lesson;
  final TrackContent track;
  final ValueChanged<ActivityResult> onFinished;
  final Random? random;
  final Duration nextDelay;

  @override
  ConsumerState<WordBuilderActivity> createState() => _WordBuilderActivityState();
}

class _WordBuilderActivityState extends ConsumerState<WordBuilderActivity> with _PhonicsGame {
  late final Random _random = widget.random ?? Random();
  late final List<LessonWord> _words = widget.lesson.words.where((w) => w.graphemes.isNotEmpty).toList();
  late List<String> _tiles = builderTiles(_words[0], widget.lesson, _random);
  final List<GlobalKey> _tileKeys = List.generate(10, (_) => GlobalKey());
  final List<GlobalKey> _slotKeys = List.generate(8, (_) => GlobalKey());
  final Set<int> _used = {};
  int _index = 0;
  int _placed = 0;
  int _mistakes = 0;
  int? _shaking;
  bool _done = false;

  @override
  String get activity => 'word-builder';
  @override
  Lesson get lesson => widget.lesson;

  /// The demo drags the first right tile into the first slot.
  @override
  List<DemoStep> get demoSteps {
    final first = _tiles.indexOf(_words[_index].graphemes[0]);
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
  void startRound() => unawaited(speech.say(then: _words[_index].audio));

  Future<void> _place(int tile) async {
    if (_done || demo || _used.contains(tile)) return;
    final word = _words[_index];
    // a tile that looks the same as the next one is right (the same letters), and says the sound they make in this word
    final right = graphemeText(_tiles[tile]) == graphemeText(word.graphemes[_placed]);
    playPhoneme(widget.track, right ? word.graphemes[_placed] : _tiles[tile]);
    if (!right) {
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
    if (_placed < word.graphemes.length) return;
    setState(() => _done = true);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    unawaited(speech.say(then: word.audio));
    await Future<void>.delayed(widget.nextDelay);
    if (!mounted) return;
    if (_index + 1 >= _words.length) {
      widget.onFinished(ActivityResult(stars: starsForMistakes(_mistakes), attempts: _words.length + _mistakes));
      return;
    }
    setState(() {
      _index++;
      _tiles = builderTiles(_words[_index], widget.lesson, _random);
      _used.clear();
      _placed = 0;
      _done = false;
    });
    startRound();
  }

  @override
  Widget build(BuildContext context) {
    final word = _words[_index];
    return frame(
      index: _index,
      total: _words.length,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AssetPicture(word.image, size: 170, semanticLabel: word.word),
                const SizedBox(width: 8),
                BigTap(
                  key: const Key('builder-hear'),
                  semanticLabel: 'Hear the word',
                  onTap: () => unawaited(speech.say(then: word.audio)),
                  child: const Icon(Icons.volume_up_rounded, size: 40, color: Palette.blue),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // the slots: filled from left to right
            Wrap(
              spacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (var i = 0; i < word.graphemes.length; i++)
                  DragTarget<int>(
                    key: Key('builder-slot-$i'),
                    onWillAcceptWithDetails: (d) => i == _placed,
                    onAcceptWithDetails: (d) => unawaited(_place(d.data)),
                    builder: (context, _, _) => KeyedSubtree(
                      key: _slotKeys[i],
                      child: i < _placed
                          ? GraphemeTile.of(word.graphemes[i], color: _done ? Palette.green : Palette.sunflower)
                          : GraphemeTile(text: '', color: Palette.cream, border: i == _placed ? Palette.blue : Palette.tan),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            // the tiles to choose from
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                for (var t = 0; t < _tiles.length; t++)
                  _used.contains(t)
                      ? GraphemeTile(text: graphemeText(_tiles[t]), faded: true)
                      : Draggable<int>(
                          data: t,
                          feedback: Material(color: Colors.transparent, child: GraphemeTile(text: graphemeText(_tiles[t]), color: Palette.sunflower)),
                          childWhenDragging: GraphemeTile(text: graphemeText(_tiles[t]), faded: true),
                          child: GestureDetector(
                            key: Key('builder-tile-$t'),
                            onTap: () => unawaited(_place(t)),
                            child: KeyedSubtree(
                              key: _tileKeys[t],
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: _shaking == t ? 1 : 0),
                                duration: const Duration(milliseconds: 400),
                                builder: (context, v, child) => Transform.translate(offset: Offset(sin(v * pi * 6) * 8, 0), child: child),
                                child: GraphemeTile(text: graphemeText(_tiles[t]), color: _shaking == t ? Palette.pink : Palette.white),
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

// ----------------------------------------------------------------------------------------------------------- Read & Pick
/// A picture to pick in Read & Pick: one [source] picture, or the same picture twice for its plural ("cats").
class ReadPick {
  const ReadPick(this.source, {this.two = false});
  final LessonWord source;
  final bool two;

  /// What it shows, written: "cat", or "cats" for two.
  String get word => two ? (source.plural ?? source.word) : source.word;

  /// What is said when it is picked: the word, or for two "One cat. Two cats!".
  String get audio => two ? (source.pluralAudio ?? source.audio) : source.audio;
}

/// One Read & Pick round: the written [target] and three pictures to choose from.
class ReadRound {
  const ReadRound(this.target, this.options);
  final ReadPick target;
  final List<ReadPick> options;
  bool get plural => target.two;
}

/// Every word of the lesson once, each with two other pictures of the lesson; then each word that has a plural ("cats"):
/// two cats, one cat, and two of something else, so the child sees that -s means more than one.
List<ReadRound> buildReadRounds(Lesson lesson, Random random) {
  final words = lesson.words.toList()..shuffle(random);
  final plurals = words.where((w) => w.plural != null).toList();
  return [
    for (final w in words)
      ReadRound(ReadPick(w), [ReadPick(w), ...(lesson.words.where((o) => o.word != w.word).toList()..shuffle(random)).take(2).map(ReadPick.new)]..shuffle(random)),
    for (final w in plurals)
      ReadRound(ReadPick(w, two: true), [ReadPick(w, two: true), ReadPick(w), ReadPick((lesson.words.where((o) => o.word != w.word).toList()..shuffle(random)).first, two: true)]..shuffle(random)),
  ];
}

/// "a" or "an" before a word, from its first sound: "an ant", "an egg", but "a cube" (u says "you" there).
String articleFor(LessonWord w) {
  final first = w.graphemes.isEmpty ? (w.word.isEmpty ? '' : w.word[0]) : (graphemeSound(w.graphemes.first) ?? '');
  return const {'a', 'e', 'i', 'o', 'u'}.contains(first) ? 'an' : 'a';
}

/// Read & Pick: the word is shown written ("a cat", "an ant"), with no sound, and the child taps its picture. The word is
/// said after the answer (a wrong picture says its own word, so the child hears the difference). The last rounds show a
/// plural ("cats"): two of the picture is right, and Dandoona says "One cat. Two cats!".
class ReadAndPickActivity extends ConsumerStatefulWidget {
  const ReadAndPickActivity({super.key, required this.lesson, required this.onFinished, this.random, this.nextDelay = const Duration(milliseconds: 1100)});

  final Lesson lesson;
  final ValueChanged<ActivityResult> onFinished;
  final Random? random;
  final Duration nextDelay;

  @override
  ConsumerState<ReadAndPickActivity> createState() => _ReadAndPickActivityState();
}

class _ReadAndPickActivityState extends ConsumerState<ReadAndPickActivity> with _PhonicsGame {
  late List<ReadRound> _rounds = buildReadRounds(widget.lesson, widget.random ?? Random());
  final _wordKey = GlobalKey();
  final List<GlobalKey> _pictureKeys = List.generate(3, (_) => GlobalKey());
  int _index = 0;
  int _mistakes = 0;
  String? _right;
  String? _wrong;
  bool _locked = false;
  bool _demoShown = false;

  @override
  String get activity => 'read-and-pick';
  @override
  Lesson get lesson => widget.lesson;

  /// The demo points at the written word, then at its picture.
  @override
  List<DemoStep> get demoSteps {
    final r = _rounds[_index];
    return [DemoStep.tap(_wordKey), DemoStep.tap(_pictureKeys[r.options.indexWhere((o) => o.word == r.target.word)])];
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
  void showDemo() {
    _demoShown = true;
    super.showDemo();
  }

  /// The word the demo answered is not asked first: it moves to the end.
  @override
  void startRound() {
    if (_demoShown && _index == 0 && _rounds.length > 1) setState(() => _rounds = [..._rounds.skip(1), _rounds.first]);
    _demoShown = false;
  }

  Future<void> _tap(ReadPick w) async {
    if (_locked || demo) return;
    final round = _rounds[_index];
    unawaited(speech.say(then: w.audio)); // the sound comes after the answer
    if (w.word != round.target.word) {
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
      widget.onFinished(ActivityResult(stars: starsForMistakes(_mistakes), attempts: _rounds.length + _mistakes));
      return;
    }
    setState(() {
      _index++;
      _right = null;
      _locked = false;
    });
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
            Container(
              key: _wordKey,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              decoration: BoxDecoration(color: Palette.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Palette.nightInk, width: 4)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  // "a" / "an" before one thing; nothing before a plural
                  if (!round.plural) ...[
                    Text(articleFor(round.target.source), key: const Key('read-article'), style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: Palette.nightInk.withValues(alpha: 0.6))),
                    const SizedBox(width: 14),
                  ],
                  Text(round.target.word, key: const Key('read-word'), style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: Palette.nightInk, letterSpacing: 4)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              alignment: WrapAlignment.center,
              children: [
                for (var i = 0; i < round.options.length; i++)
                  GestureDetector(
                    key: Key('read-${round.options[i].word}'),
                    onTap: () => unawaited(_tap(round.options[i])),
                    child: Container(
                      key: _pictureKeys[i],
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(minWidth: kMinTapTarget, minHeight: kMinTapTarget),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: _right == round.options[i].word ? Palette.green : (_wrong == round.options[i].word ? Palette.red : Palette.tan), width: 6),
                      ),
                      child: round.options[i].two
                          ? SizedBox(
                              width: 128,
                              height: 128,
                              child: Stack(children: [
                                Positioned(left: 0, top: 0, child: AssetPicture(round.options[i].source.image, size: 84, semanticLabel: 'picture')),
                                Positioned(right: 0, bottom: 0, child: AssetPicture(round.options[i].source.image, size: 84, semanticLabel: 'picture')),
                              ]),
                            )
                          : AssetPicture(round.options[i].source.image, size: 128, semanticLabel: 'picture'),
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
