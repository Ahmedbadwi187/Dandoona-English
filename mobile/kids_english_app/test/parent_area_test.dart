import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/app.dart';
import 'package:kids_english_app/core/strings.dart';
import 'package:kids_english_app/features/audio/audio_service.dart';
import 'package:kids_english_app/features/content/content_models.dart';
import 'package:kids_english_app/features/parent/parent_ui.dart';
import 'package:kids_english_app/features/profiles/child_profile.dart';
import 'package:kids_english_app/features/router_state.dart';
import 'package:kids_english_app/router.dart';

import 'helpers.dart';

/// Thursday 8 October 2026.
final _now = DateTime(2026, 10, 8, 12);

Map<String, dynamic> _lesson(String id, String word, {String? letter}) => {
      'id': id,
      'order': 1,
      'level': 'pre-a1',
      'letter': ?letter,
      'phoneme': '/x/',
      'audio': {'intro': 'a/$id-intro.mp3', 'praise': ['p.mp3']},
      'words': [
        {'word': word, 'audio': 'audio/$word.mp3', 'image': 'images/x/w.svg'},
      ],
      'activities': ['trace', 'listen-and-tap'],
    };

TrackContent _content() => TrackContent.fromJson({
      'schemaVersion': 2,
      'track': 'little-learners',
      'units': [
        {'id': 'letters', 'order': 1, 'title': {'en': 'Letters', 'ar': 'الحروف'}, 'icon': 'letters', 'color': 'blue', 'lessons': [_lesson('letter-a', 'apple', letter: 'A'), _lesson('letter-b', 'ball', letter: 'B')]},
        {'id': 'colors', 'order': 2, 'title': {'en': 'Colors', 'ar': 'الألوان'}, 'icon': 'colors', 'color': 'red', 'lessons': [_lesson('color-red', 'red'), _lesson('color-blue', 'blue')]},
        {'id': 'numbers', 'order': 3, 'title': {'en': 'Numbers', 'ar': 'الأرقام'}, 'icon': 'numbers', 'color': 'green', 'lessons': <Map<String, dynamic>>[]},
      ],
    });

String _record(String id, String child, String lesson, String activity, int stars, DateTime at, {int seconds = 60, int attempts = 1}) =>
    '{"clientRecordId":"$id","childId":"$child","lessonId":"$lesson","activity":"$activity","stars":$stars,"attempts":$attempts,"timeSpentSeconds":$seconds,"completedAt":"${at.toUtc().toIso8601String()}"}';

String _settings(String lang, String parent) => '{"languageCode":"$lang","sessionMinutes":15,"unlockAll":false,"onboarded":true,"languageChosen":true,"parentName":"$parent"}';

const _omar = '{"id":"c1","name":"Omar","avatarKey":"bear","birthYear":2022,"birthMonth":1,"goalMinutes":10,"track":"little-learners","createdAt":"2026-01-01T00:00:00Z"}';
const _lina = '{"id":"c2","name":"Lina","avatarKey":"cat","birthYear":2022,"track":"little-learners","createdAt":"2026-01-02T00:00:00Z"}';

/// Omar finished Letters, is halfway through Colors (the red lesson took three tries) and played on Monday (10 min) and
/// Thursday (20 min). Lina has not played.
String _progress() => '[${[
  _record('1', 'c1', 'letter-a', 'trace', 3, DateTime(2026, 9, 1, 9)),
  _record('2', 'c1', 'letter-b', 'trace', 3, DateTime(2026, 9, 2, 9)),
  _record('3', 'c1', 'color-red', 'trace', 1, DateTime(2026, 10, 5, 9), seconds: 600, attempts: 3),
  _record('4', 'c1', 'color-red', 'listen-and-tap', 2, DateTime(2026, 10, 8, 9), seconds: 1200),
].join(',')}]';

/// A player that waits for stop(), so "playing" can be seen.
class _SlowAudio implements AudioService {
  final played = <String>[];
  Completer<void>? _current;

  @override
  Future<void> playAsset(String assetPath) async {
    played.add(assetPath);
    _current = Completer<void>();
    await _current!.future;
  }

  @override
  Future<void> playFile(String path) async {}

  @override
  Future<void> stop() async {
    final c = _current;
    if (c != null && !c.isCompleted) c.complete();
  }

  @override
  void dispose() {}
}

