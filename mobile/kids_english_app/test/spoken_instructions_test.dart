import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/features/activities/listen_and_tap_activity.dart';
import 'package:kids_english_app/features/activities/match_picture_activity.dart';
import 'package:kids_english_app/features/activities/record_listen_activity.dart';
import 'package:kids_english_app/features/activities/trace_activity.dart';
import 'package:kids_english_app/features/audio/activity_speech.dart';
import 'package:kids_english_app/features/audio/audio_service.dart';
import 'package:kids_english_app/features/content/content_models.dart';

import 'helpers.dart';

const _instr = {
  'trace': 'audio/x/instr_trace.mp3',
  'listen-and-tap': 'audio/x/instr_listen.mp3',
  'record-and-listen': 'audio/x/instr_record.mp3',
  'match-picture': 'audio/x/instr_match.mp3',
  'hint': 'audio/x/instr_hint.mp3',
};

/// The real lessons with spoken instructions added to the first one (the exported file only has them after the audio is generated).
TrackContent _content({bool withInstructions = true}) {
  final c = realContent();
  final first = c.lessons.first.id;
  return TrackContent.fromJson({
    'schemaVersion': 1,
    'track': 'little-learners',
    'lessons': [
      for (final l in c.lessons)
        {
          'id': l.id,
          'order': l.order,
          'level': l.level,
          'letter': l.letter,
          'phoneme': l.phoneme,
          'audio': {
            'intro': l.audio.intro,
            'phoneme': l.audio.phoneme,
            'praise': l.audio.praise,
            if (withInstructions && l.id == first) 'instructions': _instr,
          },
          'words': [
            for (final w in l.words) {'word': w.word, 'audio': w.audio, 'image': w.image},
          ],
          'activities': l.activities,
        },
    ],
  });
}

Future<FakeAudio> _pump(WidgetTester t, TrackContent content, Widget Function(Lesson) build) async {
  final audio = FakeAudio();
  final overrides = await testOverrides(content: content);
  await t.pumpWidget(ProviderScope(
    overrides: [...overrides, audioServiceProvider.overrideWithValue(audio), recorderServiceProvider.overrideWithValue(FakeRecorder())],
    child: MaterialApp(home: Scaffold(body: build(content.lessons.first))),
  ));
  await t.pump();
  return audio;
}

/// A player whose first clip stays "playing" until released, to prove a newer action cuts the old sequence.
class _HeldAudio extends FakeAudio {
  final Completer<void> release = Completer<void>();
  @override
  Future<void> playAsset(String assetPath) async {
    played.add('asset:$assetPath');
    if (played.length == 1) await release.future;
  }
}

