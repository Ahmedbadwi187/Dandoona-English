import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/app.dart';
import 'package:kids_english_app/core/strings.dart';
import 'package:kids_english_app/features/audio/audio_service.dart';
import 'package:kids_english_app/features/onboarding/setup_flow.dart';
import 'package:kids_english_app/features/profiles/child_profile.dart';
import 'package:kids_english_app/features/settings/settings.dart';
import 'package:kids_english_app/features/units/unit_meta.dart';
import 'package:kids_english_app/features/content/content_models.dart';
import 'package:kids_english_app/features/content/content_repository.dart';
import 'package:kids_english_app/features/reminders/reminder_service.dart';
import 'package:kids_english_app/core/storage.dart';
import 'package:go_router/go_router.dart';

import 'helpers.dart';

const _settings = '{"languageCode":"en","sessionMinutes":15,"unlockAll":false,"onboarded":false,"languageChosen":true}';
final _s = Strings.en;
FakeAudio audio = FakeAudio();

/// Content with a placement table like the real one: level 2 = "knows all letters" -> Letters done, start at Colors.
TrackContent _content() {
  final lessons = [
    for (final id in ['a', 'b'])
      {
        'id': 'letter-$id',
        'order': 1,
        'level': 'pre-a1',
        'letter': id.toUpperCase(),
        'phoneme': '/x/',
        'audio': {'intro': 'a.mp3', 'praise': ['p.mp3']},
        'words': [
          {'word': 'w', 'audio': 'w.mp3', 'image': 'w.svg'},
        ],
        'activities': ['trace'],
      },
  ];
  return TrackContent.fromJson({
    'schemaVersion': 2,
    'track': 'little-learners',
    'units': [
      {'id': 'letters', 'order': 1, 'title': {'en': 'Letters', 'ar': 'الحروف'}, 'icon': 'abc', 'color': 'blue', 'lessons': lessons},
      {'id': 'colors', 'order': 2, 'title': {'en': 'Colors', 'ar': 'الألوان'}, 'icon': 'palette', 'color': 'red', 'lessons': <Map<String, dynamic>>[]},
    ],
    'app': {'title': 'audio/t.mp3', 'welcome': 'audio/hello.mp3', 'celebration': 'audio/b.mp3'},
    'placement': [
      {'level': 0, 'key': 'none', 'doneUnits': <String>[], 'startUnit': 'letters'},
      {'level': 2, 'key': 'all-letters', 'doneUnits': ['letters'], 'startUnit': 'colors'},
    ],
  });
}

