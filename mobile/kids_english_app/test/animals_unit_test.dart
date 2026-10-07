import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/features/activities/activity_logic.dart';
import 'package:kids_english_app/features/content/content_models.dart';

import 'helpers.dart';

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
  test('Animals has fifteen animals in five lessons, every picture, word and phrase is a file of the pack', () {
    final lessons = _lessons('animals');
    expect(lessons.map((l) => l.id), ['animals-1', 'animals-2', 'animals-3', 'animals-4', 'animals-5']);
    final words = lessons.expand((l) => l.words).toList();
    expect(words.map((w) => w.word), ['cat', 'dog', 'rabbit', 'cow', 'pig', 'horse', 'duck', 'fish', 'frog', 'lion', 'elephant', 'monkey', 'bear', 'tiger', 'zebra']);
    final manifest = jsonDecode(File('${_packDir('animals').path}/manifest.json').readAsStringSync()) as Map<String, dynamic>;
    final listed = {for (final f in manifest['files'] as List<dynamic>) (f as Map<String, dynamic>)['path'] as String};
    for (final w in words) {
      expect(listed, containsAll([w.image, w.audio, w.phrase]), reason: w.word);
      expect(File('${_packDir('animals').path}/${w.image}').existsSync(), isTrue, reason: w.image);
    }
    expect(words.map((w) => w.phrase!.isNotEmpty).every((x) => x), isTrue);
  });

  test('"tap the cat" offers only other animals, never a letter or a shape picture', () {
    final animals = CourseUnit(id: 'animals', order: 5, title: const {'en': 'Animals'}, icon: 'animals', color: 'teal', lessons: _lessons('animals'));
    final content = TrackContent(track: 'little-learners', units: [...sampleContent().units, animals]);
    final pictures = animals.lessons.expand((l) => l.words).map((w) => w.image).toSet();
    for (var seed = 0; seed < 20; seed++) {
      for (final lesson in animals.lessons) {
        for (final round in buildChoiceRounds(lesson, content, Random(seed))) {
          expect(round.options.map((o) => o.image).toSet().length, 3);
          for (final o in round.options) {
            expect(pictures, contains(o.image), reason: '${round.target.word}: ${o.word} is an animal');
          }
        }
      }
    }
  });
}
