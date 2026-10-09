import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/storage.dart';
import '../sync/sync_controller.dart' show defaultApiBaseUrl;
import 'content_models.dart';
import 'content_repository.dart' show explorersCatalogUnitIdsProvider;

/// Downloadable content packs: every unit after Letters and Colors. The app's catalog names each pack (version, checksum,
/// lesson ids); the pack itself (lesson JSON, audio, pictures) comes from our API at /packs, is checked file by file
/// against its checksums, and is kept on the device, so it plays offline afterwards. A newer version on the server
/// replaces it without an app release. Nothing about the child is sent: these are plain file downloads.

String _snake(String s) => s.replaceAll('-', '_');

class PackException implements Exception {
  const PackException(this.message, {this.offline = false});
  final String message;

  /// No connection (as opposed to a broken pack): the parent sees "needs internet", the child sees nothing alarming.
  final bool offline;
  @override
  String toString() => 'PackException: $message';
}

/// Fetches pack files. The real one uses HTTP; tests use a map of URLs.
abstract class PackFetcher {
  Future<List<int>> get(Uri url);
}

class HttpPackFetcher implements PackFetcher {
  HttpPackFetcher([http.Client? client]) : _client = client ?? http.Client();
  final http.Client _client;

  @override
  Future<List<int>> get(Uri url) async {
    try {
      final res = await _client.get(url).timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) throw PackException('${res.statusCode} for $url');
      return res.bodyBytes;
    } on SocketException catch (e) {
      throw PackException(e.message, offline: true);
    } on TimeoutException {
      throw const PackException('timed out', offline: true);
    } on http.ClientException catch (e) {
      throw PackException(e.message, offline: true);
    }
  }
}

/// A pack on this device: which version, and the folder its files are in.
class InstalledPack {
  const InstalledPack({required this.unit, required this.version, required this.dir});
  final String unit;
  final int version;
  final String dir;

  Map<String, dynamic> toJson() => {'version': version, 'dir': dir};
  factory InstalledPack.fromJson(String unit, Map<String, dynamic> json) =>
      InstalledPack(unit: unit, version: json['version'] as int, dir: json['dir'] as String);
}

class PackRepository {
  PackRepository({required this.baseUrl, required this.track, required this.prefs, required this.fetcher, required Future<Directory> Function() root})
      : _root = root;

  static const prefsKey = 'packs.v1';

  final String baseUrl;
  final String track;
  final SharedPreferences prefs;
  final PackFetcher fetcher;
  final Future<Directory> Function() _root;

  /// The same server, folder and storage for another track (Explorers packs live under /packs/explorers).
  PackRepository forTrack(String other) => PackRepository(baseUrl: baseUrl, track: other, prefs: prefs, fetcher: fetcher, root: _root);

