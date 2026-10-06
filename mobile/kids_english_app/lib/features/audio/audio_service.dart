import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Plays bundled lesson audio (and, in record-and-listen, the child's own recording).
/// Behind an interface so tests use a fake. A playback failure must never block an activity.
abstract class AudioService {
  /// Plays an asset (path relative to `assets/`, as in little_learners.json) and completes when it ends.
  Future<void> playAsset(String assetPath);

  /// Plays a local file and completes when it ends.
  Future<void> playFile(String path);

  Future<void> stop();
  void dispose();
}

class AudioplayersService implements AudioService {
  final AudioPlayer _player = AudioPlayer();
  Completer<void>? _cut; // completes when the current clip is replaced or stopped, so its caller stops waiting

  @override
  Future<void> playAsset(String assetPath) => _play(AssetSource(assetPath));

  @override
  Future<void> playFile(String path) => _play(DeviceFileSource(path));

  Future<void> _play(Source source) async {
    try {
      _cut?.complete();
      final cut = _cut = Completer<void>();
      await _player.stop();
      final done = firstEventOrTimeout(_player.onPlayerComplete, const Duration(seconds: 30));
      await _player.play(source);
      await Future.any([done, cut.future]);
    } on Object catch (e) {
      // Missing codec, no audio device, web autoplay rules...: the activity continues silently.
      debugPrint('audio: could not play $source: $e');
    }
  }

  @override
  Future<void> stop() async {
    _cut?.complete();
    try {
      await _player.stop();
    } on Object {
      // ignore
    }
  }

  @override
  void dispose() => unawaited(_player.dispose());
}

final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioplayersService();
  ref.onDispose(service.dispose);
  return service;
});

/// Records the child's voice to a temporary file for an immediate play-back. No scoring and no recognition:
/// the file never leaves the device and is deleted as soon as it has been played (see record_listen_screen.dart).
abstract class RecorderService {
  /// Asks for the microphone permission (the OS shows its own prompt). False when denied or unavailable.
  Future<bool> requestPermission();
  Future<void> start();

  /// Stops and returns the file path, or null if nothing was recorded.
  Future<String?> stop();
  Future<void> delete(String path);
  void dispose();
}

class RecordPackageService implements RecorderService {
  final AudioRecorder _recorder = AudioRecorder();

  @override
  Future<bool> requestPermission() async {
    try {
      return await _recorder.hasPermission();
    } on Object {
      return false;
    }
  }

  @override
  Future<void> start() async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}${Platform.pathSeparator}kids_voice_${DateTime.now().microsecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1, sampleRate: 22050),
      path: path,
    );
  }

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> delete(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on Object {
      // best effort; it is a temp file
    }
  }

  @override
  void dispose() => unawaited(_recorder.dispose());
}

final recorderServiceProvider = Provider<RecorderService>((ref) {
  final service = RecordPackageService();
  ref.onDispose(service.dispose);
  return service;
});

/// Completes when [events] emits once, or after [timeout] (a clip that never reports its end must not hang the caller).
/// Written without `Stream.first.timeout(onTimeout: ...)`: the stream's element type is not `void`, so a
/// `() {}` fallback throws a TypeError at run time, which the player's catch-all hid (no clip was ever played).
Future<void> firstEventOrTimeout(Stream<Object?> events, Duration timeout) {
  final completer = Completer<void>();
  late final StreamSubscription<Object?> sub;
  sub = events.listen((_) {
    if (!completer.isCompleted) completer.complete();
  });
  return completer.future.timeout(timeout, onTimeout: () {}).whenComplete(() => unawaited(sub.cancel()));
}
