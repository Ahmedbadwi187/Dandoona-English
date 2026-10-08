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
import 'activity_widgets.dart';

/// One card of the memory game: the [word] it shows and the [pair] it belongs to (two cards share a pair id).
class MemoryCard {
  const MemoryCard(this.word, this.pair);
  final LessonWord word;
  final String pair;
}

/// The cards of a lesson: each word twice, or - when the words have an `opposite` - each word with its opposite ("big" and "small").
List<MemoryCard> buildMemoryCards(Lesson lesson, TrackContent track, Random random, {int pairs = 3}) {
  final cards = <MemoryCard>[];
  final hasOpposites = lesson.words.any((w) => w.opposite != null);
  if (hasOpposites) {
    final pool = unitWordsOf(track, lesson);
    final used = <String>{};
    final chosen = <(LessonWord, LessonWord)>[];
    final firsts = [...lesson.words.where((w) => w.opposite != null)]..shuffle(random);
    for (final w in [...firsts, ...pool.where((x) => x.opposite != null)]) {
      final other = pool.where((x) => x.word == w.opposite).firstOrNull;
      if (other == null || used.contains(w.word) || used.contains(other.word)) continue;
      used.addAll([w.word, other.word]);
      chosen.add((w, other));
      if (chosen.length == pairs) break;
    }
    for (final (a, b) in chosen) {
      cards..add(MemoryCard(a, '${a.word}-${b.word}'))..add(MemoryCard(b, '${a.word}-${b.word}'));
    }
  } else {
    final words = ([...lesson.words]..shuffle(random)).take(pairs);
    for (final w in words) {
      cards..add(MemoryCard(w, w.word))..add(MemoryCard(w, w.word));
    }
  }
  return cards..shuffle(random);
}

/// Memory cards: turn two cards over (each says its word); a pair stays open. Turning more cards than needed costs stars.
class MemoryActivity extends ConsumerStatefulWidget {
  const MemoryActivity({super.key, required this.lesson, required this.track, required this.onFinished, this.random, this.closeAfter = const Duration(milliseconds: 900)});

  final Lesson lesson;
  final TrackContent track;
  final ValueChanged<ActivityResult> onFinished;
  final Random? random;
  final Duration closeAfter;

  @override
  ConsumerState<MemoryActivity> createState() => _MemoryActivityState();
}

class _MemoryActivityState extends ConsumerState<MemoryActivity> {
  late final List<MemoryCard> _cards = buildMemoryCards(widget.lesson, widget.track, widget.random ?? Random());
  late final ActivitySpeech _speech;
  final Set<int> _open = {};
  final Set<int> _matched = {};
  int _turns = 0; // pairs of cards turned over
  bool _busy = false;

  int get _pairs => _cards.length ~/ 2;

  @override
  void initState() {
    super.initState();
    _speech = ActivitySpeech(ref.read(audioServiceProvider));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_speech.say(instruction: widget.lesson.audio.instructions['memory']));
    });
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }

  Future<void> _flip(int i) async {
    if (_busy || _open.contains(i) || _matched.contains(i)) return;
    setState(() => _open.add(i));
    unawaited(_speech.say(then: _cards[i].word.audio));
    if (_open.length < 2) return;
    _turns++;
    final two = _open.toList();
    if (_cards[two[0]].pair == _cards[two[1]].pair) {
      setState(() {
        _matched.addAll(two);
        _open.clear();
      });
      if (_matched.length == _cards.length) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        // as many turns as pairs is perfect; up to twice as many is fine
        final stars = _turns <= _pairs ? 3 : (_turns <= _pairs * 2 ? 2 : 1);
        widget.onFinished(ActivityResult(stars: stars, attempts: _turns));
      }
    } else {
      _busy = true;
      await Future<void>.delayed(widget.closeAfter);
      if (!mounted) return;
      setState(() {
        _open.clear();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 14,
        runSpacing: 14,
        alignment: WrapAlignment.center,
        children: [
          for (final (i, card) in _cards.indexed)
            GestureDetector(
              key: Key('card-$i'),
              onTap: () => unawaited(_flip(i)),
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: _open.contains(i) || _matched.contains(i) ? Colors.white : Palette.plum,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: _matched.contains(i) ? Palette.green : Palette.ink, width: _matched.contains(i) ? 8 : 4),
                ),
                child: _open.contains(i) || _matched.contains(i)
                    ? Padding(padding: const EdgeInsets.all(8), child: AssetPicture(card.word.image, size: 120, semanticLabel: card.word.word))
                    : const Center(child: Icon(Icons.help_outline_rounded, size: 64, color: Palette.white)),
              ),
            ),
        ],
      ),
    );
  }
}