void main() {
  test('lessons without instructions (older exports) still load', () {
    expect(_content(withInstructions: false).lessons.first.audio.instructions, isEmpty);
    expect(_content().lessons.first.audio.instructions['trace'], 'audio/x/instr_trace.mp3');
  });

  group('ActivitySpeech', () {
    test('says the instruction, then the clip', () async {
      final audio = FakeAudio();
      await ActivitySpeech(audio).say(instruction: 'i.mp3', then: 'w.mp3');
      expect(audio.played, ['asset:i.mp3', 'asset:w.mp3']);
    });

    test('a newer call cuts the rest of an older sequence (a late clip must not play over the next action)', () async {
      final audio = _HeldAudio();
      final speech = ActivitySpeech(audio);
      final first = speech.say(instruction: 'i.mp3', then: 'w.mp3');
      await speech.say(then: 'praise.mp3');
      audio.release.complete();
      await first;
      expect(audio.played, ['asset:i.mp3', 'asset:praise.mp3']);
    });

    test('missing instructions are skipped', () async {
      final audio = FakeAudio();
      await ActivitySpeech(audio).say(instruction: null, then: 'w.mp3');
      expect(audio.played, ['asset:w.mp3']);
    });
  });

  group('every activity speaks its instruction when it starts', () {
    testWidgets('listen-and-tap: instruction, then the word', (t) async {
      final content = _content();
      final audio = await _pump(t, content, (l) => ListenAndTapActivity(lesson: l, track: content, random: Random(1), onFinished: (_) {}));
      expect(audio.played.first, 'asset:${_instr['listen-and-tap']}');
      expect(audio.played[1], startsWith('asset:audio/little_learners/letter_a/word_'));
    });

    testWidgets('trace: instruction, and the speaker button says it again', (t) async {
      final audio = await _pump(t, _content(), (l) => TraceActivity(lesson: l, onFinished: (_) {}));
      expect(audio.played, ['asset:${_instr['trace']}']);
      await t.tap(find.byKey(const Key('trace-hear')));
      await t.pump();
      expect(audio.played, ['asset:${_instr['trace']}', 'asset:${_instr['trace']}']);
    });

    testWidgets('record-and-listen: instruction, then the word', (t) async {
      final content = _content();
      final audio = await _pump(t, content, (l) => RecordListenActivity(lesson: l, onFinished: (_) {}));
      expect(audio.played.first, 'asset:${_instr['record-and-listen']}');
      expect(audio.played[1], 'asset:${content.lessons.first.words.first.audio}');
    });

    testWidgets('match-picture: instruction', (t) async {
      final audio = await _pump(t, _content(), (l) => MatchPictureActivity(lesson: l, onFinished: (_) {}, random: Random(1)));
      expect(audio.played, ['asset:${_instr['match-picture']}']);
    });

    testWidgets('lessons without instruction audio stay quiet (no crash)', (t) async {
      final audio = await _pump(t, _content(withInstructions: false), (l) => TraceActivity(lesson: l, onFinished: (_) {}));
      expect(audio.played, isEmpty);
    });
  });

  group('hints', () {
    testWidgets('listen-and-tap: nothing tapped for a while lights up the right picture and says the hint and the word', (t) async {
      final content = _content();
      final audio = await _pump(
        t,
        content,
        (l) => ListenAndTapActivity(lesson: l, track: content, random: Random(1), hintAfter: const Duration(milliseconds: 500), onFinished: (_) {}),
      );
      final target = content.lessons.first.words.firstWhere((w) => audio.played.last == 'asset:${w.audio}');
      audio.played.clear();
      await t.pump(const Duration(milliseconds: 600));
      expect(audio.played, ['asset:${_instr['hint']}', 'asset:${target.audio}']);
      final box = t.widget<Container>(find.descendant(of: find.byKey(Key('option-${target.word}')), matching: find.byType(Container)).first);
      expect((box.decoration! as BoxDecoration).border!.top.width, 10); // highlighted
      await t.pumpWidget(const SizedBox()); // disposing cancels the repeating hint timer
    });

    testWidgets('listen-and-tap: two wrong taps in a row give the hint', (t) async {
      final content = _content();
      final audio = await _pump(t, content, (l) => ListenAndTapActivity(lesson: l, track: content, random: Random(1), onFinished: (_) {}));
      final words = content.lessons.first.words;
      final target = words.firstWhere((w) => audio.played.last == 'asset:${w.audio}');
      final wrongKey = t
          .widgetList<GestureDetector>(find.byType(GestureDetector))
          .map((g) => g.key)
          .whereType<Key>()
          .firstWhere((k) => '$k'.contains('option-') && !'$k'.contains("option-${target.word}'"));
      audio.played.clear();
      await t.tap(find.byKey(wrongKey));
      await t.pump(const Duration(milliseconds: 700));
      expect(audio.played, ['asset:${target.audio}']); // first mistake: just the word again
      audio.played.clear();
      await t.tap(find.byKey(wrongKey));
      await t.pump(const Duration(milliseconds: 700));
      expect(audio.played, ['asset:${_instr['hint']}', 'asset:${target.audio}']);
    });
  });
}
