import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/features/content/content_models.dart';

Map<String, dynamic> _manifest() {
  final index = jsonDecode(File('../../packs/explorers/index.json').readAsStringSync()) as Map<String, dynamic>;
  final entry = (index['packs'] as List<dynamic>).cast<Map<String, dynamic>>().firstWhere((p) => p['unit'] == 'grammar-starters');
  return jsonDecode(File('../../packs/explorers/grammar_starters/v${entry['version']}/manifest.json').readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  final lessons = [for (final l in _manifest()['lessons'] as List<dynamic>) Lesson.fromJson(l as Map<String, dynamic>)];
  final files = {for (final f in _manifest()['files'] as List<dynamic>) (f as Map<String, dynamic>)['path'] as String};

  test('four lessons (a/an, is/are, has/have, can); every sentence has its audio and picture and a gap word among its choices', () {
    expect(lessons.map((l) => l.id), ['grammar-starters-a-an', 'grammar-starters-is-are', 'grammar-starters-has-have', 'grammar-starters-can']);
    for (final l in lessons) {
      expect(l.activities, ['fill-the-gap', 'sentence-builder', 'read-and-pick', 'true-or-false'], reason: l.id);
      for (final a in l.activities) {
        expect(files, contains(l.audio.instructions[a]), reason: '${l.id}/$a');
      }
      for (final s in l.sentences) {
        expect(files, containsAll([s.audio, s.image]), reason: s.text);
        expect(s.choices, contains(s.gap), reason: s.text);
      }
    }
  });

  test('the pictures tell the word: one thing takes is/has, two things take are/have (never named)', () {
    for (final l in lessons.where((l) => l.id.contains('is-are') || l.id.contains('has-have'))) {
      for (final s in l.sentences) {
        final one = s.gap == 'is' || s.gap == 'has';
        expect(s.two, !one, reason: s.text);
      }
    }
    final an = lessons.first.sentences;
    for (final s in an) {
      final next = s.text.split(' ')[s.text.split(' ').indexOf(s.gap!) + 1];
      expect(s.gap == 'an', 'aeiou'.contains(next[0]), reason: s.text);
    }
  });
}
