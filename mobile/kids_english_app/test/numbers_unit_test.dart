import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/features/activities/activity_logic.dart';
import 'package:kids_english_app/features/content/content_models.dart';

import 'helpers.dart';

/// The newest real Numbers pack, as the app downloads it (the index says which version that is).
Directory _packDir() {
  final index = jsonDecode(File('../../packs/little_learners/index.json').readAsStringSync()) as Map<String, dynamic>;
  final entry = (index['packs'] as List<dynamic>).cast<Map<String, dynamic>>().firstWhere((p) => p['unit'] == 'numbers');
  return Directory('../../packs/little_learners/numbers/v${entry['version']}');
}

List<Lesson> _pack() {
  final manifest = jsonDecode(File('${_packDir().path}/manifest.json').readAsStringSync()) as Map<String, dynamic>;
  return [for (final l in manifest['lessons'] as List<dynamic>) Lesson.fromJson(l as Map<String, dynamic>)];
}

void main() {
  test('Numbers has three lessons that count one to ten, in order, each marked as counting', () {
    final lessons = _pack();
    expect(lessons.map((l) => l.id), ['number-1-3', 'number-4-6', 'number-7-10']);
    expect(lessons.expand((l) => l.words).map((w) => w.word), ['one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten']);
    expect(lessons.every((l) => l.counting), isTrue);
    expect(lessons.every((l) => l.activities.contains('listen-and-tap') && l.activities.contains('match-picture') && l.activities.contains('record-and-listen')), isTrue);
    for (final w in lessons.expand((l) => l.words)) {
      expect(w.phrase, isNotNull, reason: '${w.word} has a spoken phrase');
    }
  });

  test('every picture, word and phrase of the pack is a file in the pack with a matching checksum entry', () {
    final dir = _packDir();
    final manifest = jsonDecode(File('${dir.path}/manifest.json').readAsStringSync()) as Map<String, dynamic>;
    final listed = {for (final f in manifest['files'] as List<dynamic>) (f as Map<String, dynamic>)['path'] as String};
    for (final w in _pack().expand((l) => l.words)) {
      expect(listed, contains(w.image), reason: w.word);
      expect(listed, contains(w.audio), reason: w.word);
      expect(File('${dir.path}/${w.image}').existsSync(), isTrue, reason: w.image);
      expect(listed, contains(w.phrase), reason: w.word);
    }
  });

  test('"tap that many balloons" offers only other counts, never a letter picture', () {
    final numbers = CourseUnit(id: 'numbers', order: 3, title: const {'en': 'Numbers'}, icon: 'numbers', color: 'blue', lessons: _pack());
    final content = TrackContent(track: 'little-learners', units: [
      ...sampleContent().units,
      numbers,
    ]);
    final numberWords = numbers.lessons.expand((l) => l.words).map((w) => w.image).toSet();
    for (var seed = 0; seed < 25; seed++) {
      for (final lesson in numbers.lessons) {
        for (final round in buildChoiceRounds(lesson, content, Random(seed))) {
          expect(round.options.length, 3);
          expect(round.options.map((o) => o.image).toSet().length, 3, reason: 'three different pictures');
          for (final o in round.options) {
            expect(numberWords, contains(o.image), reason: '${round.target.word}: ${o.word} is a count');
          }
        }
      }
    }
  });

  test('the numerals of each lesson for the big circle', () {
    expect(_pack().map((l) => l.digits), ['1 2 3', '4 5 6', '7 8 9 10']);
  });

  test('a lesson without the counting flag reads as before (older content)', () {
    final json = jsonDecode(File('${_packDir().path}/manifest.json').readAsStringSync()) as Map<String, dynamic>;
    final first = Map<String, dynamic>.from((json['lessons'] as List<dynamic>).first as Map<String, dynamic>)..remove('counting');
    expect(Lesson.fromJson(first).counting, isFalse);
  });
}