Future<ProviderContainer> _open(
  WidgetTester t, {
  String path = '/parent',
  String lang = 'en',
  List<String> kids = const [_omar, _lina],
  AudioService? audio,
  String? meta,
  String parent = 'Ahmed',
}) async {
  t.view.physicalSize = const Size(1080, 4200);
  t.view.devicePixelRatio = 1080 / 411;
  addTearDown(t.view.reset);
  final overrides = await testOverrides(
    content: _content(),
    prefs: {'settings.v1': _settings(lang, parent), 'children.v1': '[${kids.join(',')}]', 'progress.v1': _progress(), 'meta.v2': ?meta},
  );
  final c = ProviderContainer(overrides: [
    ...overrides,
    clockProvider.overrideWithValue(() => _now),
    audioServiceProvider.overrideWithValue(audio ?? FakeAudio()),
  ]);
  addTearDown(c.dispose);
  await t.pumpWidget(UncontrolledProviderScope(container: c, child: const KidsEnglishApp()));
  await t.pumpAndSettle();
  c.read(parentSessionProvider.notifier).unlock(); // after the picker opened (it locks the parent area on arrival)
  c.read(routerProvider).go(path);
  await t.pumpAndSettle();
  return c;
}

String _location(ProviderContainer c) => c.read(routerProvider).routerDelegate.currentConfiguration.last.matchedLocation;

