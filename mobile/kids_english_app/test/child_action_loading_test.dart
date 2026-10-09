import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/core/loading_action.dart';
import 'package:kids_english_app/core/palette.dart';
import 'package:kids_english_app/core/widgets.dart';
import 'package:kids_english_app/features/activities/activity_logic.dart';
import 'package:kids_english_app/features/activities/listen_and_tap_activity.dart';
import 'package:kids_english_app/features/activities/record_listen_activity.dart';
import 'package:kids_english_app/features/audio/audio_service.dart';

import 'helpers.dart';

class _PendingRecorder extends FakeRecorder {
  final permissionResult = Completer<bool>();
  int permissionRequests = 0;

  @override
  Future<bool> requestPermission() {
    permissionRequests++;
    return permissionResult.future;
  }
}

class _PendingAudio extends FakeAudio {
  Completer<void>? playback;

  @override
  Future<void> playAsset(String assetPath) async {
    played.add('asset:$assetPath');
    await playback?.future;
  }
}

void main() {
  testWidgets(
    'record startup shows progress, then recording can be stopped immediately',
    (tester) async {
      final audio = _PendingAudio();
      final recorder = _PendingRecorder();
      final content = realContent();
      final overrides = await testOverrides(content: content);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            audioServiceProvider.overrideWithValue(audio),
            recorderServiceProvider.overrideWithValue(recorder),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: RecordListenActivity(
                lesson: content.lessonById('letter-a')!,
                onFinished: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final mic = find.byKey(const Key('record-mic'));
      Finder progress() => find.descendant(
        of: find.ancestor(of: mic, matching: find.byType(BigTap)).first,
        matching: find.byType(CircularProgressIndicator),
      );

      await tester.tap(mic);
      await tester.pump();
      expect(progress(), findsOneWidget);
      await tester.tap(mic);
      await tester.pump();
      expect(recorder.permissionRequests, 1);

      recorder.permissionResult.complete(true);
      await tester.pump();
      expect(recorder.started, 1);
      expect(progress(), findsNothing);
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);

      audio.playback = Completer<void>();
      await tester.tap(mic);
      await tester.pump();
      expect(recorder.created, hasLength(1));
      expect(progress(), findsOneWidget);
      await tester.tap(mic);
      await tester.pump();
      expect(recorder.created, hasLength(1));

      audio.playback!.complete();
      await tester.pumpAndSettle();
      expect(recorder.deleted, recorder.created);
      expect(progress(), findsNothing);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    },
  );

  testWidgets('audio replay shows progress while an answer still responds', (
    tester,
  ) async {
    final audio = _PendingAudio();
    final content = realContent();
    final lesson = content.lessonById('letter-a')!;
    final round = buildChoiceRounds(lesson, content, Random(2)).first;
    final overrides = await testOverrides(content: content);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          audioServiceProvider.overrideWithValue(audio),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ListenAndTapActivity(
              lesson: lesson,
              track: content,
              random: Random(2),
              onFinished: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final hear = find.byKey(const Key('hear-again'));
    final before = tester.getSize(hear);
    audio.playback = Completer<void>();
    await tester.tap(hear);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.getSize(hear), before);

    final answer = find.byKey(Key('option-${round.target.word}'));
    await tester.tap(answer);
    await tester.pump();
    final card = tester.widget<Container>(
      find.descendant(of: answer, matching: find.byType(Container)).first,
    );
    expect(
      ((card.decoration! as BoxDecoration).border! as Border).top.color,
      Palette.green,
    );
    expect(
      find.descendant(of: answer, matching: find.byType(LoadingOverlay)),
      findsOneWidget,
    );

    audio.playback!.complete();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
