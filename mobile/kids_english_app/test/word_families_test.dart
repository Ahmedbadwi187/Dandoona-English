import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/features/content/content_models.dart';

/// The newest Word Families pack of the Explorers track, as the app downloads it.
Map<String, dynamic> _manifest() {
  final index = jsonDecode(File('../../packs/explorers/index.json').readAsStringSync()) as Map<String, dynamic>;
  final entry = (index['packs'] as List<dynamic>).cast<Map<String, dynamic>>().firstWhere((p) => p['unit'] == 'word-families');
  return jsonDecode(File('../../packs/explorers/word_families/v${entry['version']}/manifest.json').readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  final lessons = [for (final l in _manifest()['lessons'] as List<dynamic>) Lesson.fromJson(l as Map<String, dynamic>)];
  final files = {for (final f in _manifest()['files'] as List<dynamic>) (f as Map<String, dynamic>)['path'] as String};

  test('six families, each with the four games, a spoken instruction for each and every file in the pack', () {
    expect(lessons.map((l) => l.id), ['word-families-at', 'word-families-an', 'word-families-ig', 'word-families-ot', 'word-families-ug', 'word-families-un']);
    for (final l in lessons) {
      expect(l.activities, ['sound-tap', 'word-builder', 'spell-it', 'read-and-pick'], reason: l.id);
      for (final a in l.activities) {
        expect(files, contains(l.audio.instructions[a]), reason: '${l.id}/$a');
      }
      for (final w in l.words) {
        expect(files, containsAll([w.audio, w.image]), reason: w.word);
      }
    }
  });

  test('the words of a family end alike (the same last letters), and the letters spell the word', () {
    for (final l in lessons) {
      final ending = l.id.split('-').last; // at, an, ig, ot, ug, un
      for (final w in l.words) {
        expect(w.word.endsWith(ending), isTrue, reason: '${l.id}: ${w.word}');
        expect(w.graphemes.map((g) => g.split(':').first).join(), w.word, reason: w.word);
      }
    }
  });
}
