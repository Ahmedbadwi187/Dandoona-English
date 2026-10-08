// Explorers phase 2 (Digraphs, Blends, Magic E, Vowel Teams) for the owner to look at: every new drawing, the four new outfits on
// Dandoona, the map with its two review stops, and the games with two-letter sounds and the magic e. Not part of `flutter test`
// (it lives outside test/). Run:
//   flutter test test_screenshots/explorers_phase2_test.dart --update-goldens
// The pictures land in docs/design-options/explorers/phase-2/. The lessons are read from content/curriculum (their audio is not
// generated yet, so the exported catalog does not list them); pictures come straight from content/art, or for a picture reused
// from Little Learners, from its drawing or its approved generated image. Word Builder shuffles its tiles, so that picture is a
// preview, not a fixed comparison.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/app.dart';
import 'package:kids_english_app/core/palette.dart';
import 'package:kids_english_app/core/sky.dart';
import 'package:kids_english_app/features/audio/audio_service.dart';
import 'package:kids_english_app/features/content/content_models.dart';
import 'package:kids_english_app/features/progress/progress.dart';
import 'package:kids_english_app/router.dart';

import '../test/helpers.dart';

const _out = '../../../docs/design-options/explorers/phase-2';
final _root = Directory('../..').absolute.path;
const _units = ['sound-builders', 'digraphs', 'blends', 'magic-e', 'vowel-teams'];

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

/// One word of a lesson file: `- { word: cake, graphemes: [c, "a:ay", ...], reuse: "little-learners:x/y" }` or `source: svg`.
final _wordLine = RegExp(r'word: (\w+), graphemes: \[([^\]]*)\], (?:reuse: "little-learners:([\w-]+)/(\w+)"|source: svg)');

String _picture(String lesson, String word, String? llLesson, String? llKey) {
  if (llLesson == null) return '$_root/content/art/explorers/$lesson/$word.svg';
  final drawn = File('$_root/content/art/little-learners/$llLesson/$llKey.svg');
  return drawn.existsSync() ? drawn.path : '$_root/content/generated/little-learners/$llLesson/images/$llKey.approved.webp';
}

/// The lessons of [unit] as the generator would export them (audio paths are placeholders).
List<Map<String, dynamic>> _lessons(String unit) {
  final files = Directory('$_root/content/curriculum').listSync().whereType<File>().where((f) => f.readAsStringSync().contains('\nunit: $unit\n')).toList();
  final lessons = <Map<String, dynamic>>[];
  for (final f in files) {
    final text = f.readAsStringSync();
    final id = RegExp(r'^id: ([\w-]+)$', multiLine: true).firstMatch(text)!.group(1)!;
    final order = int.parse(RegExp(r'^order: (\d+)$', multiLine: true).firstMatch(text)!.group(1)!);
    lessons.add({
      'id': id,
      'order': order,
      'level': 'a1',
      'audio': {
        'intro': 'audio/x/intro.mp3',
        'praise': ['audio/x/p.mp3'],
        'instructions': {'sound-tap': 'x.mp3', 'word-builder': 'x.mp3', 'read-and-pick': 'x.mp3'},
      },
      'words': [
        for (final m in _wordLine.allMatches(text))
          {
            'word': m.group(1),
            'audio': 'audio/x/${m.group(1)}.mp3',
            'image': _picture(id, m.group(1)!, m.group(3), m.group(4)),
            'graphemes': [for (final g in m.group(2)!.split(',')) g.trim().replaceAll('"', '')],
          },
      ],
      'activities': ['sound-tap', 'word-builder', 'read-and-pick'],
    });
  }
  return lessons..sort((a, b) => (a['order'] as int).compareTo(b['order'] as int));
}

TrackContent _explorers() {
  final json = jsonDecode(File('assets/content/explorers.json').readAsStringSync()) as Map<String, dynamic>;
  for (final u in (json['units'] as List).cast<Map<String, dynamic>>()) {
    if (!_units.contains(u['id'])) continue;
    u['lessons'] = _lessons(u['id'] as String);
    u.remove('pack'); // shown as if its pack were installed
  }
  final keys = RegExp(r'\{ key: (\w+),').allMatches(File('$_root/content/curriculum/units/explorers.yaml').readAsStringSync()).map((m) => m.group(1)!);
  json['phonemes'] = {for (final k in keys) k: 'audio/explorers/phonemes/phoneme_$k.mp3'};
  return TrackContent.fromJson(json);
}

String _progress(Iterable<String> lessons) => jsonEncode([
      for (final (i, l) in lessons.indexed)
        ProgressRecord(clientRecordId: 'r-$l', childId: 'e1', lessonId: l, activity: 'trace', stars: 3, attempts: 1, timeSpentSeconds: 30, completedAt: DateTime(2026, 9, 1 + (i % 6), 10)).toJson(),
    ]);

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
  await _settle(t);
  return container;
}

