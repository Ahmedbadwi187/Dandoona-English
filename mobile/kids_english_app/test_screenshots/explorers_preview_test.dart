// Explorers (6-8) at phone size with the real fonts and pictures, for the owner to look at: the map (top, middle, end) and
// each new game, with its hand demo. Not part of `flutter test` (it lives outside test/). Run:
//   flutter test test_screenshots/explorers_preview_test.dart --update-goldens
// The pictures land in docs/design-options/explorers/. The Sound Builders lessons are added here from their lesson files'
// words (their audio is not generated yet, so the exported catalog does not list them); the new drawings are read straight
// from content/art/explorers.
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
import 'package:kids_english_app/router.dart';

import '../test/helpers.dart';

const _out = '../../../docs/design-options/explorers';
final _art = Directory('../../content/art/explorers').absolute.path;
final _ll = Directory('../../content/art/little-learners').absolute.path; // pictures of Little Learners pack units

Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter';
  final dir = '$root/bin/cache/artifacts/material_fonts';
  final roboto = FontLoader('Roboto');
  for (final f in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf', 'Roboto-Black.ttf']) {
    roboto.addFont(Future.value(ByteData.sublistView(File('$dir/$f').readAsBytesSync())));
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(File('$dir/MaterialIcons-Regular.otf').readAsBytesSync())));
  await icons.load();
}

// The five lessons as in content/curriculum/sound-builders-*.yaml: a picture reused from Little Learners (in the app's assets)
// or one of the new drawings (read from content/art).
final _lessons = {
  'a': [('cat', 'images/little_learners/letter_c/cat.webp'), ('jam', null), ('bag', null), ('hat', 'images/little_learners/letter_h/hat.svg')],
  'e': [('hen', null), ('bed', '$_ll/my-home-1/bed.svg'), ('pen', null), ('ten', '$_ll/number-7-10/ten.svg')],
  'i': [('pig', 'images/little_learners/letter_p/pig.webp'), ('fig', null), ('bin', null), ('six', '$_ll/number-4-6/six.svg')],
  'o': [('dog', 'images/little_learners/letter_d/dog.webp'), ('pot', null), ('box', 'images/little_learners/letter_x/box.svg'), ('mop', null)],
  'u': [('bug', null), ('nut', 'images/little_learners/letter_n/nut.svg'), ('bus', '$_ll/transport-1/bus.svg'), ('cup', null)],
};

TrackContent _explorers() {
  final json = jsonDecode(File('assets/content/explorers.json').readAsStringSync()) as Map<String, dynamic>;
  final sb = (json['units'] as List).cast<Map<String, dynamic>>().firstWhere((u) => u['id'] == 'sound-builders');
  var order = 0;
  sb['lessons'] = [
    for (final e in _lessons.entries)
      {
        'id': 'sound-builders-${e.key}',
        'order': ++order,
        'level': 'a1',
        'audio': {
          'intro': 'audio/x/intro.mp3',
          'praise': ['audio/x/p.mp3'],
          'instructions': {'sound-tap': 'x.mp3', 'word-builder': 'x.mp3', 'read-and-pick': 'x.mp3'},
        },
        'words': [
          for (final (w, img) in e.value) {'word': w, 'audio': 'audio/x/$w.mp3', 'image': img ?? '$_art/sound-builders-${e.key}/$w.svg', 'graphemes': w.split('')},
        ],
        'activities': ['sound-tap', 'word-builder', 'read-and-pick'],
      },
  ];
  json['phonemes'] = {for (final g in 'abcdefghijmnopstux'.split('')) g: 'audio/explorers/phonemes/phoneme_$g.mp3'};
  return TrackContent.fromJson(json);
}

String _progress(Iterable<String> lessons, {int days = 1}) => jsonEncode([
      for (final (i, l) in lessons.indexed)
        ProgressRecord(
          clientRecordId: 'r-$l',
          childId: 'e1',
          lessonId: l,
          activity: 'trace',
          stars: 3,
          attempts: 1,
          timeSpentSeconds: 30,
          completedAt: DateTime(2026, 9, 1 + (i % days), 10),
        ).toJson(),
    ]);

final _letters = [for (var i = 0; i < 26; i++) 'letter-${String.fromCharCode(97 + i)}'];

Future<ProviderContainer> _open(WidgetTester t, {String? progress, Map<String, Object> extra = const {}}) async {
  t.view.physicalSize = const Size(1080, 2400);
  t.view.devicePixelRatio = 1080 / 411;
  t.view.padding = const FakeViewPadding(top: 63, bottom: 63);
  addTearDown(t.view.reset);
  final overrides = await testOverrides(content: realContent(), explorers: _explorers(), prefs: {
    'settings.v1': '{"languageCode":"en","sessionMinutes":15,"unlockAll":false,"onboarded":true}',
    'children.v1': '[{"id":"e1","name":"Lina","avatarKey":"owl","birthYear":2019,"birthMonth":2,"track":"explorers","createdAt":"2026-01-01T00:00:00Z"}]',
    'progress.v1': ?progress,
    ...extra,
  });
  final container = ProviderContainer(overrides: [...overrides, audioServiceProvider.overrideWithValue(FakeAudio()), recorderServiceProvider.overrideWithValue(FakeRecorder())]);
  addTearDown(container.dispose);
  await t.pumpWidget(UncontrolledProviderScope(container: container, child: const KidsEnglishApp()));
  await t.pumpAndSettle();
  await _settleImages(t);
  return container;
}