  Uri _url(String rel) => Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}/packs/${_snake(track)}/$rel');

  Map<String, InstalledPack> installed() {
    final raw = prefs.readJson(prefsKey);
    if (raw is! Map<String, dynamic>) return const {};
    final result = <String, InstalledPack>{};
    raw.forEach((unit, v) {
      try {
        final p = InstalledPack.fromJson(unit, v as Map<String, dynamic>);
        if (File('${p.dir}/manifest.json').existsSync()) result[unit] = p; // a cleared cache reads as "not downloaded"
      } on Object {
        // unreadable entry: download again
      }
    });
    return result;
  }

  /// The newest version the server offers for [unit], or [bundled] when the server cannot be asked.
  Future<PackRef> latest(String unit, PackRef bundled) async {
    try {
      final index = jsonDecode(utf8.decode(await fetcher.get(_url('index.json')))) as Map<String, dynamic>;
      for (final e in (index['packs'] as List<dynamic>).cast<Map<String, dynamic>>()) {
        if (e['unit'] == unit) {
          final ref = PackRef.fromJson(e);
          return ref.version > bundled.version ? ref : bundled;
        }
      }
    } on Object {
      // offline or no index: the version the app knows is fine
    }
    return bundled;
  }

  /// Downloads and checks [ref] for [unit] unless that version (or a newer one) is already here.
  Future<InstalledPack> install(String unit, PackRef ref) async {
    final have = installed()[unit];
    if (have != null && have.version >= ref.version) return have;

    final manifestBytes = await fetcher.get(_url(ref.manifest));
    if (sha256.convert(manifestBytes).toString() != ref.sha256) throw PackException('manifest checksum mismatch for $unit v${ref.version}');
    final manifest = jsonDecode(utf8.decode(manifestBytes)) as Map<String, dynamic>;

    final root = await _root();
    final unitDir = Directory('${root.path}/${_snake(unit)}');
    final part = Directory('${unitDir.path}/v${ref.version}.part');
    if (part.existsSync()) part.deleteSync(recursive: true);
    part.createSync(recursive: true);
    final base = ref.manifest.substring(0, ref.manifest.lastIndexOf('/') + 1);
    for (final f in (manifest['files'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      final path = f['path'] as String;
      if (path.contains('..') || path.startsWith('/')) throw PackException('bad path in pack: $path');
      final bytes = await fetcher.get(_url('$base$path'));
      if (sha256.convert(bytes).toString() != f['sha256']) throw PackException('checksum mismatch: $path');
      final file = File('${part.path}/$path');
      file.parent.createSync(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
    }
    await File('${part.path}/manifest.json').writeAsBytes(manifestBytes, flush: true);

    final target = Directory('${unitDir.path}/v${ref.version}');
    if (target.existsSync()) target.deleteSync(recursive: true);
    part.renameSync(target.path);
    final pack = InstalledPack(unit: unit, version: ref.version, dir: target.path);
    final all = {for (final e in installed().entries) e.key: e.value.toJson(), unit: pack.toJson()};
    await prefs.writeJson(prefsKey, all);
    // older versions are no longer needed
    for (final d in unitDir.listSync().whereType<Directory>()) {
      if (d.absolute.uri != target.absolute.uri) d.deleteSync(recursive: true); // compared as URIs: Windows lists paths with other separators
    }
    return pack;
  }

  /// The unit with its lessons read from the installed pack; media paths become absolute file paths.
  CourseUnit? load(CourseUnit unit) {
    final pack = installed()[unit.id];
    if (pack == null) return null;
    final manifest = jsonDecode(File('${pack.dir}/manifest.json').readAsStringSync()) as Map<String, dynamic>;
    final lessons = withPackPaths(manifest['lessons'], pack.dir) as List<dynamic>;
    return unit.withLessons([for (final l in lessons) Lesson.fromJson(l as Map<String, dynamic>)]..sort((a, b) => a.order.compareTo(b.order)));
  }
}

/// Every media path in the lesson JSON (audio/..., images/...) becomes `<dir>/<path>`, which the picture and audio
/// widgets read from the file system instead of the app bundle.
Object? withPackPaths(Object? json, String dir) => switch (json) {
      final String s when (s.startsWith('audio/') || s.startsWith('images/')) => '$dir/$s',
      final List<dynamic> l => [for (final x in l) withPackPaths(x, dir)],
      final Map<String, dynamic> m => {for (final e in m.entries) e.key: withPackPaths(e.value, dir)},
      _ => json,
    };

/// Media that came from a pack (an absolute path) rather than from the app bundle.
bool isPackFile(String path) => path.startsWith('/') || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path); // an absolute path (a drive letter on Windows, where the tests run too)

/// The pack repository, or null when there is no server to download from (a release build without API_BASE_URL).
final packRepositoryProvider = Provider<PackRepository?>((ref) {
  final url = defaultApiBaseUrl;
  if (url.isEmpty) return null;
  return PackRepository(
    baseUrl: url,
    track: 'little-learners',
    prefs: ref.watch(sharedPreferencesProvider),
    fetcher: HttpPackFetcher(),
    root: () async => Directory('${(await getApplicationSupportDirectory()).path}/packs'),
  );
});

/// The Explorers packs come from the same server under /packs/explorers (null when there is no server).
final explorersPackRepositoryProvider = Provider<PackRepository?>((ref) => ref.watch(packRepositoryProvider)?.forTrack('explorers'));

enum PackDownload { downloading, offline, failed }

/// Downloads in progress or failed, per unit. [ensure] starts one in the background (once at a time per unit); when it
/// finishes, [installedPacksProvider] changes and the content reloads with the unit's lessons.
class PackDownloadsNotifier extends Notifier<Map<String, PackDownload>> {
  @override
  Map<String, PackDownload> build() => const {};

  final _refreshed = <String>{};

  /// Asks the server once per run whether a pack that is already here has a newer version; if so, it is downloaded quietly and
  /// replaces the old one (the child keeps playing the old lessons until then).
  Future<void> refresh(CourseUnit unit) async {
    if (!_refreshed.add(unit.id)) return;
    await ensure(unit);
  }

  Future<void> ensure(CourseUnit unit) async {
    // a unit of the Explorers catalog is downloaded from the Explorers folder, every other one from the Little Learners folder
    final explorersUnit = ref.read(explorersCatalogUnitIdsProvider).contains(unit.id);
    final repo = explorersUnit ? ref.read(explorersPackRepositoryProvider) : ref.read(packRepositoryProvider);
    final bundled = unit.pack;
    if (repo == null || bundled == null || state[unit.id] == PackDownload.downloading) return;
    final have = repo.installed()[unit.id];
    state = {...state, unit.id: PackDownload.downloading};
    try {
      final ref0 = await repo.latest(unit.id, bundled);
      if (have == null || have.version < ref0.version) await repo.install(unit.id, ref0);
      state = {...state}..remove(unit.id);
      ref.invalidate(installedPacksProvider);
    } on PackException catch (e) {
      state = {...state, unit.id: e.offline ? PackDownload.offline : PackDownload.failed};
    } on Object {
      state = {...state, unit.id: PackDownload.failed};
    }
  }
}

final packDownloadsProvider = NotifierProvider<PackDownloadsNotifier, Map<String, PackDownload>>(PackDownloadsNotifier.new);

/// The packs on this device (unit id -> version). Content reloads when it changes.
final installedPacksProvider = Provider<Map<String, int>>((ref) {
  final repo = ref.watch(packRepositoryProvider);
  return {for (final p in repo?.installed().values ?? const <InstalledPack>[]) p.unit: p.version};
});
