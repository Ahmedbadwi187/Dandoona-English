import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/core/strings.dart';
import 'package:kids_english_app/features/content/content_models.dart';
import 'package:kids_english_app/features/gate/parental_gate.dart';
import 'package:kids_english_app/features/profiles/child_profile.dart';
import 'package:kids_english_app/features/progress/progress.dart';
import 'package:kids_english_app/features/session/session.dart';
import 'package:kids_english_app/features/settings/settings.dart';
import 'package:kids_english_app/router.dart';

import 'helpers.dart';

void main() {
  group('strings', () {
    test('Arabic and English define exactly the same keys', () {
      expect(Strings.arabicKeys.toSet(), Strings.englishKeys.toSet());
    });

    test('no value is empty and Arabic differs from English', () {
      for (final key in Strings.englishKeys) {
        expect(Strings.ar(key), isNotEmpty, reason: key);
        expect(Strings.en(key), isNotEmpty, reason: key);
      }
      expect(Strings.ar('save'), isNot(Strings.en('save')));
    });

    test('Arabic is RTL, English is LTR', () {
      expect(Strings.ar.isRtl, isTrue);
      expect(Strings.en.isRtl, isFalse);
    });
  });

  group('real bundled content (written by tools/AssetGenerator)', () {
    late Map<String, dynamic> json;
    setUpAll(() {
      json = jsonDecode(File('assets/content/little_learners.json').readAsStringSync()) as Map<String, dynamic>;
    });

    test('parses the Letters unit with 26 lessons A-Z in order', () {
      final content = TrackContent.fromJson(json);
      final letters = content.unitById('letters')!.lessons;
      expect(letters, hasLength(26));
      expect(letters.map((l) => l.letter).join(), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ');
      expect(content.lessonById('letter-q')?.words, isNotEmpty);
    });

    test('every referenced audio and image file exists, and every lesson has the four activities', () {
      final content = TrackContent.fromJson(json);
      bool exists(String rel) => File('assets/$rel').existsSync();
      for (final l in content.unitById('letters')!.lessons) {
        expect(exists(l.audio.intro), isTrue, reason: l.audio.intro);
        for (final p in l.audio.praise) {
          expect(exists(p), isTrue, reason: p);
        }
        for (final w in l.words) {
          expect(exists(w.audio), isTrue, reason: w.audio);
          expect(exists(w.image), isTrue, reason: w.image);
          expect(w.image.endsWith('.svg') || w.image.endsWith('.webp'), isTrue);
        }
        expect(l.activities, containsAll(['trace', 'listen-and-tap', 'record-and-listen', 'match-picture']));
      }
      expect(content.mascot, isNotNull);
      expect(exists(content.mascot!), isTrue);
    });

    test('an unknown schema version is rejected', () {
      expect(() => TrackContent.fromJson({...json, 'schemaVersion': 99}), throwsFormatException);
    });
  });

  group('parental gate challenge', () {
    test('answer is a x b, options are 4 distinct positive numbers including the answer', () {
      for (var seed = 0; seed < 200; seed++) {
        final c = GateChallenge.random(Random(seed));
        expect(c.answer, c.a * c.b);
        expect(c.options.toSet(), hasLength(4));
        expect(c.options, contains(c.answer));
        expect(c.options.every((o) => o > 0), isTrue);
        expect(c.isCorrect(c.answer), isTrue);
        expect(c.isCorrect(c.answer + 1), isFalse);
      }
    });

    test('the product is beyond what a 3-5 year old can do', () {
      for (var seed = 0; seed < 100; seed++) {
        expect(GateChallenge.random(Random(seed)).answer, greaterThanOrEqualTo(18));
      }
    });
  });

  group('child validation', () {
    final now = DateTime(2026, 6, 1);
    test('name', () {
      expect(ChildValidation.name('Omar'), isNull);
      expect(ChildValidation.name('  '), 'errName');
      expect(ChildValidation.name(null), 'errName');
      expect(ChildValidation.name('x' * 31), 'errName');
    });
    test('birth year gives age 2-13', () {
      expect(ChildValidation.birthYear(2022, now), isNull);
      expect(ChildValidation.birthYear(2013, now), isNull);
      expect(ChildValidation.birthYear(2026, now), 'errBirthYear');
      expect(ChildValidation.birthYear(1990, now), 'errBirthYear');
      expect(ChildValidation.birthYear(null, now), 'errBirthYear');
    });
  });

  group('profiles + progress + settings (local storage)', () {
    test('profiles persist across a restart and delete removes progress too', () async {
      final overrides = await testOverrides();
      final c1 = containerWith(overrides);
      addTearDown(c1.dispose);
      final omar = await c1.read(profilesProvider.notifier).add(name: '  Omar ', avatarKey: 'star', birthYear: 2022);
      expect(omar.name, 'Omar');
      await c1.read(progressProvider.notifier).record(ProgressRecord(
            clientRecordId: 'r1', childId: omar.id, lessonId: 'letter-a', activity: 'trace',
            stars: 2, attempts: 1, timeSpentSeconds: 30, completedAt: DateTime(2026, 6, 1)));

      // same SharedPreferences instance, brand-new container = "app restarted"
      final c2 = containerWith(overrides);
      addTearDown(c2.dispose);
      expect(c2.read(profilesProvider).single.name, 'Omar');
      expect(c2.read(progressProvider), hasLength(1));

      await c2.read(profilesProvider.notifier).remove(omar.id);
      expect(c2.read(profilesProvider), isEmpty);
      expect(c2.read(progressProvider), isEmpty);
    });

    test('update changes only the given fields', () async {
      final c = containerWith(await testOverrides());
      addTearDown(c.dispose);
      final p = await c.read(profilesProvider.notifier).add(name: 'Sara', avatarKey: 'sun', birthYear: 2021);
      await c.read(profilesProvider.notifier).update(p.id, name: 'Sarah');
      final updated = c.read(profilesProvider).single;
      expect(updated.name, 'Sarah');
      expect(updated.avatarKey, 'sun');
      expect(updated.birthYear, 2021);
      expect(updated.track, 'little-learners');
    });

    test('corrupted stored data does not crash; bad entries are skipped', () async {
      final c = containerWith(await testOverrides(prefs: {
        'children.v1': '[{"id":"a","name":"Ok","avatarKey":"star","birthYear":2022,"createdAt":"2026-01-01T00:00:00Z"}, {"bad":1}]',
        'progress.v1': 'not json at all',
        'settings.v1': '{"sessionMinutes": 9999, "languageCode": "fr"}',
      }));
      addTearDown(c.dispose);
      expect(c.read(profilesProvider).map((p) => p.name), ['Ok']);
      expect(c.read(progressProvider), isEmpty);
      final s = c.read(settingsProvider);
      expect(s.sessionMinutes, AppSettings.maxSessionMinutes); // clamped
      expect(s.languageCode, 'ar'); // unknown language falls back to Arabic
    });

    test('progress: best stars per activity are summed and records are idempotent', () async {
      final c = containerWith(await testOverrides());
      addTearDown(c.dispose);
      final n = c.read(progressProvider.notifier);
      ProgressRecord rec(String id, String activity, int stars) => ProgressRecord(
          clientRecordId: id, childId: 'k', lessonId: 'letter-a', activity: activity,
          stars: stars, attempts: 1, timeSpentSeconds: 10, completedAt: DateTime(2026, 6, 1));
      await n.record(rec('1', 'trace', 1));
      await n.record(rec('2', 'trace', 3)); // better attempt replaces, not adds
      await n.record(rec('3', 'listen-and-tap', 2));
      await n.record(rec('3', 'listen-and-tap', 2)); // same client id: ignored
      expect(n.starsFor('k', 'letter-a'), 5);
      expect(n.starsFor('k', 'letter-b'), 0);
      expect(n.starsFor('other', 'letter-a'), 0);
      expect(c.read(progressProvider), hasLength(3));
    });

    test('settings: defaults, 15-minute session, clamped updates, onboarding flag', () async {
      final c = containerWith(await testOverrides());
      addTearDown(c.dispose);
      final s = c.read(settingsProvider);
      expect(s.languageCode, 'ar');
      expect(s.sessionMinutes, 15);
      expect(s.onboarded, isFalse);
      await c.read(settingsProvider.notifier).setSessionMinutes(1);
      expect(c.read(settingsProvider).sessionMinutes, AppSettings.minSessionMinutes);
      await c.read(settingsProvider.notifier).completeOnboarding();
      expect(c.read(settingsProvider).onboarded, isTrue);
    });
  });

  group('letter map unlock rule', () {
    test('first is open; next opens after progress; unlock-all opens everything', () {
      expect(isLessonUnlocked(index: 0, unlockAll: false, previousHasProgress: false), isTrue);
      expect(isLessonUnlocked(index: 1, unlockAll: false, previousHasProgress: false), isFalse);
      expect(isLessonUnlocked(index: 1, unlockAll: false, previousHasProgress: true), isTrue);
      expect(isLessonUnlocked(index: 25, unlockAll: true, previousHasProgress: false), isTrue);
    });
  });

  group('router guards', () {
    String? guard(String loc, {bool onboarded = true, bool profiles = true, bool parent = false, bool active = false}) =>
        guardRoute(location: loc, onboarded: onboarded, hasProfiles: profiles, parentUnlocked: parent, hasActiveChild: active);

    test('root goes to onboarding until a profile exists, then to the picker', () {
      expect(guard('/', onboarded: false, profiles: false), '/onboarding');
      expect(guard('/', onboarded: true, profiles: false), '/onboarding');
      expect(guard('/'), '/who');
    });

    test('the parent area is unreachable without passing the gate', () {
      for (final path in ['/parent', '/parent/settings', '/parent/children', '/parent/children/new', '/parent/children/abc']) {
        expect(guard(path), '/who', reason: path);
        expect(guard(path, parent: true), isNull, reason: path);
      }
    });

    test('map and lessons need a selected child', () {
      expect(guard('/map'), '/who');
      expect(guard('/lesson/letter-a'), '/who');
      expect(guard('/map', active: true), isNull);
      expect(guard('/lesson/letter-a', active: true), isNull);
    });

    test('picker without profiles goes back to onboarding', () {
      expect(guard('/who', profiles: false), '/onboarding');
    });
  });

  group('session timer', () {
    test('over only after the parent limit (default 15 min)', () async {
      final c = containerWith(await testOverrides());
      addTearDown(c.dispose);
      expect(c.read(sessionOverProvider), isFalse);
      c.read(sessionSecondsProvider.notifier).tick(15 * 60 - 1);
      expect(c.read(sessionOverProvider), isFalse);
      c.read(sessionSecondsProvider.notifier).tick();
      expect(c.read(sessionOverProvider), isTrue);
      c.read(sessionSecondsProvider.notifier).reset();
      expect(c.read(sessionOverProvider), isFalse);
    });

    test('a shorter limit from settings applies', () async {
      final c = containerWith(await testOverrides());
      addTearDown(c.dispose);
      await c.read(settingsProvider.notifier).setSessionMinutes(5);
      c.read(sessionSecondsProvider.notifier).tick(300);
      expect(c.read(sessionOverProvider), isTrue);
    });
  });
}
