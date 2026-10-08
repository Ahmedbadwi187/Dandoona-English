import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/features/content/content_models.dart';

Map<String, dynamic> _manifest() {
  final index = jsonDecode(File('../../packs/explorers/index.json').readAsStringSync()) as Map<String, dynamic>;
  final entry = (index['packs'] as List<dynamic>).cast<Map<String, dynamic>>().firstWhere((p) => p['unit'] == 'everyday-english');
  return jsonDecode(File('../../packs/explorers/everyday_english/v${entry['version']}/manifest.json').readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  final lessons = [for (final l in _manifest()['lessons'] as List<dynamic>) Lesson.fromJson(l as Map<String, dynamic>)];
  final files = {for (final f in _manifest()['files'] as List<dynamic>) (f as Map<String, dynamic>)['path'] as String};

  test('six lessons (school, weather twice, town, meals, play) with every file in the pack and a spoken instruction for each game', () {
    expect(lessons.map((l) => l.id), ['everyday-english-school', 'everyday-english-weather-1', 'everyday-english-weather-2', 'everyday-english-town', 'everyday-english-meals', 'everyday-english-play']);
    for (final l in lessons) {
      for (final a in l.activities) {
        expect(files, contains(l.audio.instructions[a]), reason: '${l.id}/$a');
      }
      for (final w in l.words) {
        expect(files, containsAll([w.audio, w.image]), reason: w.word);
      }
    }
  });

  test('school, weather and town read sentences with a gap ("It is sunny."), weather and meals show no article', () {
    for (final l in lessons.where((l) => l.id.contains('school') || l.id.contains('weather') || l.id.contains('town'))) {
      expect(l.activities, containsAll(['fill-the-gap', 'sentence-builder']), reason: l.id);
      expect(l.sentences.length, greaterThanOrEqualTo(3), reason: l.id);
      for (final s in l.sentences) {
        expect(files, containsAll([s.audio, s.image]), reason: s.text);
        expect(s.choices, contains(s.gap), reason: s.text);
      }
    }
    expect(lessons.where((l) => l.noArticle).map((l) => l.id), ['everyday-english-weather-1', 'everyday-english-weather-2', 'everyday-english-meals']);
  });
}
