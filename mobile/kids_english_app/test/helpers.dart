import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' show Key, Scrollable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:kids_english_app/core/storage.dart';
import 'package:kids_english_app/features/audio/audio_service.dart';
import 'package:kids_english_app/features/activities/hand_demo.dart' show autoDemoEveryTimeProvider;
import 'package:kids_english_app/features/content/content_models.dart';
import 'package:kids_english_app/features/content/content_repository.dart';
import 'package:kids_english_app/features/reminders/reminder_service.dart';
import 'package:kids_english_app/features/skills/skills.dart';
import 'package:kids_english_app/features/sync/auto_sync.dart' show autoSyncEnabledProvider;
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
Future<List<Override>> testOverrides({Map<String, Object> prefs = const {}, TrackContent? content, FakeReminders? reminders, TrackContent? explorers, bool autoDemo = false, bool autoSync = false}) async {
  final p = await mockPrefs(prefs);
  final c = content ?? sampleContent();
  return [
    sharedPreferencesProvider.overrideWithValue(p),
    contentProvider.overrideWith((ref) async => c),
    if (explorers != null) explorersContentProvider.overrideWith((ref) async => explorers),
    reminderServiceProvider.overrideWithValue(reminders ?? FakeReminders()),
    autoSyncEnabledProvider.overrideWithValue(autoSync), // the automatic sync has its own tests; elsewhere nothing runs in the background
    // the rules of the skills list are read from the file at once (a bundle read in a widget test can stall pumpAndSettle)
    skillsConfigProvider.overrideWith((ref) async => SkillsConfig.fromJson(jsonDecode(File('assets/content/skills.json').readAsStringSync()) as Map<String, dynamic>)),
    autoDemoEveryTimeProvider.overrideWithValue(autoDemo), // most tests are not about the demo: there the first-time rule decides
  ];
}

ProviderContainer containerWith(List<Override> overrides) {
  final c = ProviderContainer(overrides: overrides);
  return c;
}

// ---- activity test doubles -------------------------------------------------------------------------------

/// Remembers what would have been scheduled instead of touching the notification plugin.
class FakeReminders implements ReminderService {
  FakeReminders({this.allow = true});
  final bool allow;
  int permissionAsked = 0;
  ({int hour, int minute, String title, String body})? scheduled;
  bool cancelled = false;

  @override
  Future<bool> requestPermission() async {
    permissionAsked++;
    return allow;
  }

  @override
  Future<void> schedule({required int hour, required int minute, required String title, required String body}) async => scheduled = (hour: hour, minute: minute, title: title, body: body);

  @override
  Future<void> cancel() async => cancelled = true;
}

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

/// The real exported Explorers catalog (its Letters unit points at the Little Learners files).
TrackContent realExplorersContent() =>
    TrackContent.fromJson(jsonDecode(File('assets/content/explorers.json').readAsStringSync()) as Map<String, dynamic>);

/// The old single-choice answers (0 none, 1 some letters, 2 all letters, 3 reads simple words) as the skill to tap.
String skillOfLevel(int level) => const ['none', 'some-letters', 'all-letters', 'reads-words'][level];

/// Taps one skill of the "What can your child already do?" list (scrolling to it first: the list is long).
Future<void> tapSkill(WidgetTester t, String id) async {
  await reveal(t, find.byKey(Key('skill-$id')));
  await t.pumpAndSettle();
  await t.tap(find.byKey(Key('skill-$id')));
  await t.pumpAndSettle();
}

/// Scrolls the first scrollable until [target] is built and on screen (long forms like Edit child build their rows lazily).
Future<void> reveal(WidgetTester t, Finder target) async {
  if (target.evaluate().isEmpty) {
    await t.scrollUntilVisible(target, 300, scrollable: find.byType(Scrollable).first);
  }
  await t.ensureVisible(target);
  await t.pumpAndSettle();
}
