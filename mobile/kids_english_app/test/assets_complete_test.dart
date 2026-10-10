import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Fails when any lesson, instruction, sticker or story of either track points at an audio or picture file that does not exist:
/// in the app (bundled units, the units' own lines, the app's lines, the phonemes) or in the downloadable packs (every file a pack lists
/// is there, and every file its lessons use is listed).
const _ext = ['.mp3', '.wav', '.webp', '.svg', '.png', '.jpg'];

Set<String> _paths(Object? j) {
  final out = <String>{};
  void walk(Object? v) {
    if (v is String) {
      final low = v.toLowerCase();
      if (v.contains('/') && _ext.any(low.endsWith)) out.add(v);
    } else if (v is List) {
      v.forEach(walk);
    } else if (v is Map) {
      v.values.forEach(walk);
    }
  }

  walk(j);
  return out;
}

Map<String, dynamic> _json(String path) => jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

class _Pack {
  _Pack(this.unit, this.dir, this.manifest);
  final String unit;
  final Directory dir;
  final Map<String, dynamic> manifest;
  Set<String> get listed => {for (final f in manifest['files'] as List<dynamic>) (f as Map<String, dynamic>)['path'] as String};
}

List<_Pack> _packs(String folder) {
  final root = '../../packs/$folder';
  final index = _json('$root/index.json');
  return [
    for (final p in (index['packs'] as List<dynamic>).cast<Map<String, dynamic>>())
      () {
        final unit = p['unit'] as String;
        final dir = Directory('$root/${unit.replaceAll('-', '_')}/v${p['version']}');
        return _Pack(unit, dir, _json('${dir.path}/manifest.json'));
      }(),
  ];
}

void main() {
  for (final (track, catalogFile, packFolder) in const [('Little Learners', 'assets/content/little_learners.json', 'little_learners'), ('Explorers', 'assets/content/explorers.json', 'explorers')]) {
    group(track, () {
      final catalog = _json(catalogFile);
      final packs = _packs(packFolder);
      final inPacks = {for (final p in packs) ...p.listed};

      test('every file the catalog names is in the app, or in a pack that lists it', () {
        expect(_paths(catalog).length, greaterThan(50), reason: 'the walker found the catalog files');
        final missing = <String>[];
        for (final p in _paths(catalog)) {
          if (File('assets/$p').existsSync()) continue;
          if (inPacks.contains(p)) continue;
          missing.add(p);
        }
        expect(missing, isEmpty, reason: 'named by the $track catalog but nowhere to be found:\n${missing.take(20).join('\n')}');
      });

      test('every file a pack lists exists in its folder, and every file its lessons use is listed (or bundled)', () {
        final problems = <String>[];
        for (final p in packs) {
          for (final f in p.listed) {
            if (!File('${p.dir.path}/$f').existsSync()) problems.add('${p.unit}: listed but missing: $f');
          }
          for (final f in _paths(p.manifest['lessons'])) {
            if (!p.listed.contains(f) && !File('assets/$f').existsSync()) problems.add('${p.unit}: used by a lesson but not listed: $f');
          }
        }
        expect(problems, isEmpty, reason: problems.take(20).join('\n'));
      });

      test('the bundled lessons, instructions, stickers and stories: every unit of the catalog is a bundled one with files, or a pack unit that exists', () {
        final units = (catalog['units'] as List<dynamic>).cast<Map<String, dynamic>>();
        final packUnits = packs.map((p) => p.unit).toSet();
        for (final u in units) {
          final lessons = (u['lessons'] as List<dynamic>?) ?? const [];
          final pack = u['pack'];
          if (lessons.isEmpty && pack == null) continue; // "soon": nothing to play yet
          if (pack != null) {
            expect(packUnits, contains(u['id']), reason: '${u['id']} is a pack unit with no pack in packs/$packFolder');
          } else {
            for (final f in _paths(lessons)) {
              expect(File('assets/$f').existsSync() || inPacks.contains(f), isTrue, reason: '${u['id']}: $f');
            }
          }
        }
      });
    });
  }

  test('the Explorers phoneme table points at real clips (every one is a listening item for the owner)', () {
    final phonemes = _json('assets/content/explorers.json')['phonemes'];
    expect(phonemes, isNotNull);
    final files = _paths(phonemes);
    expect(files.length, greaterThanOrEqualTo(33));
    for (final f in files) {
      expect(File('assets/$f').existsSync(), isTrue, reason: f);
    }
  });
}
