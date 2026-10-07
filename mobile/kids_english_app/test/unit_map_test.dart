import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/app.dart';
import 'package:kids_english_app/core/storage.dart';
import 'package:kids_english_app/core/widgets.dart';
import 'package:kids_english_app/features/audio/audio_service.dart';
import 'package:kids_english_app/features/progress/progress.dart';
import 'package:kids_english_app/router.dart';

import 'helpers.dart';

const _child = '[{"id":"c1","name":"Omar","avatarKey":"star","birthYear":2022,"track":"little-learners","createdAt":"2026-01-01T00:00:00Z"}]';

String _settings({bool unlockAll = false}) => '{"languageCode":"ar","sessionMinutes":15,"unlockAll":$unlockAll,"onboarded":true}';

String _progress(Iterable<String> lessons, {String child = 'c1'}) => jsonEncode([
      for (final l in lessons)
        ProgressRecord(
          clientRecordId: 'r-$l',
          childId: child,
          lessonId: l,
          activity: 'listen-and-tap',
          stars: 3,
          attempts: 3,
          timeSpentSeconds: 10,
          completedAt: DateTime.utc(2026, 9, 1),
        ).toJson(),
    ]);

final _letters = [for (var i = 0; i < 26; i++) 'letter-${String.fromCharCode(97 + i)}'];

Future<(FakeAudio, ProviderContainer)> _openMap(WidgetTester t, {String? progress, bool unlockAll = false}) async {
  final audio = FakeAudio();
  final overrides = await testOverrides(content: realContent(), prefs: {
    'settings.v1': _settings(unlockAll: unlockAll),
    'children.v1': _child,
    'progress.v1': ?progress,
  });
  final container = ProviderContainer(overrides: [...overrides, audioServiceProvider.overrideWithValue(audio), recorderServiceProvider.overrideWithValue(FakeRecorder())]);
  addTearDown(container.dispose);
  await t.pumpWidget(UncontrolledProviderScope(container: container, child: const KidsEnglishApp()));
  await t.pumpAndSettle();
  return (audio, container);
}

IconData _iconOf(WidgetTester t, String unit) => t.widget<Icon>(find.byKey(Key('unit-icon-$unit'))).icon!;

/// Scrolls the map so a stop is in the middle of the screen (clear of the top bar).
Future<void> _center(WidgetTester t, String key) async {
  await Scrollable.ensureVisible(t.element(find.byKey(Key(key))), alignment: 0.5);
  await t.pumpAndSettle();
}

/// The progress ring around the current island's badge carries "done/total" for screen readers.
String? _ring(WidgetTester t, String unit) => t.widget<Semantics>(find.byKey(Key('unit-progress-$unit'))).properties.value;

