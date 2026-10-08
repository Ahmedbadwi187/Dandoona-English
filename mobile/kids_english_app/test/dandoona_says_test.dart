import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/features/activities/activity_logic.dart';
import 'package:kids_english_app/features/activities/dandoona_says_activity.dart';
import 'package:kids_english_app/features/audio/audio_service.dart';
import 'package:kids_english_app/features/content/content_models.dart';

import 'helpers.dart';
import 'pack_helpers.dart';

void main() {
  final lessons = packLessons('actions');
  final bundled = {for (final w in realContent().lessons.expand((l) => l.words)) w.image}.toList();
  // the pack pictures are downloaded files; the widget tests use bundled ones
  final shown = [
    for (final l in packManifest('actions')['lessons'] as List<dynamic>)
      Lesson.fromJson({
        ...(l as Map<String, dynamic>),
        'words': [for (final (i, w) in (l['words'] as List<dynamic>).indexed) {...(w as Map<String, dynamic>), 'image': bundled[i]}],
      }),
  ];

  test('every Dandoona-says lesson of Actions has a spoken line for each of its words and for how to play, all files of the pack', () {
    final withSays = lessons.where((l) => l.activities.contains('dandoona-says')).toList();
    expect(withSays, isNotEmpty);
    for (final l in withSays) {
      expect(l.audio.instructions, contains('dandoona-says'), reason: l.id);
      expect(packFiles('actions'), contains(l.audio.instructions['dandoona-says']), reason: l.id);
      for (final w in l.words) {
        expect(w.says, isNotNull, reason: '${l.id}/${w.word}');
        expect(packFiles('actions'), contains(w.says), reason: '${l.id}/${w.word}');
      }
    }
  });

  Future<FakeAudio> pump(WidgetTester t, Widget child) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 1080 / 411;
    addTearDown(t.view.reset);
    final audio = FakeAudio();
    final overrides = await testOverrides(content: realContent());
    await t.pumpWidget(ProviderScope(overrides: [...overrides, audioServiceProvider.overrideWithValue(audio)], child: MaterialApp(home: Scaffold(body: child))));
    await t.pump();
    await t.pump();
    return audio;
  }

  testWidgets('each action is said by Dandoona, the green check moves on, and the end always gives three stars', (t) async {
    final lesson = shown.firstWhere((l) => l.activities.contains('dandoona-says'));
    ActivityResult? result;
    final audio = await pump(t, DandoonaSaysActivity(lesson: lesson, random: Random(1), onFinished: (r) => result = r));
    expect(audio.played.first, 'asset:${lesson.audio.instructions['dandoona-says']}');
    final says = {for (final w in lesson.words) 'asset:${w.says}'};
    expect(says, contains(audio.played.last));

    for (var i = 0; i < lesson.words.length; i++) {
      expect(result, isNull);
      await t.tap(find.byKey(const Key('says-done')));
      await t.pump();
    }
    expect(result, isNotNull);
    expect(result!.stars, 3);
    expect(result!.attempts, lesson.words.length);
    // every action was said once
    expect(audio.played.where(says.contains).toSet().length, lesson.words.length);
  });

  testWidgets('the gentle timer moves on by itself when the ring is full, and the picture says the line again', (t) async {
    final lesson = shown.firstWhere((l) => l.activities.contains('dandoona-says'));
    ActivityResult? result;
    final audio = await pump(t, DandoonaSaysActivity(lesson: lesson, random: Random(1), turn: const Duration(seconds: 2), onFinished: (r) => result = r));
    final first = audio.played.last;
    await t.tap(find.byKey(const Key('says-picture')));
    await t.pump();
    expect(audio.played.last, first); // the same line again
    expect(t.widget<CircularProgressIndicator>(find.byKey(const Key('says-ring'))).value, isNotNull);

    for (var i = 0; i < lesson.words.length; i++) {
      await t.pump(const Duration(seconds: 3));
    }
    expect(result, isNotNull);
    expect(result!.stars, 3);
  });
}
