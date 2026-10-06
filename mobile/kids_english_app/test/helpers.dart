import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:kids_english_app/core/storage.dart';
import 'package:kids_english_app/features/audio/audio_service.dart';
import 'package:kids_english_app/features/content/content_models.dart';
import 'package:kids_english_app/features/content/content_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 26 small lessons (A-Z) so map/flow tests do not depend on the real asset files.
TrackContent sampleContent({int count = 26}) {
  final lessons = <Map<String, dynamic>>[
    for (var i = 0; i < count; i++)
      {
        'id': 'letter-${String.fromCharCode(97 + i)}',
        'order': i + 1,
        'level': 'pre-a1',
        'letter': String.fromCharCode(65 + i),
        'phoneme': '/x/',
        'audio': {
          'intro': 'audio/x/intro.mp3',
          'praise': ['audio/x/praise_0.mp3'],
        },
        'words': [
          {'word': 'word${i + 1}', 'audio': 'audio/x/w.mp3', 'image': 'images/x/w.svg'},
        ],
        'activities': ['trace', 'listen-and-tap', 'record-and-listen', 'match-picture'],
      },
  ];
  return TrackContent.fromJson({'schemaVersion': 1, 'track': 'little-learners', 'lessons': lessons});
}

Future<SharedPreferences> mockPrefs([Map<String, Object> initial = const {}]) async {
  SharedPreferences.setMockInitialValues(initial);
  return SharedPreferences.getInstance();
}

/// Overrides every app dependency that touches the platform.
Future<List<Override>> testOverrides({Map<String, Object> prefs = const {}, TrackContent? content}) async {
  final p = await mockPrefs(prefs);
  final c = content ?? sampleContent();
  return [
    sharedPreferencesProvider.overrideWithValue(p),
    contentProvider.overrideWith((ref) async => c),
  ];
}

ProviderContainer containerWith(List<Override> overrides) {
  final c = ProviderContainer(overrides: overrides);
  return c;
}

// ---- activity test doubles -------------------------------------------------------------------------------

/// Records what would have been played instead of touching the audio plugin.
class FakeAudio implements AudioService {
  final List<String> played = [];
  @override
  Future<void> playAsset(String assetPath) async => played.add('asset:$assetPath');
  @override
  Future<void> playFile(String path) async => played.add('file:$path');
  @override
  Future<void> stop() async {}
  @override
  void dispose() {}
}

class FakeRecorder implements RecorderService {
  bool permission = true;
  bool failOnStart = false;
  int started = 0;
  final List<String> created = [];
  final List<String> deleted = [];
  @override
  Future<bool> requestPermission() async => permission;
  @override
  Future<void> start() async {
    if (failOnStart) throw StateError('no microphone');
    started++;
  }

  @override
  Future<String?> stop() async {
    final path = 'tmp/voice_${created.length}.m4a';
    created.add(path);
    return path;
  }

  @override
  Future<void> delete(String path) async => deleted.add(path);
  @override
  void dispose() {}
}

/// The real exported lessons (so image/audio paths exist in the test asset bundle).
TrackContent realContent() =>
    TrackContent.fromJson(jsonDecode(File('assets/content/little_learners.json').readAsStringSync()) as Map<String, dynamic>);