void main() {
  testWidgets('a new child: Dandoona greets them by name, Letters is the current unit with a progress ring and a play button, the rest wait', (t) async {
    await _openMap(t);
    expect(find.byKey(const Key('unit-map')), findsOneWidget);
    expect(find.text('Hi, Omar!'), findsOneWidget);
    expect(t.widget<Text>(find.byKey(const Key('total-stars'))).data, '0');

    expect(find.byKey(const Key('unit-play-letters')), findsOneWidget);
    expect(_ring(t, 'letters'), '0/26');
    expect(find.byKey(const Key('unit-done-letters')), findsNothing);
    // locked: the previous unit is not finished. The island keeps a faded picture of its topic, with a small lock badge.
    expect(_iconOf(t, 'colors'), Icons.palette_rounded);
    expect(find.byKey(const Key('unit-lock-colors')), findsOneWidget);
    expect(find.byKey(const Key('unit-play-colors')), findsNothing);
    expect(find.byKey(const Key('unit-title-colors')), findsOneWidget);
  });

  testWidgets('only one Dandoona on screen: she stands on the current island', (t) async {
    await _openMap(t);
    expect(find.byKey(const Key('map-dandoona')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('unit-letters')), matching: find.byKey(const Key('map-dandoona'))), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is AssetPicture && w.assetPath.contains('mascot')), findsOneWidget);
  });

  testWidgets('the greeting shows for about three seconds, then only the avatar stays', (t) async {
    await _openMap(t);
    expect(find.byKey(const Key('greeting')), findsOneWidget);
    await t.pump(const Duration(seconds: 2));
    expect(find.byKey(const Key('greeting')), findsOneWidget);
    await t.pump(const Duration(seconds: 2));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('greeting')), findsNothing);
    expect(find.byKey(const Key('map-avatar')), findsOneWidget);
  });

  testWidgets('the avatar opens "Who is playing?"; there is no back arrow to the parent area', (t) async {
    await _openMap(t);
    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
    await t.tap(find.byKey(const Key('map-avatar')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('unit-map')), findsNothing);
    expect(find.text('Omar'), findsWidgets); // the child card on "Who is playing?"
  });

  testWidgets('the small parent button asks the parental gate before the parent area', (t) async {
    await _openMap(t);
    await t.tap(find.byKey(const Key('map-parent')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('gate-hold')), findsOneWidget);
  });

  testWidgets('every tappable thing in the top bar is at least 64 dp', (t) async {
    await _openMap(t);
    for (final k in ['map-avatar', 'open-wardrobe', 'map-parent', 'unit-play-letters']) {
      final size = t.getSize(find.byKey(Key(k)));
      expect(size.width, greaterThanOrEqualTo(64), reason: k);
      expect(size.height, greaterThanOrEqualTo(64), reason: k);
    }
  });

  testWidgets('every unit of the content file is on the map, in order, and units without lessons are "coming soon"', (t) async {
    await _openMap(t);
    final map = find.byKey(const Key('unit-map'));
    for (final id in ['letters', 'colors', 'numbers', 'shapes', 'animals', 'my-body', 'food', 'my-family']) {
      await t.scrollUntilVisible(find.byKey(Key('unit-title-$id')), 300, scrollable: find.descendant(of: map, matching: find.byType(Scrollable)));
      expect(find.byKey(Key('unit-title-$id')), findsOneWidget);
    }
    // not built yet: its own faded picture and a "Soon" ribbon, never an hourglass
    expect(_iconOf(t, 'my-family'), Icons.family_restroom_rounded);
    expect(find.byKey(const Key('unit-soon-my-family')), findsOneWidget);
    expect(find.byIcon(Icons.hourglass_top_rounded), findsNothing);
  });

  testWidgets('tapping a locked unit: Dandoona says its name and what to finish first, and the map stays', (t) async {
    final (audio, _) = await _openMap(t);
    await _center(t, 'unit-colors');
    audio.played.clear();
    await t.tap(find.byKey(const Key('unit-colors')));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Finish Letters first!'), findsOneWidget);
    expect(audio.played.first, 'asset:audio/little_learners/unit_colors/instr_title.mp3');
    await t.pumpAndSettle();
    await t.pump(const Duration(seconds: 3));
    expect(find.text('Finish Letters first!'), findsNothing);
    expect(find.byKey(const Key('unit-map')), findsOneWidget);
    expect(find.byKey(const Key('letter-map')), findsNothing);
  });

  testWidgets('tapping a unit that is not built yet: "Coming soon!"', (t) async {
    await _openMap(t, progress: _progress(_letters));
    await _center(t, 'unit-numbers');
    await t.tap(find.byKey(const Key('unit-numbers')));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Coming soon!'), findsOneWidget);
    await t.pumpAndSettle();
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('tapping the current unit says its name and opens its lesson path; back returns to the map', (t) async {
    final (audio, _) = await _openMap(t);
    audio.played.clear(); // Dandoona's question and the chime on the way here
    await t.tap(find.byKey(const Key('unit-play-letters')));
    await t.pumpAndSettle();
    expect(audio.played, ['asset:audio/little_learners/unit_letters/instr_title.mp3']);
    expect(find.byKey(const Key('letter-map')), findsOneWidget);
    expect(find.byKey(const Key('node-letter-a')), findsOneWidget);

    await t.tap(find.byKey(const Key('map-back')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('unit-map')), findsOneWidget);
  });

  testWidgets('a child who had finished all 26 letters (progress saved before units existed) sees Letters done with a certificate, and Colors open', (t) async {
    final (_, container) = await _openMap(t, progress: _progress(_letters));
    expect(find.byKey(const Key('unit-done-letters')), findsOneWidget);
    expect(find.byKey(const Key('unit-certificate-letters')), findsOneWidget);
    expect(find.byKey(const Key('unit-play-letters')), findsNothing);
    expect(find.byKey(const Key('unit-play-colors')), findsOneWidget);
    expect(_ring(t, 'colors'), '0/10');
    expect(_iconOf(t, 'colors'), Icons.palette_rounded);
    expect(find.byKey(const Key('unit-lock-colors')), findsNothing);

    // the migration recorded it once, in meta.v2, without touching progress.v1
    final prefs = container.read(sharedPreferencesProvider);
    expect(jsonDecode(prefs.getString('meta.v2')!)['children']['c1']['certificates'], {'letters': '2026-09-01'});
    expect((jsonDecode(prefs.getString('progress.v1')!) as List), hasLength(26));
  });

  testWidgets('the Colors path shows the ten colors; the first is open, the rest follow the one-after-another rule', (t) async {
    await _openMap(t, progress: _progress(_letters));
    await t.tap(find.byKey(const Key('unit-play-colors')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('letter-map')), findsOneWidget);
    expect(find.byKey(const Key('node-color-red')), findsOneWidget);
    // red is open (its node is a colored circle, not a lock)
    final node = t.widget<Container>(find.byKey(const Key('node-color-red')));
    expect((node.decoration! as BoxDecoration).color, const Color(0xFFE5524A));
    // a Colors lesson opens with its color as the big circle
    await t.tap(find.byKey(const Key('node-color-red')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('lesson-letter-tap')), findsOneWidget);
    expect(find.byKey(const Key('activity-color-the-object')), findsOneWidget);
  });

  testWidgets('progress in Colors fills the bar, and the stars of both units are counted', (t) async {
    await _openMap(t, progress: _progress([..._letters, 'color-red', 'color-blue', 'color-yellow', 'color-green']));
    expect(_ring(t, 'colors'), '4/10');
    expect(t.widget<Text>(find.byKey(const Key('total-stars'))).data, '90'); // 30 lessons x 1 activity x 3 stars
  });

  testWidgets('the parent\'s "unlock all" opens Colors for a new child', (t) async {
    await _openMap(t, unlockAll: true);
    expect(find.byKey(const Key('unit-play-colors')), findsOneWidget);
  });

  group('routes', () {
    String? go(String location, {bool child = true}) =>
        guardRoute(location: location, onboarded: true, hasProfiles: true, parentUnlocked: false, hasActiveChild: child);

    test('the unit map, a unit path and certificates need a selected child', () {
      for (final path in ['/map', '/unit/letters', '/certificate/letters']) {
        expect(go(path, child: false), '/who', reason: path);
        expect(go(path), isNull, reason: path);
      }
    });
  });
}
