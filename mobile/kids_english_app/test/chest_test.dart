import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/app.dart';
import 'package:kids_english_app/features/audio/audio_service.dart';
import 'package:kids_english_app/features/content/packs.dart';
import 'package:kids_english_app/features/profiles/child_profile.dart';
import 'package:kids_english_app/features/progress/progress.dart';
import 'package:kids_english_app/features/rewards/accessories.dart';
import 'package:kids_english_app/features/rewards/chest_rewards.dart';
import 'package:kids_english_app/features/rewards/chest_screen.dart';
import 'package:kids_english_app/features/units/unit_meta.dart';
import 'package:kids_english_app/router.dart';

import 'helpers.dart';

const _child = '[{"id":"c1","name":"Omar","avatarKey":"star","birthYear":2022,"track":"little-learners","createdAt":"2026-01-01T00:00:00Z"}]';
const _settings = '{"languageCode":"en","sessionMinutes":15,"unlockAll":false,"onboarded":true,"languageChosen":true}';

String _progress(Iterable<String> lessons) => jsonEncode([
      for (final l in lessons)
        ProgressRecord(clientRecordId: 'r-$l', childId: 'c1', lessonId: l, activity: 'listen-and-tap', stars: 3, attempts: 3, timeSpentSeconds: 10, completedAt: DateTime.utc(2026, 9, 1)).toJson(),
    ]);

final _letters = [for (var i = 0; i < 26; i++) 'letter-${String.fromCharCode(97 + i)}'];

/// The map of a child who finished Letters (so its chest is ready); [meta] is the saved unit meta, if any.
Future<(FakeAudio, ProviderContainer)> _open(WidgetTester t, {String? meta, String? children, PackRepository? packs}) async {
  t.view.physicalSize = const Size(1080, 2400);
  t.view.devicePixelRatio = 1080 / 411;
  addTearDown(t.view.reset);
  final audio = FakeAudio();
  final overrides = await testOverrides(content: realContent(), prefs: {
    'settings.v1': _settings,
    'children.v1': children ?? _child,
    'progress.v1': _progress(_letters),
    'meta.v2': ?meta,
  });
  final c = ProviderContainer(overrides: [...overrides, audioServiceProvider.overrideWithValue(audio), if (packs != null) packRepositoryProvider.overrideWithValue(packs)]);
  addTearDown(c.dispose);
  await t.pumpWidget(UncontrolledProviderScope(container: c, child: const KidsEnglishApp()));
  await t.pumpAndSettle();
  return (audio, c);
}

String _where(ProviderContainer c) => c.read(routerProvider).routerDelegate.currentConfiguration.last.matchedLocation;

