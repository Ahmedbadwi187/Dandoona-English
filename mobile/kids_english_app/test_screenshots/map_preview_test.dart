// Renders the unit map at phone size with the real fonts and pictures, for the owner to look at before approval.
// Not part of `flutter test` (it lives outside test/). Run:
//   flutter test test_screenshots/map_preview_test.dart --update-goldens
// The pictures land in docs/design-options/unit-map-v2/.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/app.dart';
import 'package:kids_english_app/core/sky.dart';
import 'package:kids_english_app/features/audio/audio_service.dart';
import 'package:kids_english_app/features/content/content_models.dart';
import 'package:kids_english_app/features/progress/progress.dart';

import '../test/helpers.dart';

const _out = '../../../docs/design-options/unit-map-v2';

Future<void> _loadFonts() async {
  const dir = '/opt/flutter/bin/cache/artifacts/material_fonts';
  final roboto = FontLoader('Roboto');
  for (final f in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf', 'Roboto-Black.ttf']) {
    roboto.addFont(Future.value(ByteData.sublistView(File('$dir/$f').readAsBytesSync())));
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(File('$dir/MaterialIcons-Regular.otf').readAsBytesSync())));
  await icons.load();
}

/// The real content plus what the units file will hold after approval: the new placeholder units in path order, the
/// three reviews, and stories for Letters and Colors. [fakeDone] gives units a one-lesson stand-in (to show later states).
TrackContent _previewContent({Set<String> fakeDone = const {}}) {
  final json = jsonDecode(File('assets/content/little_learners.json').readAsStringSync()) as Map<String, dynamic>;
  final units = (json['units'] as List).cast<Map<String, dynamic>>();
  final order = ['letters', 'colors', 'numbers', 'shapes', 'animals', 'feelings', 'my-body', 'actions', 'food', 'clothes', 'toys', 'my-family', 'my-home', 'opposites', 'transport'];
  const added = {
    'feelings': ('Feelings', 'feelings', 'purple'),
    'actions': ('Actions', 'actions', 'orange'),
    'clothes': ('Clothes', 'clothes', 'blue'),
    'toys': ('Toys', 'toys', 'red'),
    'my-home': ('My Home', 'home', 'teal'),
    'opposites': ('Opposites', 'opposites', 'pink'),
    'transport': ('Transport', 'transport', 'green'),
  };
  for (final e in added.entries.where((e) => !units.any((u) => u['id'] == e.key))) {
    units.add({'id': e.key, 'order': 0, 'title': {'en': e.value.$1, 'ar': e.value.$1}, 'icon': e.value.$2, 'color': e.value.$3, 'lessons': []});
  }
  for (final u in units) {
    u['order'] = order.indexOf(u['id'] as String) + 1;
    if (u['id'] == 'letters' || u['id'] == 'colors') u['story'] = {'pages': []};
    if (fakeDone.contains(u['id'])) {
      u['lessons'] = [
        {
          'id': 'preview-${u['id']}',
          'order': 1,
          'level': 'pre-a1',
          'audio': {'intro': 'x.mp3', 'praise': ['x.mp3']},
          'words': [],
          'activities': ['listen-and-tap'],
        }
      ];
    }
  }
  json['reviews'] ??= [
    {'id': 'review-1', 'units': ['letters', 'colors', 'numbers', 'shapes']},
    {'id': 'review-2', 'units': ['animals', 'feelings', 'my-body', 'actions']},
    {'id': 'review-3', 'units': ['food', 'clothes', 'toys']},
  ];
  return TrackContent.fromJson(json);
}

const _child = '[{"id":"c1","name":"Omar","avatarKey":"bunny","birthYear":2022,"track":"little-learners","createdAt":"2026-01-01T00:00:00Z"}]';

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
const _colors = ['color-red', 'color-blue', 'color-yellow', 'color-green', 'color-orange', 'color-purple', 'color-pink', 'color-brown', 'color-black', 'color-white'];

Future<void> _open(WidgetTester t, {required TrackContent content, String? progress, Map<String, Object> meta = const {}}) async {
  t.view.physicalSize = const Size(1080, 2400);
  t.view.devicePixelRatio = 1080 / 411;
  t.view.padding = const FakeViewPadding(top: 63, bottom: 63); // status bar and home indicator
  addTearDown(t.view.reset);
  final overrides = await testOverrides(content: content, prefs: {
    'settings.v1': '{"languageCode":"ar","sessionMinutes":15,"unlockAll":false,"onboarded":true}',
    'children.v1': _child,
    'progress.v1': ?progress,
    if (meta.isNotEmpty) 'meta.v2': jsonEncode({'schema': 2, 'children': {'c1': meta}}),
  });
  final container = ProviderContainer(overrides: [...overrides, audioServiceProvider.overrideWithValue(FakeAudio()), recorderServiceProvider.overrideWithValue(FakeRecorder())]);
  addTearDown(container.dispose);
  await t.pumpWidget(UncontrolledProviderScope(container: container, child: const KidsEnglishApp()));
  await t.pumpAndSettle();
  await _settleImages(t);
}

