import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/app.dart';
import 'package:kids_english_app/core/strings.dart';
import 'package:kids_english_app/features/audio/audio_service.dart';
import 'package:kids_english_app/features/parent/parent_prompts.dart';
import 'package:kids_english_app/features/profiles/child_profile.dart';
import 'package:kids_english_app/features/router_state.dart';
import 'package:kids_english_app/router.dart';
import 'package:kids_english_app/features/units/unit_meta.dart';

import 'helpers.dart';

final _s = Strings.en;
final _year = DateTime.now().year;

Future<ProviderContainer> _start(WidgetTester t, {Map<String, Object>? prefs}) async {
  t.view.physicalSize = const Size(1080, 2400);
  t.view.devicePixelRatio = 1080 / 411;
  addTearDown(t.view.reset);
  final overrides = await testOverrides(
    prefs: prefs ?? {'settings.v1': '{"languageCode":"en","sessionMinutes":15,"unlockAll":false,"onboarded":false,"languageChosen":true}'},
    content: realContent(),
    explorers: realExplorersContent(),
  );
  final container = ProviderContainer(overrides: [...overrides, audioServiceProvider.overrideWithValue(FakeAudio())]);
  addTearDown(container.dispose);
  await t.pumpWidget(UncontrolledProviderScope(container: container, child: const KidsEnglishApp()));
  await t.pumpAndSettle();
  return container;
}

Future<void> _tap(WidgetTester t, String key) async {
  await t.tap(find.byKey(Key(key)));
  await t.pumpAndSettle();
}

Future<void> _pick(WidgetTester t, String dropdownKey, String item) async {
  await _tap(t, dropdownKey);
  await t.tap(find.text(item).last);
  await t.pumpAndSettle();
}

/// Welcome, name, birth month + year, the English level, the goal, no reminder: up to the summary.
Future<void> _toSummary(WidgetTester t, {required int month, required int year, required int level}) async {
  await _tap(t, 'ob-continue'); // welcome
  await t.enterText(find.byKey(const Key('ob-name')), 'Lina');
  await t.tap(find.byKey(const Key('avatar-cat')));
  await t.pump();
  await _tap(t, 'ob-continue');
  await _pick(t, 'ob-month', _s('obMonth$month'));
  await _pick(t, 'ob-year', '$year');
  await _tap(t, 'ob-continue');
  await _tap(t, 'level-$level');
  await _tap(t, 'ob-continue');
  await _tap(t, 'goal-10');
  await _tap(t, 'ob-continue');
  await _tap(t, 'ob-secondary'); // reminder: later
}

