import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/app.dart';
import 'package:kids_english_app/features/audio/audio_service.dart';
import 'package:kids_english_app/features/content/content_models.dart';
import 'package:kids_english_app/features/content/packs.dart';
import 'package:kids_english_app/features/progress/progress.dart';
import 'package:kids_english_app/features/units/unit_logic.dart';

import 'helpers.dart';

/// Serves a fixed set of URLs; anything else is "no connection".
class FakeFetcher implements PackFetcher {
  FakeFetcher(this.files);
  final Map<String, List<int>> files;
  final List<String> asked = [];

  @override
  Future<List<int>> get(Uri url) async {
    asked.add(url.toString());
    final f = files[url.toString()];
    if (f == null) throw const PackException('offline', offline: true);
    return f;
  }
}

const _base = 'http://test';
String _sha(List<int> b) => sha256.convert(b).toString();

/// A one-lesson Numbers pack as the generator writes it, served at the URLs the app asks for.
({Map<String, List<int>> files, PackRef ref}) _numbersPack({int version = 1, String audio = 'ONE'}) {
  final mp3 = utf8.encode(audio);
  final manifest = utf8.encode(jsonEncode({
    'schemaVersion': 1,
    'track': 'little-learners',
    'unit': 'numbers',
    'version': version,
    'contentHash': 'h$version',
    'lessons': [
      {
        'id': 'number-1',
        'order': 1,
        'level': 'pre-a1',
        'audio': {'intro': 'audio/little_learners/number_1/intro.mp3', 'praise': ['audio/little_learners/number_1/intro.mp3']},
        'words': [
          {'word': 'one', 'audio': 'audio/little_learners/number_1/intro.mp3', 'image': 'images/little_learners/number_1/one.svg'},
        ],
        'activities': ['listen-and-tap'],
      },
    ],
    'files': [
      {'path': 'audio/little_learners/number_1/intro.mp3', 'sha256': _sha(mp3), 'bytes': mp3.length},
    ],
  }));
  return (
    files: {
      '$_base/packs/little_learners/numbers/v$version/manifest.json': manifest,
      '$_base/packs/little_learners/numbers/v$version/audio/little_learners/number_1/intro.mp3': mp3,
    },
    ref: PackRef(version: version, sha256: _sha(manifest), bytes: 100, manifest: 'numbers/v$version/manifest.json', lessonIds: const ['number-1']),
  );
}

