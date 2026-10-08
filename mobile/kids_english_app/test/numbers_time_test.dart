import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/features/content/content_models.dart';

Map<String, dynamic> _manifest() {
  final index = jsonDecode(File('../../packs/explorers/index.json').readAsStringSync()) as Map<String, dynamic>;
  final entry = (index['packs'] as List<dynamic>).cast<Map<String, dynamic>>().firstWhere((p) => p['unit'] == 'numbers-time');
  return jsonDecode(File('../../packs/explorers/numbers_time/v${entry['version']}/manifest.json').readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  final lessons = [for (final l in _manifest()['lessons'] as List<dynamic>) Lesson.fromJson(l as Map<String, dynamic>)];
  final files = {for (final f in _manifest()['files'] as List<dynamic>) (f as Map<String, dynamic>)['path'] as String};
  final words = lessons.expand((l) => l.words).map((w) => w.word).toList();

  test('numbers to 100, the days, the months and the clock: 15 lessons of three or four words, all files in the pack, no article before the words', () {
    expect(lessons.length, 15);
    for (final l in lessons) {
      expect(l.noArticle, isTrue, reason: l.id);
      expect(l.words.length, inInclusiveRange(3, 4), reason: l.id);
      expect(l.activities, ['listen-and-tap', 'read-and-pick', 'match-picture', 'memory'], reason: l.id);
      for (final a in l.activities) {
        expect(files, contains(l.audio.instructions[a]), reason: '${l.id}/$a');
      }
      for (final w in l.words) {
        expect(files, containsAll([w.audio, w.image]), reason: w.word);
      }
    }
  });

  test('the words: eleven to nineteen, the tens to one hundred, seven days, twelve months and twelve o\'clocks, each once', () {
    expect(words.toSet().length, words.length);
    expect(words, containsAll(['eleven', 'nineteen', 'twenty', 'ninety', 'hundred', 'Monday', 'Sunday', 'January', 'December', "one o'clock", "twelve o'clock"]));
    expect(words.where((w) => w.endsWith("o'clock")).length, 12);
    expect(words.length, 9 + 9 + 7 + 12 + 12);
  });
}
