import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/app.dart';
import 'package:kids_english_app/features/units/unit_meta.dart';
import 'package:kids_english_app/features/audio/audio_service.dart';
import 'package:kids_english_app/features/certificate/certificate_card.dart';
import 'package:kids_english_app/features/certificate/certificate_sharer.dart';
import 'package:kids_english_app/features/progress/progress.dart';

import 'helpers.dart';

const _child = '[{"id":"c1","name":"Omar","avatarKey":"star","birthYear":2022,"track":"little-learners","createdAt":"2026-01-01T00:00:00Z"}]';

class _FakeSharer implements CertificateSharer {
  final shared = <(Uint8List, String)>[];
  @override
  Future<bool> share(Uint8List png, String fileName, {String? text}) async {
    shared.add((png, fileName));
    return true;
  }
}

String _progress(Iterable<String> lessons) => jsonEncode([
      for (final l in lessons)
        ProgressRecord(
          clientRecordId: 'r-$l',
          childId: 'c1',
          lessonId: l,
          activity: 'listen-and-tap',
          stars: 3,
          attempts: 3,
          timeSpentSeconds: 10,
          completedAt: DateTime.utc(2026, 9, 1),
        ).toJson(),
    ]);

final _letters = [for (var i = 0; i < 26; i++) 'letter-${String.fromCharCode(97 + i)}'];

Future<(FakeAudio, _FakeSharer, ProviderContainer)> _open(WidgetTester t, {required String progress}) async {
  final audio = FakeAudio();
  final sharer = _FakeSharer();
  final overrides = await testOverrides(content: realContent(), prefs: {
    'settings.v1': '{"languageCode":"ar","sessionMinutes":15,"unlockAll":false,"onboarded":true}',
    'children.v1': _child,
    'progress.v1': progress,
  });
  final container = ProviderContainer(overrides: [
    ...overrides,
    audioServiceProvider.overrideWithValue(audio),
    recorderServiceProvider.overrideWithValue(FakeRecorder()),
    certificateSharerProvider.overrideWithValue(sharer),
  ]);
  addTearDown(container.dispose);
  await t.pumpWidget(UncontrolledProviderScope(container: container, child: const KidsEnglishApp()));
  await t.pumpAndSettle();
  return (audio, sharer, container);
}

Future<void> _passGate(WidgetTester t) async {
  final gesture = await t.startGesture(t.getCenter(find.byKey(const Key('gate-hold'))));
  await t.pump(const Duration(milliseconds: 200));
  await t.pump(const Duration(seconds: 3));
  await gesture.up();
  await t.pump();
  final q = t.widget<Text>(find.byKey(const Key('gate-question'))).data!; // "7 × 9 = ?"
  final m = RegExp(r'(\d+) × (\d+)').firstMatch(q)!;
  await t.tap(find.byKey(Key('gate-option-${int.parse(m[1]!) * int.parse(m[2]!)}')));
  await t.pump(const Duration(milliseconds: 600));
}

void main() {
  test('dates read as 7 Oct 2026', () {
    expect(prettyDate('2026-10-07'), '7 Oct 2026');
    expect(prettyDate('2026-01-31'), '31 Jan 2026');
    expect(prettyDate('garbage'), 'garbage');
  });

  testWidgets('the certificate card shows the name, the unit and the date', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(body: CertificateCard(childName: 'Omar', unitTitle: 'Colors', date: '7 Oct 2026', mascot: null)),
    ));
    expect(find.text('Omar'), findsOneWidget);
    expect(find.text('Colors'), findsOneWidget);
    expect(find.text('7 Oct 2026'), findsOneWidget);
    expect(find.text('CERTIFICATE'), findsOneWidget);
  });

  testWidgets('the Letters certificate is already unlocked for a child who had finished Letters, and can be opened from the map', (t) async {
    await _open(t, progress: _progress(_letters));
    await t.tap(find.byKey(const Key('unit-certificate-letters')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('certificate-name')), findsOneWidget);
    expect(t.widget<Text>(find.byKey(const Key('certificate-name'))).data, 'Omar');
    expect(t.widget<Text>(find.byKey(const Key('certificate-unit'))).data, 'Letters');
    expect(t.widget<Text>(find.byKey(const Key('certificate-date'))).data, '1 Sep 2026'); // the date they finished, from their old progress
    await t.tap(find.byKey(const Key('certificate-done')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('unit-map')), findsOneWidget);
  });

  testWidgets('sharing the certificate asks the parental gate first, then hands a PNG picture to the share sheet', (t) async {
    final (_, sharer, _) = await _open(t, progress: _progress(_letters));
    await t.tap(find.byKey(const Key('unit-certificate-letters')));
    await t.pumpAndSettle();

    await t.tap(find.byKey(const Key('certificate-share')));
    await t.pump();
    expect(find.byKey(const Key('gate-hold')), findsOneWidget); // behind the gate
    expect(sharer.shared, isEmpty);
    await _passGate(t);
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500))); // the picture is rendered on the device
    await t.pump();

    expect(sharer.shared, hasLength(1));
    final (png, name) = sharer.shared.single;
    expect(name, 'certificate-letters.png');
    expect(png.sublist(0, 8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]); // a real PNG
  });

  testWidgets('a child who finishes the last lesson of a unit gets the celebration, then the certificate; it is shown only once', (t) async {
    final (audio, _, container) = await _open(t, progress: _progress(_letters.take(25)));
    await t.tap(find.byKey(const Key('unit-play-letters')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('unit-letters')), findsNothing);
    await t.scrollUntilVisible(find.byKey(const Key('node-letter-z')), 200, scrollable: find.descendant(of: find.byKey(const Key('letter-map')), matching: find.byType(Scrollable)));
    await t.tap(find.byKey(const Key('node-letter-z')));
    await t.pumpAndSettle();
    await t.ensureVisible(find.byKey(const Key('activity-listen-and-tap')));
    await t.tap(find.byKey(const Key('activity-listen-and-tap')));
    await t.pump();

    final z = realContent().lessonById('letter-z')!;
    for (var i = 0; i < z.words.length; i++) {
      final last = audio.played.lastWhere((p) => z.words.any((w) => 'asset:${w.audio}' == p));
      final target = z.words.firstWhere((w) => 'asset:${w.audio}' == last);
      await t.tap(find.byKey(Key('option-${target.word}')));
      await t.pump(const Duration(seconds: 1));
    }
    await t.pump(const Duration(seconds: 2));
    await t.tap(find.byKey(const Key('result-done')));
    await t.pumpAndSettle(const Duration(milliseconds: 200), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 10));

    expect(find.byKey(const Key('celebration-hooray')), findsOneWidget);
    expect(t.widget<Text>(find.byKey(const Key('celebration-unit'))).data, 'Letters');
    expect(audio.played, contains('asset:audio/little_learners/unit_letters/instr_celebration.mp3'));
    final meta = container.read(unitMetaProvider);
    expect(meta.of('c1').celebrated, contains('letters'));
    expect(meta.of('c1').certificates.containsKey('letters'), isTrue);

    await t.tap(find.byKey(const Key('celebration-continue')));
    await t.pumpAndSettle();
    expect(t.widget<Text>(find.byKey(const Key('certificate-name'))).data, 'Omar');
    expect(t.widget<Text>(find.byKey(const Key('certificate-unit'))).data, 'Letters');
    await t.tap(find.byKey(const Key('certificate-done')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('unit-done-letters')), findsOneWidget);
    expect(find.byKey(const Key('unit-play-colors')), findsOneWidget); // the next unit is open
  });
}
