import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/features/activities/activity_logic.dart';
import 'package:kids_english_app/features/content/content_models.dart';

import 'helpers.dart';
import 'pack_helpers.dart';

/// Every downloadable pack of the course, as the app gets it: all its files are there, every word has its picture, voice and phrase,
/// and the games can always be played (three different pictures to choose from).
void main() {
  final catalog = realContent();
  final packUnits = [for (final u in catalog.units) if (u.pack != null) u];

  test('thirteen units are packs; Letters and Colors are bundled', () {
    expect(packUnits.length, 13);
    expect(catalog.units.where((u) => u.pack == null).map((u) => u.id), ['letters', 'colors']);
  });

  for (final unit in packUnits) {
    test('${unit.id}: every file of the pack exists, every word has a picture, a voice and a phrase, and the games always have three choices', () {
      expect(hasPack(unit.id), isTrue);
      final dir = packDir(unit.id);
      final listed = packFiles(unit.id);
      for (final f in listed) {
        expect(File('${dir.path}/$f').existsSync(), isTrue, reason: '${unit.id}: $f');
      }
      final lessons = packLessons(unit.id);
      expect(lessons.map((l) => l.id), unit.pack!.lessonIds, reason: 'the catalog lists the same lessons as the pack');
      final content = TrackContent(track: 'little-learners', units: [...sampleContent().units, unit.withLessons(lessons)]);
      for (final l in lessons) {
        expect(l.words.length, greaterThanOrEqualTo(2));
        for (final w in l.words) {
          expect(listed, containsAll([w.image, w.audio]), reason: '${l.id}/${w.word}');
          expect(w.phrase, isNotNull, reason: '${l.id}/${w.word} has a phrase');
          expect(listed, contains(w.phrase), reason: '${l.id}/${w.word}');
        }
        expect(listed, containsAll([l.audio.intro, ...l.audio.praise]));
        for (var seed = 0; seed < 5; seed++) {
          for (final r in buildChoiceRounds(l, content, Random(seed))) {
            expect(r.options.map((o) => o.image).toSet().length, 3, reason: '${l.id}/${r.target.word}');
          }
        }
      }
    });
  }
}