void main() {
  group('parent area', () {
    testWidgets('header: the title, a greeting with the first name and the settings gear', (t) async {
      final c = await _open(t);
      expect(find.text('Parent area'), findsOneWidget);
      expect(find.text('Hi, Ahmed'), findsOneWidget);
      await t.tap(find.byKey(const Key('parent-settings')));
      await t.pumpAndSettle();
      expect(_location(c), '/parent/settings');
    });

    testWidgets('without a first name there is no greeting', (t) async {
      await _open(t, kids: const [_omar], parent: '');
      expect(find.byKey(const Key('parent-greeting')), findsNothing);
    });

    testWidgets('a child card: age, current unit, unit progress, the units line (not mixed with lessons) and a chevron', (t) async {
      await _open(t);
      final card = find.byKey(const Key('parent-child-c1'));
      expect(find.descendant(of: card, matching: find.textContaining('Omar')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.textContaining('4 years')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('Now learning: Colors')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('Colors · 1 of 2 lessons')), findsOneWidget);
      expect(t.widget<LinearProgressIndicator>(find.byKey(const Key('unit-progress-c1'))).value, 0.5);
      expect(find.text('Units completed: 1 of 3'), findsOneWidget);
      expect(find.descendant(of: card, matching: find.byType(ParentChevron)), findsOneWidget);
      expect(find.textContaining('Letters completed'), findsNothing);
    });

    testWidgets('this week: four tiles and a chart of minutes with the goal line; the week starts on Monday in English', (t) async {
      await _open(t);
      for (final k in ['stars', 'activities', 'minutes', 'days']) {
        expect(find.byKey(Key('tile-$k')), findsOneWidget, reason: k);
      }
      expect(find.descendant(of: find.byKey(const Key('tile-minutes')), matching: find.text('30')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('tile-days')), matching: find.text('2/7')), findsOneWidget);
      expect(find.byKey(const Key('goal-line')), findsOneWidget);
      // Monday (10 min) is shorter than Thursday (20 min); a day with nothing is a thin stub
      final mon = t.getSize(find.byKey(const Key('week-bar-0'))).height;
      final thu = t.getSize(find.byKey(const Key('week-bar-3'))).height;
      expect(thu, greaterThan(mon));
      expect(t.getSize(find.byKey(const Key('week-bar-1'))).height, 3);
      expect(find.text('Mon'), findsOneWidget);
      expect(t.getTopLeft(find.text('Mon')).dx, lessThan(t.getTopLeft(find.text('Sun')).dx));
      // the chart is short
      expect(t.getSize(find.byKey(const Key('week-chart'))).height, lessThan(110));
    });

    testWidgets('an empty week shows Dandoona waiting instead of zeros, tiles and chart', (t) async {
      await _open(t);
      expect(find.byKey(const Key('empty-week-c2')), findsOneWidget);
      expect(find.text('No activity this week yet. Dandoona is waiting!'), findsOneWidget);
      expect(find.byKey(const Key('empty-week-c1')), findsNothing);
      expect(find.byKey(const Key('week-chart')), findsOneWidget); // only Omar's
      expect(find.byKey(const Key('week-tiles')), findsOneWidget);
    });

    testWidgets('the two buttons are fixed at the bottom: Child mode filled, Manage children outlined, same width, smaller', (t) async {
      await _open(t);
      final mode = t.getSize(find.byKey(const Key('open-child-mode')));
      final manage = t.getSize(find.byKey(const Key('manage-children')));
      expect(mode.width, manage.width);
      expect(manage.height, lessThan(mode.height));
      expect(manage.height, greaterThanOrEqualTo(kParentTap));
      expect(t.getBottomLeft(find.byKey(const Key('manage-children'))).dy, greaterThan(t.getBottomLeft(find.byKey(const Key('open-child-mode'))).dy));
      expect(find.byType(FilledButton), findsWidgets);
      expect(find.byType(OutlinedButton), findsOneWidget);
    });

    testWidgets('tapping a card opens that child\'s details', (t) async {
      final c = await _open(t);
      await t.tap(find.byKey(const Key('parent-child-c1')));
      await t.pumpAndSettle();
      expect(_location(c), '/parent/child/c1');
      expect(find.byKey(const Key('detail-name')), findsOneWidget);
    });

    testWidgets('Child mode with two children asks who is playing', (t) async {
      final c = await _open(t);
      await t.tap(find.byKey(const Key('open-child-mode')));
      await t.pumpAndSettle();
      expect(_location(c), '/who');
    });

    testWidgets('Child mode with one child opens that child\'s unit map directly', (t) async {
      final c = await _open(t, kids: const [_omar]);
      await t.tap(find.byKey(const Key('open-child-mode')));
      await t.pumpAndSettle();
      expect(_location(c), '/map');
      expect(c.read(activeChildIdProvider), 'c1');
      expect(c.read(parentSessionProvider), isFalse); // back in the child area
    });

    testWidgets('Manage children opens the list', (t) async {
      final c = await _open(t);
      await t.tap(find.byKey(const Key('manage-children')));
      await t.pumpAndSettle();
      expect(_location(c), '/parent/children');
    });

    testWidgets('Arabic: right to left, Arabic digits, the week starts on Saturday, text mirrored', (t) async {
      await _open(t, lang: 'ar');
      expect(find.text('منطقة الأهل'), findsOneWidget);
      expect(Directionality.of(t.element(find.text('منطقة الأهل'))), TextDirection.rtl);
      expect(find.text('أهلاً، Ahmed'), findsOneWidget);
      expect(find.text('الوحدات المكتملة: ١ من ٣'), findsOneWidget);
      expect(find.text('الألوان · ١ من ٢ دروس'), findsOneWidget);
      expect(find.text('يتعلّم الآن: الألوان'), findsOneWidget);
      expect(find.text('لا نشاط هذا الأسبوع بعد. دندونة تنتظر!'), findsOneWidget);
      // Saturday first: in a right-to-left row it is the right-most label
      expect(t.getTopLeft(find.text(Strings.ar('d5'))).dx, greaterThan(t.getTopLeft(find.text(Strings.ar('d4'))).dx));
      final chevron = t.widget<Icon>(find.descendant(of: find.byKey(const Key('parent-child-c1')), matching: find.byIcon(Icons.chevron_right_rounded)));
      expect(chevron.icon!.matchTextDirection, isTrue);
    });
  });

  group('child detail', () {
    testWidgets('header: avatar, name, age and an edit pencil that opens Edit child', (t) async {
      final c = await _open(t, path: '/parent/child/c1');
      expect(find.text('Omar'), findsOneWidget);
      expect(find.text('4 years'), findsOneWidget);
      await t.tap(find.byKey(const Key('detail-edit')));
      await t.pumpAndSettle();
      expect(_location(c), '/parent/children/c1');
      expect(find.text('Edit child'), findsOneWidget);
    });

    testWidgets('back returns to the parent area', (t) async {
      final c = await _open(t);
      await t.tap(find.byKey(const Key('parent-child-c1')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('parent-back')));
      await t.pumpAndSettle();
      expect(_location(c), '/parent');
    });

    testWidgets('current unit with its progress; "Hear the words" plays the unit words one after another', (t) async {
      final audio = FakeAudio();
      await _open(t, path: '/parent/child/c1', audio: audio);
      expect(find.descendant(of: find.byKey(const Key('detail-current')), matching: find.text('Colors')), findsOneWidget);
      expect(find.text('1 of 2 lessons'), findsOneWidget);
      await t.tap(find.byKey(const Key('hear-words')));
      await t.pumpAndSettle();
      expect(audio.played, ['asset:audio/red.mp3', 'asset:audio/blue.mp3']);
      expect(find.byKey(const Key('hear-words')), findsOneWidget); // ended: the button is back
    });

    testWidgets('while playing there is a Stop button that ends the playback', (t) async {
      final audio = _SlowAudio();
      await _open(t, path: '/parent/child/c1', audio: audio);
      await t.tap(find.byKey(const Key('hear-words')));
      await t.pump();
      expect(find.byKey(const Key('hear-stop')), findsOneWidget);
      expect(audio.played, ['audio/red.mp3']);
      await t.tap(find.byKey(const Key('hear-stop')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('hear-words')), findsOneWidget);
      expect(audio.played, ['audio/red.mp3']); // the second word was not started
    });

    testWidgets('practice at home lists the words that took the most tries, each with a play button', (t) async {
      final audio = FakeAudio();
      await _open(t, path: '/parent/child/c1', audio: audio);
      expect(find.byKey(const Key('practice-red')), findsOneWidget);
      expect(find.byKey(const Key('practice-apple')), findsNothing); // 3 stars on the first try: nothing to practise
      await t.tap(find.byKey(const Key('practice-play-red')));
      await t.pump();
      expect(audio.played, ['asset:audio/red.mp3']);
    });

    testWidgets('nothing to practise: a cheerful line instead of a list', (t) async {
      await _open(t, path: '/parent/child/c2');
      expect(find.byKey(const Key('nothing-to-practice')), findsOneWidget);
      expect(find.text('Great job, nothing to practice right now'), findsOneWidget);
    });

    testWidgets('all units: status and stars; done and current open their lessons, locked and soon do not', (t) async {
      await _open(t, path: '/parent/child/c1');
      expect(find.byKey(const Key('unit-row-letters')), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Learning now'), findsOneWidget);
      expect(find.text('Soon'), findsOneWidget);

      await t.tap(find.byKey(const Key('unit-row-letters')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('lessons-letters')), findsOneWidget);
      expect(find.byKey(const Key('lesson-letter-a')), findsOneWidget);
      // two activities, three stars on one of them: 3 of 6 -> rounds to 2 of 3 stars lit
      final lit = t.widgetList<Icon>(find.descendant(of: find.byKey(const Key('lesson-letter-a')), matching: find.byIcon(Icons.star_rounded))).where((i) => i.color == const Color(0xFFFFC93C)).length;
      expect(lit, 2);
      await t.tapAt(const Offset(5, 5)); // close the sheet
      await t.pumpAndSettle();
      expect(find.byKey(const Key('lessons-letters')), findsNothing);

      await t.tap(find.byKey(const Key('unit-row-numbers'))); // soon: not tappable
      await t.pumpAndSettle();
      expect(find.byKey(const Key('lessons-numbers')), findsNothing);
    });

    testWidgets('certificates: none yet shows the hint', (t) async {
      await _open(t, path: '/parent/child/c2');
      expect(find.byKey(const Key('no-certificates')), findsOneWidget);
      expect(find.text('Certificates appear here when a unit is finished'), findsOneWidget);
    });

    testWidgets('certificates: a thumbnail opens the certificate view', (t) async {
      final c = await _open(t, path: '/parent/child/c1', meta: '{"schema":2,"children":{"c1":{"certificates":{"letters":"2026-09-02"},"celebrated":["letters"]}}}');
      expect(find.byKey(const Key('no-certificates')), findsNothing);
      await t.ensureVisible(find.byKey(const Key('cert-letters')));
      await t.tap(find.byKey(const Key('cert-letters')));
      await t.pumpAndSettle();
      expect(_location(c), '/certificate/letters');
    });

    testWidgets('history: this week, last week and this month with minutes and active days', (t) async {
      await _open(t, path: '/parent/child/c1');
      await t.ensureVisible(find.byKey(const Key('history-range')));
      expect(find.text('30 minutes'), findsOneWidget);
      expect(find.text('2 active days'), findsOneWidget);
      await t.tap(find.byKey(const Key('history-1')));
      await t.pumpAndSettle();
      expect(find.text('0 minutes'), findsOneWidget);
      expect(find.text('0 active days'), findsOneWidget);
      await t.tap(find.byKey(const Key('history-2')));
      await t.pumpAndSettle();
      expect(find.text('30 minutes'), findsOneWidget);
      expect(find.byKey(const Key('week-bar-30')), findsOneWidget); // October has 31 days
    });

    testWidgets('Arabic detail page is right to left with Arabic digits', (t) async {
      await _open(t, path: '/parent/child/c1', lang: 'ar');
      expect(find.text('٤ سنوات'), findsOneWidget);
      expect(find.text('١ من ٢ دروس'), findsOneWidget);
      expect(find.text('اسمع الكلمات'), findsOneWidget);
      expect(Directionality.of(t.element(find.byKey(const Key('detail-name')))), TextDirection.rtl);
    });

    testWidgets('tap targets in the detail page are at least 48 dp', (t) async {
      await _open(t, path: '/parent/child/c1');
      for (final k in ['detail-edit', 'hear-words', 'practice-play-red', 'unit-row-letters', 'parent-back']) {
        final size = t.getSize(find.byKey(Key(k)));
        expect(size.height, greaterThanOrEqualTo(kParentTap), reason: k);
        expect(size.width, greaterThanOrEqualTo(kParentTap), reason: k);
      }
    });
  });
}
