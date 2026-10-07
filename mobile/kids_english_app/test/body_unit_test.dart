import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/features/activities/activity_logic.dart';
import 'package:kids_english_app/features/content/content_models.dart';

import 'helpers.dart';
import 'pack_helpers.dart';

void main() {
  test('My Body has six parts in two lessons; every picture, word and phrase is a file of the pack', () {
    final lessons = packLessons('my-body');
    expect(lessons.map((l) => l.id), ['my-body-1', 'my-body-2']);
    final words = lessons.expand((l) => l.words).toList();
    expect(words.map((w) => w.word), ['eye', 'ear', 'nose', 'mouth', 'hand', 'foot']);
    final listed = packFiles('my-body');
    for (final w in words) {
      expect(listed, containsAll([w.image, w.audio, w.phrase]), reason: w.word);
    }
  });

  test('"tap the nose" offers only other body parts', () {
    final body = CourseUnit(id: 'my-body', order: 7, title: const {'en': 'My Body'}, icon: 'body', color: 'pink', lessons: packLessons('my-body'));
    final content = TrackContent(track: 'little-learners', units: [...sampleContent().units, body]);
    final parts = body.lessons.expand((l) => l.words).map((w) => w.image).toSet();
    for (var seed = 0; seed < 20; seed++) {
      for (final lesson in body.lessons) {
        for (final round in buildChoiceRounds(lesson, content, Random(seed))) {
          expect(round.options.map((o) => o.image).toSet().length, 3);
          for (final o in round.options) {
            expect(parts, contains(o.image), reason: '${round.target.word}: ${o.word} is a body part');
          }
        }
      }
    }
  });
}