Future<(ProviderContainer, FakeReminders)> _start(WidgetTester t, {bool allow = true, Map<String, Object>? prefs}) async {
  audio = FakeAudio();
  t.view.physicalSize = const Size(1080, 2400);
  t.view.devicePixelRatio = 1080 / 411;
  addTearDown(t.view.reset);
  final reminders = FakeReminders(allow: allow);
  final overrides = await testOverrides(prefs: prefs ?? {'settings.v1': _settings}, content: _content(), reminders: reminders);
  final container = ProviderContainer(overrides: [...overrides, audioServiceProvider.overrideWithValue(audio)]);
  addTearDown(container.dispose);
  await t.pumpWidget(UncontrolledProviderScope(container: container, child: const KidsEnglishApp()));
  await t.pumpAndSettle();
  return (container, reminders);
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

bool _continueEnabled(WidgetTester t) => t.widget<FilledButton>(find.byKey(const Key('ob-continue'))).onPressed != null;

/// Goes through name, age, level, goal up to the reminder screen.
Future<void> _answers(WidgetTester t, {String name = 'Omar', int level = 2, int goal = 15}) async {
  await t.enterText(find.byKey(const Key('ob-name')), name);
  await t.tap(find.byKey(const Key('avatar-bunny')));
  await t.pump();
  await _tap(t, 'ob-continue');
  await _pick(t, 'ob-month', _s('obMonth3'));
  await _pick(t, 'ob-year', '${DateTime.now().year - 4}');
  await _tap(t, 'ob-continue');
  await tapSkill(t, skillOfLevel(level));
  await _tap(t, 'ob-continue');
  await _tap(t, 'goal-$goal');
  await _tap(t, 'ob-continue');
}

void main() {
  testWidgets('the whole first launch: answers become the child, the placement, the goal and the reminder', (t) async {
    final (c, reminders) = await _start(t);
    await _tap(t, 'ob-continue'); // welcome: start without an account
    expect(_continueEnabled(t), isFalse); // the name and avatar come first

    await _answers(t);
    expect(reminders.permissionAsked, 0); // nothing is asked before the parent taps "Remind me"
    await _tap(t, 'time-evening');
    await _tap(t, 'ob-continue'); // "Remind me"
    expect(reminders.permissionAsked, 1);

    // summary: the path is ready, with the starting unit from the placement table
    expect(find.text(_s('obPathReady').replaceAll('{name}', 'Omar')), findsOneWidget);
    expect(find.textContaining('Colors'), findsOneWidget); // ("Colors · 1 unit skipped")
    expect(find.text(_s('obGoal15')), findsOneWidget);
    await _tap(t, 'ob-continue'); // Start learning

    final child = c.read(profilesProvider).single;
    expect((child.name, child.avatarKey, child.birthMonth, child.goalMinutes, child.track), ('Omar', 'bunny', 3, 15, 'little-learners'));
    expect(child.birthYear, DateTime.now().year - 4);
    expect(c.read(unitMetaProvider).of(child.id).placed, {'letters'});
    expect(c.read(settingsProvider).sessionMinutes, 15);
    expect(c.read(settingsProvider).reminderTime, 'evening');
    expect(c.read(settingsProvider).onboarded, isTrue);
    expect(reminders.scheduled?.hour, 19);
    expect(reminders.scheduled?.title, _s('obReminderTitle'));

    // Dandoona greets the child in English, then the unit map opens for that child
    expect(audio.played, ['asset:audio/hello.mp3']); // Dandoona says hello
    expect(find.byKey(const Key('greeting-name')), findsOneWidget);
    expect(find.text('Hi, Omar!'), findsOneWidget);
    expect(c.read(activeChildIdProvider), child.id);
    await _tap(t, 'greeting-go');
    expect(find.byKey(const Key('unit-colors')), findsOneWidget);
  });

  testWidgets('"Remind me later" and a refused permission both leave no reminder and still finish', (t) async {
    final (c, reminders) = await _start(t);
    await _tap(t, 'ob-continue');
    await _answers(t, level: 0, goal: 5);
    await _tap(t, 'ob-secondary'); // Remind me later
    expect(reminders.permissionAsked, 0);
    await _tap(t, 'ob-continue');
    expect(c.read(settingsProvider).reminderTime, isNull);
    expect(reminders.scheduled, isNull);
    expect(c.read(settingsProvider).sessionMinutes, 5);
    expect(c.read(unitMetaProvider).of(c.read(profilesProvider).single.id).placed, isEmpty);
  });

  testWidgets('a refused notification permission shows the note and the setup goes on', (t) async {
    final (c, reminders) = await _start(t, allow: false);
    await _tap(t, 'ob-continue');
    await _answers(t);
    await _tap(t, 'time-morning');
    await _tap(t, 'ob-continue');
    expect(reminders.permissionAsked, 1);
    expect(find.text(_s('obReminderDenied')), findsOneWidget);
    await t.pump(const Duration(seconds: 6));
    await t.pumpAndSettle();
    await _tap(t, 'ob-continue');
    expect(c.read(settingsProvider).reminderTime, isNull);
    expect(reminders.scheduled, isNull);
    expect(c.read(profilesProvider), hasLength(1));
  });

  testWidgets('the back arrow keeps the answers, and a summary row edits one answer and comes back', (t) async {
    await _start(t);
    await _tap(t, 'ob-continue');
    await _answers(t, goal: 10);
    await _tap(t, 'ob-secondary'); // later
    expect(find.byKey(const Key('summary-goal')), findsOneWidget);

    await _tap(t, 'summary-goal');
    await _tap(t, 'goal-15');
    await _tap(t, 'ob-continue'); // back on the summary
    expect(find.byKey(const Key('summary-goal')), findsOneWidget);
    expect(find.text(_s('obGoal15')), findsOneWidget);

    await _tap(t, 'ob-back'); // summary -> reminder -> goal -> ...
    await _tap(t, 'ob-back');
    expect(find.byKey(const Key('goal-15')), findsOneWidget);
    await _tap(t, 'ob-back');
    await _tap(t, 'ob-back');
    await _tap(t, 'ob-back');
    expect(find.text('Omar'), findsOneWidget);
  });

  testWidgets('rerunning the setup for an existing child updates that child and returns to the list', (t) async {
    final (c, _) = await _start(t, prefs: {
      'settings.v1': '{"languageCode":"en","sessionMinutes":15,"unlockAll":false,"onboarded":true,"languageChosen":true}',
      'children.v1': '[{"id":"c1","name":"Lina","avatarKey":"cat","birthYear":${DateTime.now().year - 4},"track":"little-learners","createdAt":"2026-01-01T00:00:00Z"}]',
    });
    c.read(setupDraftProvider.notifier).start(childId: 'c1', returnTo: '/who');
    GoRouter.of(t.element(find.byType(Scaffold).first)).go('/setup/name');
    await t.pumpAndSettle();
    expect(find.byKey(const Key('ob-name')), findsOneWidget);
    await t.enterText(find.byKey(const Key('ob-name')), 'Lina B');
    await t.pump();
    await _tap(t, 'ob-continue');
    await _pick(t, 'ob-month', _s('obMonth5'));
    await _tap(t, 'ob-continue');
    await tapSkill(t, 'some-letters');
    await _tap(t, 'ob-continue');
    await _tap(t, 'goal-5');
    await _tap(t, 'ob-continue');
    await _tap(t, 'ob-secondary');
    await _tap(t, 'ob-continue');

    final kids = c.read(profilesProvider);
    expect(kids, hasLength(1)); // updated, not duplicated
    expect((kids.single.name, kids.single.birthMonth, kids.single.goalMinutes), ('Lina B', 5, 5));
    expect(find.text('Who is playing?'), findsOneWidget); // returnTo
  });

  test('the reminder times and strings exist', () {
    for (final t in reminderTimes.keys) {
      expect(_s('obTime${t[0].toUpperCase()}${t.substring(1)}'), isNot(startsWith('obTime')));
    }
    expect(PrefKeys.children, isNotEmpty);
    expect(littleLearnersAsset, isNotEmpty);
  });
}
