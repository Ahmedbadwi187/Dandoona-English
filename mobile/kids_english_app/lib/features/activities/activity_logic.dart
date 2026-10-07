import 'dart:math';
import 'dart:typed_data';

import '../content/content_models.dart';

/// What an activity reports when it finishes.
class ActivityResult {
  const ActivityResult({required this.stars, required this.attempts});
  final int stars; // 0-3
  final int attempts;
}

/// 0 mistakes = 3 stars, 1-2 = 2 stars, more = 1 star (finishing always earns at least one).
int starsForMistakes(int mistakes) => mistakes == 0 ? 3 : (mistakes <= 2 ? 2 : 1);

/// One round of listen-and-tap: hear [target], tap its picture among [options].
class ChoiceRound {
  const ChoiceRound({required this.target, required this.options});
  final LessonWord target;
  final List<LessonWord> options; // shuffled, always contains target exactly once
}

/// Each word of the lesson becomes a round (in random order). Wrong options come from other lessons so
/// they are visibly different pictures; if the track is tiny, the lesson's own other words are used.
List<ChoiceRound> buildChoiceRounds(Lesson lesson, TrackContent track, Random random, {int optionCount = 3}) {
  // A Colors lesson asks for a color, so wrong pictures come only from the unit's other colors (never a same-colored thing).
  // A Numbers lesson asks for a count, so wrong pictures are other counts of the same unit.
  // Every other unit than Letters (Shapes, Animals, ...) keeps its wrong pictures inside the unit too: "tap the circle" among other shapes.
  final unit = track.unitOfLesson(lesson.id);
  final sameUnit = lesson.color != null || lesson.counting || (unit != null && unit.id != 'letters' && unit.lessons.length > 1);
  // A lesson of objects ("Shapes around us") keeps them to its own words.
  final pool0 = lesson.ownWordsOnly ? <Lesson>[] : (sameUnit ? (unit?.lessons ?? track.lessons) : track.lessons);
  final others = [
    for (final l in pool0)
      if (l.id != lesson.id) ...l.words,
  ];
  List<LessonWord> ownOthers(LessonWord target) => lesson.words.where((w) => w.word != target.word).toList();

  final rounds = <ChoiceRound>[];
  for (final target in lesson.words) {
    final pool = [...others]..shuffle(random);
    final distractors = <LessonWord>[];
    for (final w in [...pool, ...ownOthers(target)]) {
      if (distractors.length == optionCount - 1) break;
      if (w.word != target.word && w.image != target.image && !distractors.any((d) => d.image == w.image)) {
        distractors.add(w);
      }
    }
    rounds.add(ChoiceRound(target: target, options: [target, ...distractors]..shuffle(random)));
  }
  return rounds..shuffle(random);
}

/// Pairs for match-the-picture: each word has a picture card and a sound card; the two columns are shuffled differently.
class MatchPairs {
  const MatchPairs({required this.pictures, required this.sounds});
  final List<LessonWord> pictures;
  final List<LessonWord> sounds;
}

MatchPairs buildMatchPairs(Lesson lesson, Random random, {int maxPairs = 3}) {
  final words = [...lesson.words]..shuffle(random);
  final picked = words.take(maxPairs).toList();
  var sounds = [...picked]..shuffle(random);
  // Avoid the trivial identical order (only possible with 2+ cards).
  for (var i = 0; i < 5 && picked.length > 1 && _sameOrder(picked, sounds); i++) {
    sounds = [...picked]..shuffle(random);
  }
  return MatchPairs(pictures: picked, sounds: sounds);
}

bool _sameOrder(List<LessonWord> a, List<LessonWord> b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i].word != b[i].word) return false;
  }
  return true;
}

// ---------------------------------------------------------------------------------------------------------------
// Tracing: the glyph and the child's strokes are rasterised, reduced to coarse boolean grids, and compared.
// ---------------------------------------------------------------------------------------------------------------

/// Reduces RGBA pixels to a grid of [cell]-sized cells; a cell is "on" when any sampled pixel is visibly opaque.
List<bool> maskFromRgba(Uint8List rgba, int width, int height, {int cell = 6, int alphaThreshold = 40}) {
  final cols = (width / cell).ceil();
  final rows = (height / cell).ceil();
  final mask = List<bool>.filled(cols * rows, false);
  for (var cy = 0; cy < rows; cy++) {
    for (var cx = 0; cx < cols; cx++) {
      var on = false;
      for (var y = cy * cell; y < min((cy + 1) * cell, height) && !on; y += 2) {
        for (var x = cx * cell; x < min((cx + 1) * cell, width); x += 2) {
          if (rgba[(y * width + x) * 4 + 3] > alphaThreshold) {
            on = true;
            break;
          }
        }
      }
      mask[cy * cols + cx] = on;
    }
  }
  return mask;
}

class TraceScore {
  const TraceScore({required this.coverage, required this.spill, required this.stars});

  /// Share of the letter that was covered by ink (0-1).
  final double coverage;

  /// Share of the ink that landed far from the letter (0-1).
  final double spill;

  /// 0 = not enough yet (try again), 1-3 = stars.
  final int stars;
}

TraceScore scoreTrace({required List<bool> glyph, required List<bool> ink, required int cols}) {
  assert(glyph.length == ink.length);
  final rows = glyph.length ~/ cols;

  var glyphCells = 0, covered = 0, inkCells = 0, spilled = 0;
  bool nearGlyph(int cx, int cy) {
    for (var dy = -2; dy <= 2; dy++) {
      for (var dx = -2; dx <= 2; dx++) {
        final x = cx + dx, y = cy + dy;
        if (x >= 0 && x < cols && y >= 0 && y < rows && glyph[y * cols + x]) return true;
      }
    }
    return false;
  }

  for (var cy = 0; cy < rows; cy++) {
    for (var cx = 0; cx < cols; cx++) {
      final i = cy * cols + cx;
      if (glyph[i]) {
        glyphCells++;
        if (ink[i]) covered++;
      }
      if (ink[i]) {
        inkCells++;
        if (!nearGlyph(cx, cy)) spilled++;
      }
    }
  }

  final coverage = glyphCells == 0 ? 0.0 : covered / glyphCells;
  final spill = inkCells == 0 ? 0.0 : spilled / inkCells;
  final stars = coverage >= 0.55 && spill <= 0.3
      ? 3
      : coverage >= 0.38 && spill <= 0.5
          ? 2
          : coverage >= 0.22
              ? 1
              : 0;
  return TraceScore(coverage: coverage, spill: spill, stars: stars);
}