void main() {
  group('what a chest holds (pure)', () {
    final content = realContent();
    final letters = content.units.firstWhere((u) => u.id == 'letters');

    test('every unit has a chest with an outfit and 3-4 stickers, and no outfit is given twice', () {
      for (final u in content.units) {
        expect(u.chest, isNotNull, reason: u.id);
        expect(u.chest!.stickers.length, inInclusiveRange(3, 4), reason: u.id);
      }
      expect(content.units.map((u) => u.chest!.accessory).toSet().length, content.units.length);
    });

    test('a sticker takes its picture and voice from the unit\'s own words', () {
      final apple = stickersOfUnit(letters).first;
      expect((apple.unitId, apple.word), ('letters', 'apple'));
      expect(apple.image, isNotNull);
      expect(apple.audio, isNotNull);
      expect(stickersOfUnit(letters).map((s) => s.word), ['apple', 'ball', 'cat', 'dog']);
    });

    test('a unit whose pack is not on the phone still lists its stickers, without picture or voice', () {
      final numbers = content.units.firstWhere((u) => u.id == 'numbers');
      final s = stickersOfUnit(numbers);
      expect(s.map((x) => x.word), ['one', 'three', 'five', 'ten']);
      expect(s.every((x) => x.image == null && x.audio == null), isTrue);
    });

    test('what a child owns is derived from the opened chests: nothing opened owns nothing, opened Letters owns its outfit and stickers', () {
      const none = ChestInventory(units: [], opened: {});
      expect(none.outfits, isEmpty);
      final inv = ChestInventory(units: content.units, opened: const {'letters', 'colors'});
      expect(inv.outfits, {'grad-cap', 'beret'});
      expect(inv.stickers.length, 8);
      expect(inv.allStickers.length, greaterThan(inv.stickers.length)); // the rest are empty frames
      expect(inv.unitOfOutfit('beret')!.id, 'colors');
    });

  test('an outfit that is not one of the five star outfits is still wearable (it comes from a chest)', () {
      expect(outfitById('grad-cap')!.assetPath, 'assets/images/accessories/grad-cap.svg');
      expect(outfitById('crown')!.unlockStars, 50);
      expect(outfitById(null), isNull);
      expect(accessoryById('grad-cap'), isNull); // the star list is only the five
    });
  });

  testWidgets('a ready chest on the map opens the chest screen; it waits for a tap, shakes, opens with a sound, the outfit flies to Dandoona, she wears it, "Got it!"', (t) async {
    final (audio, c) = await _open(t);
    await Scrollable.ensureVisible(t.element(find.byKey(const Key('stop-chest-letters'))), alignment: 0.5);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('wardrobe-new')), findsOneWidget); // the red dot: a chest is ready
    await t.tap(find.byKey(const Key('stop-chest-letters')));
    await t.pumpAndSettle();
    expect(_where(c), '/chest/letters');
    expect(find.byKey(const Key('chest-hint')), findsOneWidget); // "Tap to open the chest!"
    expect(find.byKey(const Key('chest-closed')), findsOneWidget);
    expect(find.byKey(const Key('chest-reward')), findsNothing);
    audio.played.clear();

    await t.tap(find.byKey(const Key('chest-tap')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600)); // shaking
    expect(find.byKey(const Key('chest-closed')), findsOneWidget);
    expect(c.read(unitMetaProvider).of('c1').chests, isEmpty);

    await t.pump(const Duration(milliseconds: 500)); // the lid has gone up
    expect(find.byKey(const Key('chest-open')), findsOneWidget);
    expect(audio.played, ['asset:$chestOpenSound']);
    expect(c.read(unitMetaProvider).of('c1').chests, {'letters'});
    expect(c.read(profilesProvider).single.equippedAccessory, 'grad-cap'); // worn right away

    await t.pump(const Duration(milliseconds: 600)); // the outfit is on its way
    expect(find.byKey(const Key('chest-flying')), findsOneWidget);

    await t.pump(const Duration(milliseconds: 1400)); // landed: she celebrates in it
    expect(find.byKey(const Key('chest-flying')), findsNothing);
    expect(audio.played, ['asset:$chestOpenSound', 'asset:audio/ui/cheer.wav']);

    await t.pump(const Duration(milliseconds: 1500));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('chest-reward')), findsOneWidget);
    expect(find.text('A new outfit for Dandoona!'), findsOneWidget);
    for (final w in ['apple', 'ball', 'cat', 'dog']) {
      expect(find.byKey(Key('chest-sticker-$w')), findsOneWidget, reason: w);
    }
    expect(t.getSize(find.byKey(const Key('chest-done'))).height, greaterThanOrEqualTo(64));

    await t.tap(find.byKey(const Key('chest-sticker-apple'))); // a sticker says its word
    await t.pump();
    expect(audio.played.last, startsWith('asset:audio/little_learners/letter_a/'));

    await t.tap(find.byKey(const Key('chest-done')));
    await t.pumpAndSettle();
    expect(_where(c), '/map');
    expect(find.byKey(const Key('wardrobe-new')), findsNothing); // no chest waiting any more
  });

  testWidgets('an opened chest shows as open on the map, and tapping it shows what was inside (no show, no sound, nothing changes)', (t) async {
    final (audio, c) = await _open(t, meta: '{"schema":2,"children":{"c1":{"certificates":{},"celebrated":["letters"],"chests":["letters"]}}}');
    await Scrollable.ensureVisible(t.element(find.byKey(const Key('stop-chest-letters'))), alignment: 0.5);
    await t.pumpAndSettle();
    audio.played.clear();
    await t.tap(find.byKey(const Key('stop-chest-letters')));
    await t.pumpAndSettle();
    expect(_where(c), '/chest/letters');
    expect(find.byKey(const Key('chest-hint')), findsNothing);
    expect(find.byKey(const Key('chest-open')), findsOneWidget);
    expect(find.text('Inside the chest'), findsOneWidget);
    expect(find.byKey(const Key('chest-reward')), findsOneWidget);
    expect(audio.played, isEmpty);
    expect(c.read(profilesProvider).single.equippedAccessory, isNull); // looking does not change what she wears
    await t.tap(find.byKey(const Key('chest-done')));
    await t.pumpAndSettle();
    expect(_where(c), '/map');
  });

  testWidgets('a child who had already passed a chest gets its outfit and stickers automatically', (t) async {
    final (_, c) = await _open(t, meta: '{"schema":2,"children":{"c1":{"certificates":{},"celebrated":["letters"],"chests":["letters"]}}}');
    final inv = c.read(chestInventoryProvider);
    c.read(activeChildIdProvider.notifier).select('c1');
    expect(c.read(chestInventoryProvider).outfits, {'grad-cap'});
    expect(inv.units, isNotEmpty);
    expect(c.read(chestInventoryProvider).stickers.map((s) => s.word), ['apple', 'ball', 'cat', 'dog']);
  });

  testWidgets('the wardrobe lists the chest outfits: locked (with the chest and its unit) until opened, then wearable', (t) async {
    final (_, c) = await _open(t, meta: '{"schema":2,"children":{"c1":{"certificates":{},"celebrated":["letters"],"chests":["letters"]}}}');
    c.read(routerProvider).push('/wardrobe');
    await t.pumpAndSettle();
    await t.ensureVisible(find.byKey(const Key('accessory-grad-cap')));
    expect(find.byKey(const Key('accessory-beret')), findsOneWidget);
    await t.tap(find.byKey(const Key('accessory-grad-cap')));
    await t.pumpAndSettle();
    expect(c.read(profilesProvider).single.equippedAccessory, 'grad-cap');
    await t.tap(find.byKey(const Key('accessory-beret'))); // the Colors chest is not opened: locked
    await t.pumpAndSettle();
    expect(c.read(profilesProvider).single.equippedAccessory, 'grad-cap');
    await t.tap(find.byKey(const Key('accessory-grad-cap'))); // tap again takes it off
    await t.pumpAndSettle();
    expect(c.read(profilesProvider).single.equippedAccessory, isNull);
  });

  testWidgets('the Sticker Book opens from the top bar; earned stickers are in color and say their word, the rest are empty frames', (t) async {
    final (audio, c) = await _open(t, meta: '{"schema":2,"children":{"c1":{"certificates":{},"celebrated":["letters"],"chests":["letters"]}}}');
    await t.tap(find.byKey(const Key('open-stickers')));
    await t.pumpAndSettle();
    expect(_where(c), '/stickers');
    expect(find.text('Sticker Book'), findsOneWidget);
    expect(find.byKey(const Key('sticker-page-letters')), findsOneWidget);
    final total = c.read(chestInventoryProvider).allStickers.length;
    expect(find.text('4 of $total'), findsOneWidget);
    audio.played.clear();
    await t.tap(find.byKey(const Key('sticker-letters/cat')));
    await t.pump();
    expect(audio.played.single, startsWith('asset:audio/little_learners/letter_c/'));

    await t.scrollUntilVisible(find.byKey(const Key('sticker-page-colors')), 300, scrollable: find.byType(Scrollable).first);
    audio.played.clear();
    await t.tap(find.byKey(const Key('sticker-colors/sun')), warnIfMissed: false); // not earned: silent
    await t.pump();
    expect(audio.played, isEmpty);
    expect(find.descendant(of: find.byKey(const Key('sticker-colors/sun')), matching: find.byIcon(Icons.help_outline_rounded)), findsOneWidget);
    await t.tap(find.byKey(const Key('stickers-back')));
    await t.pumpAndSettle();
    expect(_where(c), '/map');
  });

  testWidgets('the Sticker Book fetches the pack of a unit whose chest was opened on another phone, so its stickers get their pictures', (t) async {
    final fetcher = _AskedFetcher();
    final shared = await mockPrefs();
    final packs = PackRepository(baseUrl: 'http://test', track: 'little-learners', prefs: shared, fetcher: fetcher, root: () async => Directory.systemTemp);
    final (_, c) = await _open(t, packs: packs, meta: '{"schema":2,"children":{"c1":{"certificates":{},"celebrated":["letters"],"chests":["letters","numbers"]}}}');
    c.read(routerProvider).push('/stickers');
    await t.pumpAndSettle();
    expect(fetcher.asked, contains('http://test/packs/little_learners/index.json')); // it asked for the Numbers pack (the only opened chest of a pack unit)
    expect(fetcher.asked.where((u) => u.contains('/animals/')), isEmpty); // not for units whose chest is closed
  });

  testWidgets('a chest that is not ready yet does not open (Dandoona says what to do first)', (t) async {
    final (_, c) = await _open(t);
    c.read(unitMetaProvider);
    await Scrollable.ensureVisible(t.element(find.byKey(const Key('stop-chest-colors'))), alignment: 0.5);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('stop-chest-colors')));
    await t.pump(const Duration(milliseconds: 300));
    expect(_where(c), '/map');
    await t.pumpAndSettle();
    await t.pump(const Duration(seconds: 3));
  });
}

/// A pack server that is not there: it only remembers what was asked.
class _AskedFetcher implements PackFetcher {
  final asked = <String>[];

  @override
  Future<List<int>> get(Uri url) async {
    asked.add(url.toString());
    throw const PackException('offline', offline: true);
  }
}