/// Pictures (webp, svg, files) decode on real time, outside the fake clock.
Future<void> _settle(WidgetTester t) async {
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

Future<void> _game(WidgetTester t, ProviderContainer c, String lesson, String activity) async {
  c.read(routerProvider).push('/lesson/$lesson/$activity');
  await t.pumpAndSettle();
  await _settle(t);
}

/// A sheet on a plain page (not the app): the pictures with their words, a few per row.
Future<void> _sheet(WidgetTester t, String name, List<(String, Widget)> items, {int columns = 5, double cell = 200}) async {
  final rows = (items.length / columns).ceil();
  t.view.physicalSize = Size(columns * cell + 32, rows * (cell + 40) + 32);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: Palette.cream,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          children: [
            for (final (label, w) in items)
              SizedBox(
                width: cell,
                height: cell + 40,
                child: Column(children: [
                  SizedBox(width: cell - 16, height: cell - 16, child: w),
                  Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Palette.nightInk)),
                ]),
              ),
          ],
        ),
      ),
    ),
  ));
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 800)));
  await t.pumpAndSettle();
  await _settle(t);
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('$_out/$name.png'));
}

void main() {
  setUpAll(_loadFonts);
  setUp(() => SkyBackground.drift = false);

  testWidgets('01 every new drawing of phase 2', (t) async {
    final dir = Directory('$_root/content/art/explorers');
    final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.svg') && !f.path.contains('sound-builders')).toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    await _sheet(t, '01-new-drawings', [
      for (final f in files) ('${f.parent.uri.pathSegments.reversed.elementAt(1)}: ${f.uri.pathSegments.last.replaceAll('.svg', '')}', SvgPicture.file(f)),
    ], columns: 6, cell: 190);
  });

  testWidgets('02 the four new outfits on Dandoona', (t) async {
    // decoded up front on real time, so the sheet needs no image loading
    final mascot = (await t.runAsync(() async {
      final codec = await ui.instantiateImageCodec(File('assets/images/mascot/mascot.webp').readAsBytesSync());
      return (await codec.getNextFrame()).image;
    }))!;
    await _sheet(t, '02-outfits', [
      for (final o in ['headphones', 'bandana', 'wizard-hat', 'team-cap'])
        (o, Stack(children: [Positioned.fill(child: RawImage(image: mascot, fit: BoxFit.contain)), Positioned.fill(child: SvgPicture.file(File('$_root/content/art/accessories/$o.svg')))])),
    ], columns: 4, cell: 260);
  });

  testWidgets('03 the map: Sound Builders done (its story and chest), Digraphs current', (t) async {
    final done = [for (var i = 0; i < 26; i++) 'letter-${String.fromCharCode(97 + i)}', for (final v in 'aeiou'.split('')) 'sound-builders-$v'];
    await _open(t, progress: _progress(done));
    await t.pump(const Duration(seconds: 4));
    await t.pumpAndSettle();
    final pos = t.state<ScrollableState>(find.descendant(of: find.byKey(const Key('unit-map')), matching: find.byType(Scrollable))).position;
    await t.drag(find.byKey(const Key('unit-map')), const Offset(0, 300)); // a little up the path, so the review stop shows
    await t.pumpAndSettle();
    await _settle(t);
    expect(pos.pixels, isNonNegative);
    await expectLater(find.byType(KidsEnglishApp), matchesGoldenFile('$_out/03-map-digraphs-current.png'));
  });

  testWidgets('04 Sound Tap with the magic e: cake, the e is quieter', (t) async {
    final c = await _open(t, extra: {'demos.v1': '{"e1":["sound-tap","word-builder","read-and-pick"]}'});
    await _game(t, c, 'magic-e-a', 'sound-tap');
    await t.tap(find.byKey(const Key('sound-box-0')));
    await t.pump(const Duration(milliseconds: 100));
    await t.tap(find.byKey(const Key('sound-box-1')));
    await t.pump(const Duration(milliseconds: 100));
    await expectLater(find.byType(KidsEnglishApp), matchesGoldenFile('$_out/04-sound-tap-magic-e.png'));
    await t.pumpAndSettle();
  });

  testWidgets('05 Sound Tap with a digraph: sh is one box', (t) async {
    final c = await _open(t, extra: {'demos.v1': '{"e1":["sound-tap","word-builder","read-and-pick"]}'});
    await _game(t, c, 'digraphs-sh', 'sound-tap');
    await t.tap(find.byKey(const Key('sound-box-2')));
    await t.pump(const Duration(milliseconds: 100));
    await expectLater(find.byType(KidsEnglishApp), matchesGoldenFile('$_out/05-sound-tap-digraph.png'));
    await t.pumpAndSettle();
  });

  testWidgets('06 Word Builder with a vowel team: rain, half built', (t) async {
    final c = await _open(t, extra: {'demos.v1': '{"e1":["sound-tap","word-builder","read-and-pick"]}'});
    await _game(t, c, 'vowel-teams-ai', 'word-builder');
    for (final g in ['r', 'ai']) {
      for (var i = 0; i < 6; i++) {
        final tile = find.byKey(Key('builder-tile-$i'));
        if (tile.evaluate().isNotEmpty && t.widget<Text>(find.descendant(of: tile, matching: find.byType(Text))).data == g) {
          await t.tap(tile);
          await t.pump(const Duration(milliseconds: 600));
          break;
        }
      }
    }
    await expectLater(find.byType(KidsEnglishApp), matchesGoldenFile('$_out/06-word-builder-vowel-team.png'));
    await t.pumpAndSettle();
  });

  testWidgets('07 Read & Pick in Magic E', (t) async {
    final c = await _open(t, extra: {'demos.v1': '{"e1":["sound-tap","word-builder","read-and-pick"]}'});
    await _game(t, c, 'magic-e-i', 'read-and-pick');
    await expectLater(find.byType(KidsEnglishApp), matchesGoldenFile('$_out/07-read-and-pick-magic-e.png'));
  });
}