const _numbers = CourseUnit(id: 'numbers', order: 3, title: {'en': 'Numbers 1-10', 'ar': 'الأرقام'}, icon: 'numbers', color: 'blue', lessons: []);

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('packs'));
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<PackRepository> repo(FakeFetcher f) async =>
      PackRepository(baseUrl: '$_base/', track: 'little-learners', prefs: await mockPrefs(), fetcher: f, root: () async => tmp);

  group('repository', () {
    test('downloads a pack, checks every file, keeps it, and reads its lessons from the device', () async {
      final p = _numbersPack();
      final r = await repo(FakeFetcher(p.files));
      final installed = await r.install('numbers', p.ref);
      expect(installed.version, 1);
      expect(r.installed().keys, ['numbers']);

      final unit = r.load(_numbers.withLessons(const []))!;
      expect(unit.lessons.single.id, 'number-1');
      final intro = unit.lessons.single.audio.intro;
      expect(isPackFile(intro), isTrue); // an absolute path into the pack folder
      expect(File(intro).readAsStringSync(), 'ONE');
      expect(unit.lessons.single.words.single.word, 'one'); // plain words are not paths
    });

    test('a file that does not match its checksum is refused and nothing is kept', () async {
      final p = _numbersPack();
      final files = {...p.files, '$_base/packs/little_learners/numbers/v1/audio/little_learners/number_1/intro.mp3': utf8.encode('TAMPERED')};
      final r = await repo(FakeFetcher(files));
      await expectLater(r.install('numbers', p.ref), throwsA(isA<PackException>()));
      expect(r.installed(), isEmpty);
    });

    test('a newer version on the server replaces the old one without an app release', () async {
      final v1 = _numbersPack(), v2 = _numbersPack(version: 2, audio: 'ONE!');
      final index = utf8.encode(jsonEncode({
        'schemaVersion': 1,
        'track': 'little-learners',
        'packs': [
          {'unit': 'numbers', 'version': 2, 'sha256': v2.ref.sha256, 'bytes': 100, 'manifest': v2.ref.manifest, 'lessonIds': ['number-1']},
        ],
      }));
      final r = await repo(FakeFetcher({...v1.files, ...v2.files, '$_base/packs/little_learners/index.json': index}));
      await r.install('numbers', v1.ref);
      final newest = await r.latest('numbers', v1.ref); // the app only knows v1
      expect(newest.version, 2);
      await r.install('numbers', newest);
      expect(r.installed()['numbers']!.version, 2);
      expect(Directory('${tmp.path}/numbers/v1').existsSync(), isFalse); // the old copy is removed
      expect(File(r.load(_numbers)!.lessons.single.audio.intro).readAsStringSync(), 'ONE!');
    });

    test('without a connection the app keeps the version it knows', () async {
      final p = _numbersPack();
      final r = await repo(FakeFetcher(const {}));
      expect((await r.latest('numbers', p.ref)).version, 1);
      await expectLater(r.install('numbers', p.ref), throwsA(isA<PackException>().having((e) => e.offline, 'offline', isTrue)));
    });
  });

  test('a unit whose pack is not downloaded is not "soon", and progress made on another phone still finishes it', () {
    final p = _numbersPack();
    final unit = CourseUnit(id: 'numbers', order: 1, title: const {'en': 'Numbers'}, icon: 'numbers', color: 'blue', lessons: const [], pack: p.ref);
    expect(unit.comingSoon, isFalse);
    expect(unit.needsDownload, isTrue);
    final statuses = computeUnitStatuses([unit], (l) => l == 'number-1');
    expect(statuses.single.state, UnitState.done);
    expect(computeUnitStatuses([unit], (_) => false).single.state, UnitState.current);
  });

  group('on the map', () {
    final letters = [for (var i = 0; i < 26; i++) 'letter-${String.fromCharCode(97 + i)}'];
    final colors = ['color-red', 'color-blue', 'color-yellow', 'color-green', 'color-orange', 'color-purple', 'color-pink', 'color-brown', 'color-black', 'color-white'];

    Future<(FakeAudio, FakeFetcher, ProviderContainer)> open(WidgetTester t) async {
      final p = _numbersPack();
      final real = realContent();
      final content = real.withUnits([
        for (final u in real.units)
          if (u.id == 'numbers') CourseUnit(id: u.id, order: u.order, title: u.title, icon: u.icon, color: u.color, audio: u.audio, lessons: const [], pack: p.ref) else u,
      ]);
      final fetcher = FakeFetcher(const {}); // no connection
      final audio = FakeAudio();
      final prefs = {
        'settings.v1': '{"languageCode":"en","sessionMinutes":15,"unlockAll":false,"onboarded":true}',
        'children.v1': '[{"id":"c1","name":"Omar","avatarKey":"star","birthYear":2022,"track":"little-learners","createdAt":"2026-01-01T00:00:00Z"}]',
        'progress.v1': jsonEncode([
          for (final l in [...letters, ...colors])
            ProgressRecord(clientRecordId: 'r-$l', childId: 'c1', lessonId: l, activity: 'listen-and-tap', stars: 3, attempts: 3, timeSpentSeconds: 10, completedAt: DateTime.utc(2026, 9, 1)).toJson(),
        ]),
      };
      final overrides = await testOverrides(content: content, prefs: prefs);
      final shared = await mockPrefs(prefs);
      final container = ProviderContainer(overrides: [
        ...overrides,
        audioServiceProvider.overrideWithValue(audio),
        recorderServiceProvider.overrideWithValue(FakeRecorder()),
        packRepositoryProvider.overrideWithValue(PackRepository(baseUrl: _base, track: 'little-learners', prefs: shared, fetcher: fetcher, root: () async => tmp)),
      ]);
      addTearDown(container.dispose);
      await t.pumpWidget(UncontrolledProviderScope(container: container, child: const KidsEnglishApp()));
      await t.pumpAndSettle();
      return (audio, fetcher, container);
    }

    testWidgets('the next unit\'s pack is fetched in the background; offline, the child sees "Almost ready!" and no error', (t) async {
      final (audio, fetcher, container) = await open(t);
      expect(fetcher.asked, contains('$_base/packs/little_learners/numbers/v1/manifest.json')); // Numbers is the current unit
      expect(container.read(packDownloadsProvider)['numbers'], PackDownload.offline);
      expect(find.byKey(const Key('unit-waiting-numbers')), findsOneWidget);

      await t.tap(find.byKey(const Key('unit-play-numbers')));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Almost ready!'), findsOneWidget);
      expect(find.byKey(const Key('letter-map')), findsNothing); // stays on the map
      await t.pumpAndSettle();
      await t.pump(const Duration(seconds: 3));
    });
  });
}
