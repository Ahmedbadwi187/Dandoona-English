// Explorers phase 3 (Sight Words 1 and 2, My Sentences) for the owner to look at: the three new outfits on Dandoona and the new
// games (Find the Word, Sentence Builder, Fill the Gap with is/are and a/an). Not part of `flutter test` (it lives outside
// test/). Run one at a time if a run stalls:
//   flutter test test_screenshots/explorers_phase3_test.dart --update-goldens [--plain-name "02 "]
// The pictures land in docs/design-options/explorers/phase-3/. The lessons are read from content/curriculum (their audio is
// not generated yet, so the exported catalog does not list them). The games shuffle, so the pictures are previews.
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
import 'package:kids_english_app/features/activities/phonics_activities.dart';
import 'package:kids_english_app/features/activities/sentence_activities.dart';
import 'package:kids_english_app/features/audio/audio_service.dart';
import 'package:kids_english_app/features/content/content_models.dart';
import 'package:kids_english_app/router.dart';

import '../test/helpers.dart';

const _out = '../../../docs/design-options/explorers/phase-3';
final _root = Directory('../..').absolute.path;
const _units = ['sight-words-1', 'sight-words-2', 'my-sentences'];
const _seen = '{"e1":["find-the-word","sentence-builder","fill-the-gap"]}';

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

/// A reused picture: the app's own copy of a Little Learners picture, else the Explorers drawing (svg files load fine; a webp read
/// from a file can stall the test clock).
String _picture(String reuse) {
  final track = reuse.contains(':') ? reuse.substring(0, reuse.indexOf(':')) : 'explorers';
  final path = reuse.contains(':') ? reuse.substring(reuse.indexOf(':') + 1) : reuse;
  final (lesson, key) = (path.split('/')[0], path.split('/')[1]);
  for (final ext in ['webp', 'svg']) {
    final bundled = 'images/${track.replaceAll('-', '_')}/${lesson.replaceAll('-', '_')}/$key.$ext';
    if (File('assets/$bundled').existsSync()) return bundled;
  }
  return '$_root/content/art/$track/$lesson/$key.svg';
}

List<Map<String, dynamic>> _lessons(String unit) {
  final files = Directory('$_root/content/curriculum').listSync().whereType<File>().where((f) => f.readAsStringSync().contains('\nunit: $unit\n'));
  final lessons = <Map<String, dynamic>>[];
  for (final f in files) {
    final text = f.readAsStringSync();
    final id = RegExp(r'^id: ([\w-]+)$', multiLine: true).firstMatch(text)!.group(1)!;
    final images = {for (final m in RegExp(r'word: (\w+), reuse: "([^"]+)"').allMatches(text)) m.group(1)!: _picture(m.group(2)!)};
    final sight = RegExp(r'^sightWords: \[([^\]]*)\]$', multiLine: true).firstMatch(text)?.group(1)?.split(',').map((w) => w.trim()).toList() ?? [];
    lessons.add({
      'id': id,
      'order': int.parse(RegExp(r'^order: (\d+)$', multiLine: true).firstMatch(text)!.group(1)!),
      'level': 'a1',
      'audio': {
        'intro': 'audio/x/intro.mp3',
        'praise': ['audio/x/p.mp3'],
        'instructions': {'find-the-word': 'x.mp3', 'sentence-builder': 'x.mp3', 'fill-the-gap': 'x.mp3'},
      },
      'words': [for (final e in images.entries) {'word': e.key, 'audio': 'audio/x/${e.key}.mp3', 'image': e.value}],
      'sightWords': [for (final w in sight) {'word': w, 'audio': 'audio/x/sight_$w.mp3'}],
      'sentences': [
        for (final m in RegExp(r'text: "([^"]+)", picture: (\w+)(, two: true)?(?:, gap: (\w+), choices: \[([^\]]*)\])?').allMatches(text))
          {
            'text': m.group(1),
            'audio': 'audio/x/s.mp3',
            'image': images[m.group(2)],
            'two': m.group(3) != null,
            if (m.group(4) != null) 'gap': m.group(4),
            if (m.group(5) != null) 'choices': m.group(5)!.split(',').map((c) => c.trim()).toList(),
          },
      ],
      'activities': RegExp(r'^activities: \[([^\]]*)\]$', multiLine: true).firstMatch(text)!.group(1)!.split(',').map((a) => a.trim()).toList(),
    });
  }
  return lessons;
}

TrackContent _explorers() {
  final json = jsonDecode(File('assets/content/explorers.json').readAsStringSync()) as Map<String, dynamic>;
  for (final u in (json['units'] as List).cast<Map<String, dynamic>>()) {
    if (!_units.contains(u['id'])) continue;
    u['lessons'] = _lessons(u['id'] as String);
    u.remove('pack'); // shown as if its pack were installed
  }
  return TrackContent.fromJson(json);
}