void main() {
  group('new children: the track comes from the age', () {
    testWidgets('a seven-year-old who knows all letters goes to Explorers and starts at Sound Builders', (t) async {
      final c = await _start(t);
      await _toSummary(t, month: 1, year: _year - 7, level: 2);
      expect(find.text(_s('obTrackExplorers')), findsOneWidget);
      expect(find.text('Sound Builders'), findsOneWidget);
      await _tap(t, 'ob-continue'); // Start learning
      final child = c.read(profilesProvider).single;
      expect(child.track, 'explorers');
      expect(c.read(unitMetaProvider).of(child.id).placed, {'letters'});
    });

    testWidgets('a six-year-old who knows no English starts with Letters inside the Explorers map', (t) async {
      final c = await _start(t);
      await _toSummary(t, month: 1, year: _year - 6, level: 0);
      expect(find.text(_s('obTrackExplorers')), findsOneWidget);
      expect(find.text('Letters'), findsOneWidget);
      await _tap(t, 'ob-continue');
      expect(c.read(profilesProvider).single.track, 'explorers');
      expect(c.read(unitMetaProvider).of(c.read(profilesProvider).single.id).placed, isEmpty);
    });

    testWidgets('a child who reads simple words starts at Digraphs, with Letters and Sound Builders done by placement', (t) async {
      final c = await _start(t);
      await _toSummary(t, month: 1, year: _year - 8, level: 3);
      expect(find.text('Digraphs'), findsOneWidget);
      await _tap(t, 'ob-continue');
      expect(c.read(unitMetaProvider).of(c.read(profilesProvider).single.id).placed, {'letters', 'sound-builders'});
    });

    testWidgets('five years and eleven months is still Little Learners (the month decides)', (t) async {
      final now = DateTime.now();
      final month = now.month == 12 ? 1 : now.month + 1; // the 6th birthday is next month
      final year = now.month == 12 ? now.year - 5 : now.year - 6;
      final c = await _start(t);
      await _toSummary(t, month: month, year: year, level: 0);
      expect(find.text(_s('obTrackLL')), findsOneWidget);
      await _tap(t, 'ob-continue');
      expect(c.read(profilesProvider).single.track, 'little-learners');
    });

    testWidgets('the parent can change the track on the summary, and the start follows that track', (t) async {
      final c = await _start(t);
      await _toSummary(t, month: 1, year: _year - 7, level: 2);
      await _tap(t, 'summary-track');
      expect(find.byKey(const Key('track-explorers')), findsOneWidget);
      await _tap(t, 'track-little-learners');
      await _tap(t, 'ob-continue'); // back on the summary
      expect(find.text(_s('obTrackLL')), findsOneWidget);
      expect(find.text('Colors'), findsOneWidget); // Little Learners: all letters known -> Colors
      await _tap(t, 'ob-continue');
      expect(c.read(profilesProvider).single.track, 'little-learners');
    });

    testWidgets('the birth month is required: Continue stays off with the year alone', (t) async {
      await _start(t);
      await _tap(t, 'ob-continue');
      await t.enterText(find.byKey(const Key('ob-name')), 'Lina');
      await t.tap(find.byKey(const Key('avatar-cat')));
      await t.pump();
      await _tap(t, 'ob-continue');
      await _pick(t, 'ob-year', '${_year - 7}');
      expect(t.widget<FilledButton>(find.byKey(const Key('ob-continue'))).onPressed, isNull);
    });
  });

  group('parent area prompts', () {
    String child(String id, {int? month, int age = 4, String track = 'little-learners'}) =>
        '{"id":"$id","name":"Kid$id","avatarKey":"star","birthYear":${_year - age}${month == null ? '' : ',"birthMonth":$month'},"track":"$track","createdAt":"2026-01-01T00:00:00Z"}';

    Future<ProviderContainer> parentArea(WidgetTester t, String children, {String? meta}) async {
      final c = await _start(t, prefs: {
        'settings.v1': '{"languageCode":"en","sessionMinutes":15,"unlockAll":false,"onboarded":true,"languageChosen":true}',
        'children.v1': children,
        'meta.v2': ?meta,
      });
      c.read(parentSessionProvider.notifier).unlock();
      c.read(routerProvider).go('/parent');
      await t.pumpAndSettle();
      return c;
    }

    testWidgets('a child saved with the year only: the parent is asked once for the month', (t) async {
      final c = await parentArea(t, '[${child('1')}]');
      expect(find.byKey(const Key('ask-month-1')), findsOneWidget);
      await _tap(t, 'ask-month-later-1');
      expect(find.byKey(const Key('ask-month-1')), findsNothing);
      expect(c.read(parentAsksProvider).monthAsked, {'1'}); // never asked again
    });

    testWidgets('"Add the month" opens Edit child', (t) async {
      await parentArea(t, '[${child('1')}]');
      await _tap(t, 'ask-month-add-1');
      expect(find.byKey(const Key('edit-year')), findsOneWidget);
    });

    testWidgets('a Little Learner who turns 6 is offered Explorers; nothing changes until the parent accepts', (t) async {
      final c = await parentArea(t, '[${child('1', month: 1, age: 6)}]');
      expect(find.byKey(const Key('offer-explorers-1')), findsOneWidget);
      expect(c.read(profilesProvider).single.track, 'little-learners'); // never automatic
      await _tap(t, 'offer-explorers-yes-1');
      expect(c.read(profilesProvider).single.track, 'explorers');
      expect(find.byKey(const Key('offer-explorers-1')), findsNothing);
    });

    testWidgets('finishing the castle brings the offer before the 6th birthday; "Stay" keeps the track and certificates', (t) async {
      final meta = '{"schema":2,"children":{"1":{"certificates":{"letters":"2026-09-01"},"celebrated":["letters"],"reviews":["castle"],"chests":["letters"]}}}';
      final c = await parentArea(t, '[${child('1', month: 1, age: 5)}]', meta: meta);
      expect(find.byKey(const Key('offer-explorers-1')), findsOneWidget);
      await _tap(t, 'offer-explorers-stay-1');
      expect(c.read(profilesProvider).single.track, 'little-learners');
      expect(c.read(unitMetaProvider).of('1').certificates, {'letters': '2026-09-01'});
      expect(find.byKey(const Key('offer-explorers-1')), findsNothing);
    });

    testWidgets('accepting keeps the certificates, chests and outfits', (t) async {
      final meta = '{"schema":2,"children":{"1":{"certificates":{"letters":"2026-09-01"},"celebrated":["letters"],"chests":["letters"]}}}';
      final c = await parentArea(t, '[${child('1', month: 1, age: 6)}]', meta: meta);
      await _tap(t, 'offer-explorers-yes-1');
      final m = c.read(unitMetaProvider).of('1');
      expect(m.certificates, {'letters': '2026-09-01'});
      expect(m.chests, {'letters'});
    });

    testWidgets('a four-year-old Little Learner is not offered anything', (t) async {
      await parentArea(t, '[${child('1', month: 1)}]');
      expect(find.byKey(const Key('offer-explorers-1')), findsNothing);
      expect(find.byKey(const Key('ask-month-1')), findsNothing);
    });
  });

  testWidgets('Edit child: Explorers can be chosen, and the starting point follows the track', (t) async {
    final c = await _start(t, prefs: {
      'settings.v1': '{"languageCode":"en","sessionMinutes":15,"unlockAll":false,"onboarded":true,"languageChosen":true}',
      'children.v1': '[{"id":"1","name":"Lina","avatarKey":"star","birthYear":${_year - 7},"birthMonth":1,"track":"little-learners","createdAt":"2026-01-01T00:00:00Z"}]',
    });
    c.read(parentSessionProvider.notifier).unlock();
    c.read(routerProvider).go('/parent/children/1');
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.byKey(const Key('edit-track-explorers')), 200, scrollable: find.byType(Scrollable).first);
    await _tap(t, 'edit-track-explorers');
    await t.scrollUntilVisible(find.byKey(const Key('edit-start-sound-builders')), 200, scrollable: find.byType(Scrollable).first);
    await _tap(t, 'edit-start-sound-builders');
    await t.scrollUntilVisible(find.byKey(const Key('edit-save')), 200, scrollable: find.byType(Scrollable).first);
    await _tap(t, 'edit-save');
    expect(c.read(profilesProvider).single.track, 'explorers');
    expect(c.read(unitMetaProvider).of('1').placed, {'letters'});
  });
}
