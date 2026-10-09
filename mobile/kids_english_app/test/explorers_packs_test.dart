import 'dart:convert';
import 'dart:io';


import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/features/content/content_models.dart';
import 'package:kids_english_app/features/content/content_repository.dart';
import 'package:kids_english_app/features/content/packs.dart';
import 'package:kids_english_app/features/profiles/child_profile.dart';

import 'helpers.dart';

/// The bundled JSON files, read from the project folder (the real Explorers catalog provider is under test).
class _FileBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData.view(Uint8List.fromList(await File(key).readAsBytes()).buffer);
}

class _Fetcher implements PackFetcher {
  _Fetcher(this.files);
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

String _sha(List<int> b) => sha256.convert(b).toString();

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('explorers_packs'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('an Explorers pack is downloaded from /packs/explorers (not from the Little Learners folder), and its lessons join the Explorers catalog', () async {
    final real = realExplorersContent();
    final unit = real.units.firstWhere((u) => u.pack != null); // the first Explorers pack unit
    final mp3 = utf8.encode('AUDIO');
    final dir = unit.id.replaceAll('-', '_');
    final manifest = utf8.encode(jsonEncode({
      'schemaVersion': 1,
      'track': 'explorers',
      'unit': unit.id,
      'version': unit.pack!.version + 1,
      'lessons': [
        {
          'id': '${unit.id}-1',
          'order': 1,
          'level': 'a1',
          'audio': {'intro': 'audio/explorers/x/intro.mp3', 'praise': ['audio/explorers/x/intro.mp3']},
          'words': [
            {'word': 'cat', 'audio': 'audio/explorers/x/intro.mp3', 'image': 'images/explorers/x/cat.svg'},
          ],
          'activities': ['listen-and-tap'],
        },
      ],
      'files': [
        {'path': 'audio/explorers/x/intro.mp3', 'sha256': _sha(mp3), 'bytes': mp3.length},
      ],
    }));
    final v = unit.pack!.version + 1; // newer than the bundled one, so the server's index is what is installed
    final ref = PackRef(version: v, sha256: _sha(manifest), bytes: 100, manifest: '${unit.id}/v$v/manifest.json', lessonIds: const []);
    final fetcher = _Fetcher({
      'http://test/packs/explorers/index.json': utf8.encode(jsonEncode({'packs': [{'unit': unit.id, 'version': v, 'sha256': ref.sha256, 'bytes': 100, 'manifest': ref.manifest}]})),
      'http://test/packs/explorers/${unit.id}/v$v/manifest.json': manifest,
      'http://test/packs/explorers/${unit.id}/v$v/audio/explorers/x/intro.mp3': mp3,
    });
    final ll = PackRepository(baseUrl: 'http://test/', track: 'little-learners', prefs: await mockPrefs(), fetcher: fetcher, root: () async => tmp);
    final overrides = await testOverrides(content: realContent(), prefs: {
      'children.v1': '[{"id":"e1","name":"Lina","avatarKey":"star","birthYear":2019,"birthMonth":2,"track":"explorers","createdAt":"2026-01-01T00:00:00Z"}]',
    });
    final c = ProviderContainer(overrides: [...overrides, assetBundleProvider.overrideWithValue(_FileBundle()), packRepositoryProvider.overrideWithValue(ll)]);
    addTearDown(c.dispose);
    c.read(activeChildIdProvider.notifier).select('e1');
    await c.read(explorersContentProvider.future);
    expect(c.read(explorersCatalogUnitIdsProvider), contains(unit.id));

    await c.read(packDownloadsProvider.notifier).ensure(unit);

    expect(fetcher.asked, contains('http://test/packs/explorers/index.json'));
    expect(fetcher.asked.where((u) => u.contains('/packs/little_learners/')), isEmpty, reason: 'nothing is asked from the Little Learners folder');
    expect(c.read(packDownloadsProvider)[unit.id], isNull); // no failure
    final loaded = (await c.read(explorersContentProvider.future)).unitById(unit.id)!;
    expect(loaded.lessons.map((l) => l.id), ['${unit.id}-1']);
    expect(File('${tmp.path}/$dir/v$v/manifest.json').existsSync(), isTrue);
  });

  test('a Little Learners unit still comes from the Little Learners folder', () async {
    final unit = realContent().units.firstWhere((u) => u.pack != null);
    final fetcher = _Fetcher({});
    final ll = PackRepository(baseUrl: 'http://test/', track: 'little-learners', prefs: await mockPrefs(), fetcher: fetcher, root: () async => tmp);
    final overrides = await testOverrides(content: realContent());
    final c = ProviderContainer(overrides: [...overrides, assetBundleProvider.overrideWithValue(_FileBundle()), packRepositoryProvider.overrideWithValue(ll)]);
    addTearDown(c.dispose);
    await c.read(explorersContentProvider.future);
    await c.read(packDownloadsProvider.notifier).ensure(unit);
    expect(fetcher.asked.first, 'http://test/packs/little_learners/index.json');
    expect(fetcher.asked.every((u) => u.contains('/packs/little_learners/')), isTrue);
  });
}