Future<ProviderContainer> _open(WidgetTester t) async {
  t.view.physicalSize = const Size(1080, 2400);
  t.view.devicePixelRatio = 1080 / 411;
  t.view.padding = const FakeViewPadding(top: 63, bottom: 63);
  addTearDown(t.view.reset);
  final overrides = await testOverrides(content: realContent(), explorers: _explorers(), prefs: {
    'settings.v1': '{"languageCode":"en","sessionMinutes":15,"unlockAll":false,"onboarded":true}',
    'children.v1': '[{"id":"e1","name":"Lina","avatarKey":"owl","birthYear":2019,"birthMonth":2,"track":"explorers","createdAt":"2026-01-01T00:00:00Z"}]',
    'demos.v1': _seen,
  });
  final container = ProviderContainer(overrides: [...overrides, audioServiceProvider.overrideWithValue(FakeAudio()), recorderServiceProvider.overrideWithValue(FakeRecorder())]);
  addTearDown(container.dispose);
  await t.pumpWidget(UncontrolledProviderScope(container: container, child: const KidsEnglishApp()));
  await t.pumpAndSettle();
  return container;
}

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

Future<void> _shot(WidgetTester t, String name) async {
  await _settle(t);
  await expectLater(find.byType(KidsEnglishApp), matchesGoldenFile('$_out/$name.png'));
}

void main() {
  setUpAll(_loadFonts);
  setUp(() => SkyBackground.drift = false);

  testWidgets('01 the three new outfits on Dandoona', (t) async {
    final mascot = (await t.runAsync(() async {
      final codec = await ui.instantiateImageCodec(File('assets/images/mascot/mascot.webp').readAsBytesSync());
      return (await codec.getNextFrame()).image;
    }))!;
    t.view.physicalSize = const Size(3 * 260 + 32, 300 + 32);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Palette.cream,
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            for (final o in ['book-hat', 'detective-cap', 'pencil-band'])
              SizedBox(
                width: 260,
                child: Column(children: [
                  SizedBox(
                    width: 244,
                    height: 244,
                    child: Stack(children: [
                      Positioned.fill(child: RawImage(image: mascot, fit: BoxFit.contain)),
                      Positioned.fill(child: SvgPicture.file(File('$_root/content/art/accessories/$o.svg'))),
                    ]),
                  ),
                  Text(o, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Palette.nightInk)),
                ]),
              ),
          ]),
        ),
      ),
    ));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 800)));
    await t.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('$_out/01-outfits.png'));
  });

  testWidgets('02 Find the Word: hear "the", find it', (t) async {
    final c = await _open(t);
    await _game(t, c, 'sight-words-1-a', 'find-the-word');
    await _shot(t, '02-find-the-word');
  });

  testWidgets('03 Sentence Builder: "They are bees." half built, two bees in the picture', (t) async {
    final c = await _open(t);
    final lesson = _explorers().units.firstWhere((u) => u.id == 'sight-words-2').lessons.firstWhere((l) => l.id == 'sight-words-2-c');
    expect(lesson.sentences.any((s) => s.two), isTrue);
    await _game(t, c, 'sight-words-2-c', 'sentence-builder');
    // build the first two words of the sentence on screen (its words come from the lesson's sentences)
    final sentence = lesson.sentences.firstWhere((x) {
      final cards = [for (var i = 0; i < 8; i++) if (find.byKey(Key('sentence-tile-$i')).evaluate().isNotEmpty) t.widget<WordCard>(find.descendant(of: find.byKey(Key('sentence-tile-$i')), matching: find.byType(WordCard))).text]..sort();
      return (x.tokens.toList()..sort()).join(' ') == cards.join(' ');
    });
    for (final word in sentence.tokens.take(2)) {
      for (var i = 0; i < 8; i++) {
        final tile = find.byKey(Key('sentence-tile-$i'));
        if (tile.evaluate().isNotEmpty && t.widget<WordCard>(find.descendant(of: tile, matching: find.byType(WordCard))).text == word) {
          await t.tap(tile);
          await t.pump(const Duration(milliseconds: 600));
          break;
        }
      }
    }
    await _shot(t, '03-sentence-builder');
    await t.pumpAndSettle();
  });

  testWidgets('04 Fill the Gap: is or are, the picture tells', (t) async {
    final c = await _open(t);
    await _game(t, c, 'my-sentences-is-are', 'fill-the-gap');
    // answer until a round shows two things ("are")
    for (var r = 0; r < 5 && !t.widget<ManyPicture>(find.byType(ManyPicture)).two; r++) {
      await t.tap(find.byKey(const Key('gap-choice-is')));
      await t.pump(const Duration(seconds: 2));
      await t.pumpAndSettle();
      await _settle(t);
    }
    await _shot(t, '04-fill-the-gap-is-are');
  });

  testWidgets('05 Fill the Gap: a or an', (t) async {
    final c = await _open(t);
    await _game(t, c, 'my-sentences-a-an', 'fill-the-gap');
    await _shot(t, '05-fill-the-gap-a-an');
  });
}
