import 'dart:math';

import '../content/content_models.dart';

/// The words of a review: a few from every unit of the group (round robin, so each unit gets its turn), never the same picture
/// twice, in a random order. Only units whose lessons are on the phone take part (a pack that is not downloaded has no words).
/// [perUnit] words come from each unit, at most [maxWords] in all.
List<LessonWord> reviewWords(TrackContent track, Iterable<String> unitIds, Random random, {int perUnit = 2, int maxWords = 8}) {
  final lists = <List<LessonWord>>[];
  for (final id in unitIds) {
    final unit = track.unitById(id);
    if (unit == null || unit.lessons.isEmpty) continue;
    final seen = <String>{};
    lists.add([for (final l in unit.lessons) for (final w in l.words) if (seen.add(w.image)) w]..shuffle(random));
  }
  final picked = <LessonWord>[];
  final images = <String>{};
  for (var round = 0; round < perUnit; round++) {
    for (final words in lists) {
      if (round < words.length && picked.length < maxWords && images.add(words[round].image)) picked.add(words[round]);
    }
  }
  return picked..shuffle(random);
}

/// The review as a one-lesson listen-and-tap game: hear the word, tap the picture among the other review words. Null when fewer
/// than three words are on the phone (nothing sensible to ask yet).
Lesson? buildReviewLesson(TrackContent track, String reviewId, Iterable<String> unitIds, Random random) {
  final words = reviewWords(track, unitIds, random);
  if (words.length < 3) return null;
  // the praise lines of the first lessons are good for any review
  final praise = [for (final u in track.units) for (final l in u.lessons) ...l.audio.praise].take(3).toList();
  return Lesson(
    id: reviewId,
    order: 1,
    level: 'pre-a1',
    audio: LessonAudio(intro: words.first.audio, praise: praise),
    words: words,
    activities: const ['listen-and-tap'],
  );
}