/// Pictures (webp, svg) decode on real time, outside the fake clock.
Future<void> _settleImages(WidgetTester t) async {
  for (var i = 0; i < 3; i++) {
    await t.runAsync(() async {
      for (final e in find.byType(Image).evaluate()) {
        await precacheImage((e.widget as Image).image, e);
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await t.pump();
  }
}

Future<void> _shot(WidgetTester t, String name) async {
  await expectLater(find.byType(KidsEnglishApp), matchesGoldenFile('$_out/$name.png'));
}

ScrollableState _map(WidgetTester t) => t.state<ScrollableState>(find.descendant(of: find.byKey(const Key('unit-map')), matching: find.byType(Scrollable)));

Future<void> _scrollTo(WidgetTester t, String stopKey) async {
  final pos = _map(t).position;
  final box = t.getRect(find.byKey(Key(stopKey)));
  pos.jumpTo((pos.pixels + box.center.dy - 1200 / (1080 / 411) * 0.5 - 150).clamp(0, pos.maxScrollExtent));
  await t.pump();
  await _settleImages(t);
}

void main() {
  setUpAll(_loadFonts);
  setUp(() => SkyBackground.drift = false);

  testWidgets('01 top of the path: a new child, greeting showing', (t) async {
    await _open(t, content: _previewContent());
    await _shot(t, '01-top-new-child');
    // the greeting shrinks back to the avatar after three seconds
    await t.pump(const Duration(seconds: 4));
    await t.pumpAndSettle();
    await _shot(t, '02-top-bar-after-greeting');
  });

  testWidgets('03 Letters done, Colors in progress: stations after Letters, chest ready, the wardrobe dot', (t) async {
    await _open(t, content: _previewContent(), progress: _progress([..._letters, 'color-red', 'color-blue', 'color-yellow', 'color-green']), meta: {'certificates': {'letters': '2026-09-01'}, 'celebrated': ['letters']});
    await t.pump(const Duration(seconds: 4));
    await t.pumpAndSettle();
    await _shot(t, '03-colors-current');
  });

  testWidgets('04 tapping a locked island: Dandoona shakes her head and says what comes first', (t) async {
    await _open(t, content: _previewContent(), progress: _progress([..._letters, 'color-red', 'color-blue', 'color-yellow', 'color-green']), meta: {'certificates': {'letters': '2026-09-01'}, 'celebrated': ['letters']});
    await t.pump(const Duration(seconds: 4));
    await t.pumpAndSettle();
    // scroll down a little so a closed island is on screen with Dandoona
    final pos = _map(t).position;
    pos.jumpTo(pos.pixels + 260);
    await t.pump();
    await _settleImages(t);
    await t.tap(find.byKey(const Key('unit-numbers')));
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    await _settleImages(t);
    await _shot(t, '04-soon-tap');
    await t.pumpAndSettle(const Duration(seconds: 1));
    await t.pump(const Duration(seconds: 3));
    await t.tap(find.byKey(const Key('stop-chest-colors')));
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    await _settleImages(t);
    await _shot(t, '04b-locked-tap');
    await t.pumpAndSettle(const Duration(seconds: 1));
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('05 every station state: story read and chest opened (Letters), story and chest ready (Colors), review ready', (t) async {
    await _open(
      t,
      content: _previewContent(fakeDone: {'numbers', 'shapes'}),
      progress: _progress([..._letters, ..._colors, 'preview-numbers', 'preview-shapes']),
      meta: {'certificates': {'letters': '2026-09-01', 'colors': '2026-09-20'}, 'celebrated': ['letters', 'colors'], 'stories': ['letters'], 'chests': ['letters']},
    );
    await t.pump(const Duration(seconds: 4));
    await t.pumpAndSettle();
    await _scrollTo(t, 'stop-story-letters');
    await _shot(t, '05-stations-letters-colors');
    await _scrollTo(t, 'stop-review-1');
    await _shot(t, '06-review-ready');
  });

  testWidgets('07 middle and end of the path', (t) async {
    await _open(t, content: _previewContent(), progress: _progress(_letters), meta: {'certificates': {'letters': '2026-09-01'}, 'celebrated': ['letters']});
    await t.pump(const Duration(seconds: 4));
    await t.pumpAndSettle();
    await _scrollTo(t, 'unit-actions');
    await _shot(t, '07-middle');
    final pos = _map(t).position;
    pos.jumpTo(pos.maxScrollExtent);
    await t.pump();
    await _settleImages(t);
    await _shot(t, '08-end-castle');
  });
}
