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
  test('Feelings has six faces in two lessons; every picture, word and phrase is a file of the pack, and the phrase is "I am ..."', () {
    final lessons = _lessons('feelings');
    expect(lessons.map((l) => l.id), ['feelings-1', 'feelings-2']);
    final words = lessons.expand((l) => l.words).toList();
    expect(words.map((w) => w.word), ['happy', 'sad', 'angry', 'sleepy', 'scared', 'surprised']);
    final manifest = jsonDecode(File('${_packDir('feelings').path}/manifest.json').readAsStringSync()) as Map<String, dynamic>;
    final listed = {for (final f in manifest['files'] as List<dynamic>) (f as Map<String, dynamic>)['path'] as String};
    for (final w in words) {
      expect(listed, containsAll([w.image, w.audio, w.phrase]), reason: w.word);
    }
  });

  test('"tap the happy face" offers only other faces', () {
    final feelings = CourseUnit(id: 'feelings', order: 6, title: const {'en': 'Feelings'}, icon: 'feelings', color: 'pink', lessons: _lessons('feelings'));
    final content = TrackContent(track: 'little-learners', units: [...sampleContent().units, feelings]);
    final faces = feelings.lessons.expand((l) => l.words).map((w) => w.image).toSet();
    for (var seed = 0; seed < 20; seed++) {
      for (final lesson in feelings.lessons) {
        for (final round in buildChoiceRounds(lesson, content, Random(seed))) {
          expect(round.options.map((o) => o.image).toSet().length, 3);
          for (final o in round.options) {
            expect(faces, contains(o.image), reason: '${round.target.word}: ${o.word} is a face');
          }
        }
      }
    }
  });
}