/// Pictures (webp, svg, files) decode on real time, outside the fake clock.
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
  await _settleImages(t);
  await expectLater(find.byType(KidsEnglishApp), matchesGoldenFile('$_out/$name.png'));
}

ScrollableState _map(WidgetTester t) => t.state<ScrollableState>(find.descendant(of: find.byKey(const Key('unit-map')), matching: find.byType(Scrollable)));

Future<void> _game(WidgetTester t, ProviderContainer c, String lesson, String activity) async {
  c.read(routerProvider).push('/lesson/$lesson/$activity');
  await t.pump();
  await t.pump(const Duration(milliseconds: 200));
}

void main() {
  setUpAll(_loadFonts);
  setUp(() => SkyBackground.drift = false);

  testWidgets('01 the Explorers map for a new child: Letters first (Little Learners Letters inside Explorers)', (t) async {
    await _open(t);
    await t.pump(const Duration(seconds: 4));
    await t.pumpAndSettle();
    await _shot(t, '01-map-top-new-child');
  });

  testWidgets('02 Letters done: Sound Builders is current, the active days are celebrated', (t) async {
    await _open(t, progress: _progress(_letters, days: 5));
    await t.pump(const Duration(seconds: 4));
    await t.pumpAndSettle();
    await _shot(t, '02-map-sound-builders-current');
    final pos = _map(t).position;
    pos.jumpTo(pos.maxScrollExtent * 0.5);
    await t.pump();
    await _shot(t, '03-map-middle');
    pos.jumpTo(pos.maxScrollExtent);
    await t.pump();
    await _shot(t, '04-map-end');
  });

  testWidgets('05 Sound Tap: the demo hand, then two sounds heard', (t) async {
    final c = await _open(t, progress: _progress(_letters));
    await _game(t, c, 'sound-builders-a', 'sound-tap');
    for (var i = 0; i < 9; i++) {
      await t.pump(const Duration(milliseconds: 100)); // frame by frame, so the hand moves
    }
    await _shot(t, '05-sound-tap-demo');
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('sound-box-0')));
    await t.pump(const Duration(milliseconds: 100));
    await t.tap(find.byKey(const Key('sound-box-1')));
    await t.pump(const Duration(milliseconds: 100));
    await _shot(t, '06-sound-tap');
    await t.pumpAndSettle();
  });

  testWidgets('07 Word Builder: the demo drags a tile, then a word half built', (t) async {
    final c = await _open(t, progress: _progress(_letters), extra: {'demos.v1': '{}'});
    await _game(t, c, 'sound-builders-e', 'word-builder');
    for (var i = 0; i < 13; i++) {
      await t.pump(const Duration(milliseconds: 100)); // frame by frame, so the hand moves
    }
    await _shot(t, '07-word-builder-demo');
    await t.pumpAndSettle();
    final tiles = [
      for (var i = 0; i < 5; i++)
        if (find.byKey(Key('builder-tile-$i')).evaluate().isNotEmpty)
          (i, t.widget<Text>(find.descendant(of: find.byKey(Key('builder-tile-$i')), matching: find.byType(Text))).data),
    ];
    for (final g in ['h', 'e']) {
      final i = tiles.firstWhere((x) => x.$2 == g, orElse: () => (-1, null)).$1;
      if (i >= 0) {
        await t.tap(find.byKey(Key('builder-tile-$i')));
        await t.pump(const Duration(milliseconds: 200));
      }
    }
    await _shot(t, '08-word-builder');
    await t.pumpAndSettle();
  });

  testWidgets('09 Read & Pick: the demo points at the word and its picture, then a round', (t) async {
    final c = await _open(t, progress: _progress(_letters));
    await _game(t, c, 'sound-builders-o', 'read-and-pick');
    for (var i = 0; i < 15; i++) {
      await t.pump(const Duration(milliseconds: 100)); // frame by frame, so the hand moves
    }
    await _shot(t, '09-read-and-pick-demo');
    await t.pumpAndSettle();
    await _shot(t, '10-read-and-pick');
  });

  testWidgets('11 the Sound Builders lesson: its three games', (t) async {
    final c = await _open(t, progress: _progress(_letters));
    c.read(routerProvider).push('/lesson/sound-builders-u');
    await t.pumpAndSettle();
    await _shot(t, '11-lesson-games');
  });
}
