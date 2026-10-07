import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/features/activities/activity_logic.dart';
import 'package:kids_english_app/features/content/content_models.dart';

import 'helpers.dart';

/// The newest real pack of [unit], as the app downloads it (the index says which version that is).
Directory _packDir(String unit) {
  final index = jsonDecode(File('../../packs/little_learners/index.json').readAsStringSync()) as Map<String, dynamic>;
  final entry = (index['packs'] as List<dynamic>).cast<Map<String, dynamic>>().firstWhere((p) => p['unit'] == unit);
  return Directory('../../packs/little_learners/$unit/v${entry['version']}');
}

List<Lesson> _lessons(String unit) {
  final manifest = jsonDecode(File('${_packDir(unit).path}/manifest.json').readAsStringSync()) as Map<String, dynamic>;
  return [for (final l in manifest['lessons'] as List<dynamic>) Lesson.fromJson(l as Map<String, dynamic>)];
}

void main() {
  test('Shapes has eight shapes in three lessons and a fourth lesson of things around us, each with a picture, a word and a phrase in the pack', () {
    final lessons = _lessons('shapes');
    expect(lessons.map((l) => l.id), ['shapes-1', 'shapes-2', 'shapes-3', 'shapes-4']);
    expect(lessons.take(3).expand((l) => l.words).map((w) => w.word), ['circle', 'square', 'triangle', 'rectangle', 'oval', 'diamond', 'star', 'heart']);
    expect(lessons.last.words.map((w) => w.word), ['ball', 'window', 'kite', 'egg']);
    expect(lessons.last.ownWordsOnly, isTrue);
    expect(lessons.take(3).every((l) => !l.ownWordsOnly), isTrue);
    final manifest = jsonDecode(File('${_packDir('shapes').path}/manifest.json').readAsStringSync()) as Map<String, dynamic>;
    final listed = {for (final f in manifest['files'] as List<dynamic>) (f as Map<String, dynamic>)['path'] as String};
    for (final w in lessons.expand((l) => l.words)) {
      expect(listed, containsAll([w.image, w.audio, w.phrase]), reason: w.word);
    }
    expect(lessons.every((l) => !l.counting && l.color == null), isTrue);
  });

  test('"tap the circle" offers only other shapes, never a letter picture', () {
    final shapes = CourseUnit(id: 'shapes', order: 4, title: const {'en': 'Shapes'}, icon: 'shapes', color: 'green', lessons: _lessons('shapes'));
    final content = TrackContent(track: 'little-learners', units: [...sampleContent().units, shapes]);
    final shapePictures = shapes.lessons.expand((l) => l.words).map((w) => w.image).toSet();
    for (var seed = 0; seed < 25; seed++) {
      for (final lesson in shapes.lessons) {
        for (final round in buildChoiceRounds(lesson, content, Random(seed))) {
          expect(round.options.map((o) => o.image).toSet().length, round.options.length, reason: 'different pictures');
          for (final o in round.options) {
            expect(shapePictures, contains(o.image), reason: '${round.target.word}: ${o.word} is a shape');
          }
        }
      }
    }
  });


  test('in "Shapes around us" the wrong pictures are the other things of the lesson itself, never a plain shape', () {
    final shapes = CourseUnit(id: 'shapes', order: 4, title: const {'en': 'Shapes'}, icon: 'shapes', color: 'green', lessons: _lessons('shapes'));
    final content = TrackContent(track: 'little-learners', units: [...sampleContent().units, shapes]);
    final around = shapes.lessons.last;
    final own = around.words.map((w) => w.image).toSet();
    for (var seed = 0; seed < 25; seed++) {
      for (final round in buildChoiceRounds(around, content, Random(seed))) {
        expect(round.options.length, 3);
        for (final o in round.options) {
          expect(own, contains(o.image), reason: '${round.target.word}: ${o.word} is one of the four things');
        }
      }
    }
  });
}
