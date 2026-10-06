import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/core/ids.dart';
import 'package:kids_english_app/features/activities/activity_screen.dart';
import 'package:kids_english_app/features/audio/audio_service.dart';
import 'package:kids_english_app/features/parent/settings_screen.dart';
import 'package:kids_english_app/features/parent/weekly_view.dart';
import 'package:kids_english_app/features/profiles/child_profile.dart';
import 'package:kids_english_app/features/progress/progress.dart';
import 'package:kids_english_app/features/progress/weekly_summary.dart';
import 'package:kids_english_app/features/rewards/accessories.dart';
import 'package:kids_english_app/features/rewards/wardrobe_screen.dart';
import 'package:kids_english_app/core/strings.dart';
import 'package:kids_english_app/features/sync/sync_api.dart';
import 'package:kids_english_app/features/sync/sync_controller.dart';
import 'package:kids_english_app/features/sync/sync_service.dart';
import 'package:kids_english_app/router.dart';

import 'helpers.dart';

ProgressRecord rec(String id, String child, String lesson, String activity, int stars, DateTime at, {int seconds = 60}) => ProgressRecord(
    clientRecordId: id, childId: child, lessonId: lesson, activity: activity, stars: stars, attempts: 1, timeSpentSeconds: seconds, completedAt: at);

ChildProfile kid(String id, [String name = 'Omar']) =>
    ChildProfile(id: id, name: name, avatarKey: 'star', birthYear: 2022, createdAt: DateTime(2026, 1, 1));

/// Scriptable server stand-in.
class FakeSyncApi implements SyncApi {
  final List<String> createdChildren = [];
  final Map<String, Set<String>> stored = {}; // server child id -> client record guids
  int refreshCalls = 0;
  int submitCalls = 0;
  bool failLogin = false;
  bool offline = false;
  int failSubmitAfter = -1; // fail on the Nth submit (0-based); -1 = never

  void _net() {
    if (offline) throw const SyncException(SyncErrorKind.network, 'offline');
  }

  @override
  Future<AuthTokens> register({required String email, required String password, required String displayName}) async {
    _net();
    return const AuthTokens(accessToken: 'access-0', refreshToken: 'refresh-0');
  }

  @override
  Future<AuthTokens> login({required String email, required String password}) async {
    _net();
    if (failLogin) throw const SyncException(SyncErrorKind.auth, 'bad credentials');
    return const AuthTokens(accessToken: 'access-0', refreshToken: 'refresh-0');
  }

  @override
  Future<AuthTokens> refresh(String refreshToken) async {
    _net();
    refreshCalls++;
    return AuthTokens(accessToken: 'access-$refreshCalls', refreshToken: 'refresh-$refreshCalls');
  }

  @override
  Future<String> createChild(String accessToken, {required String name, required String avatarKey, required int birthYear, required String track}) async {
    _net();
    final id = 'server-${createdChildren.length}';
    createdChildren.add(name);
    stored[id] = {};
    return id;
  }

  @override
  Future<SubmitResult> submitProgress(String accessToken, String serverChildId, List<Map<String, Object?>> items) async {
    _net();
    if (submitCalls++ == failSubmitAfter) throw const SyncException(SyncErrorKind.server, 'boom');
    var accepted = 0;
    for (final i in items) {
      if (stored[serverChildId]!.add(i['clientRecordId'] as String)) accepted++;
    }
    return SubmitResult(accepted: accepted, duplicates: items.length - accepted);
  }
}

void main() {
  group('ids', () {
    test('newUuid is a valid v4 UUID and never repeats', () {
      final ids = {for (var i = 0; i < 500; i++) newUuid()};
      expect(ids, hasLength(500));
      for (final id in ids.take(20)) {
        expect(isUuid(id), isTrue);
        expect(id[14], '4'); // version
        expect('89ab'.contains(id[19]), isTrue); // variant
      }
    });

    test('guidFor passes real UUIDs through and maps legacy ids deterministically', () {
      final u = newUuid();
      expect(guidFor(u), u);
      expect(guidFor(u.toUpperCase()), u);
      final legacy = guidFor('mf3k2j-1a2b3');
      expect(isUuid(legacy), isTrue);
      expect(guidFor('mf3k2j-1a2b3'), legacy);
      expect(guidFor('mf3k2j-1a2b4'), isNot(legacy));
    });
  });

  group('weekly summary', () {
    final monday = DateTime(2026, 10, 5); // a Monday
    test('mondayOf', () {
      expect(mondayOf(DateTime(2026, 10, 5)), monday);
      expect(mondayOf(DateTime(2026, 10, 7, 23, 59)), monday);
      expect(mondayOf(DateTime(2026, 10, 11)), monday); // Sunday belongs to the week that started Monday
      expect(mondayOf(DateTime(2026, 1, 1)), DateTime(2025, 12, 29));
    });

    test('totals, per-day bars, active days; other children and other weeks are ignored', () {
      final records = [
        rec('1', 'a', 'letter-a', 'trace', 3, DateTime(2026, 10, 5, 9), seconds: 60),
        rec('2', 'a', 'letter-a', 'listen-and-tap', 2, DateTime(2026, 10, 5, 10), seconds: 120),
        rec('3', 'a', 'letter-b', 'match-picture', 1, DateTime(2026, 10, 7, 8), seconds: 30),
        rec('4', 'a', 'letter-z', 'trace', 3, DateTime(2026, 9, 30, 8)), // previous week
        rec('5', 'b', 'letter-a', 'trace', 3, DateTime(2026, 10, 5, 8)), // someone else
      ];
      final w = summarizeWeek(records, 'a', DateTime(2026, 10, 8));
      expect(w.weekStart, monday);
      expect(w.days, hasLength(7));
      expect(w.totalStars, 6);
      expect(w.activitiesCompleted, 3);
      expect(w.lessonsPracticed, 2);
      expect(w.seconds, 210);
      expect(w.minutes, 4); // 3.5 rounds to 4
      expect(w.activeDays, 2);
      expect(w.days[0].stars, 5);
      expect(w.days[2].stars, 1);
      expect(w.days[1].activities, 0);
      expect(w.maxDayStars, 5);
    });

    test('an empty week is all zeros', () {
      final w = summarizeWeek([], 'a', monday);
      expect([w.totalStars, w.activitiesCompleted, w.activeDays, w.maxDayStars], [0, 0, 0, 0]);
    });

    testWidgets('weekly view shows the numbers and seven bars in the parent language', (tester) async {
      final w = summarizeWeek([rec('1', 'a', 'letter-a', 'trace', 3, DateTime(2026, 10, 5, 9))], 'a', monday);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: WeeklyView(summary: w, s: Strings.ar))));
      expect(find.text('هذا الأسبوع'), findsOneWidget);
      for (var i = 0; i < 7; i++) {
        expect(find.byKey(Key('week-bar-$i')), findsOneWidget);
      }
      expect(find.text('1/7'), findsOneWidget); // active days
    });
  });

  group('accessories', () {
    test('thresholds unlock in order and newlyUnlocked reports only crossings', () {
      expect(accessories.map((a) => a.unlockStars), orderedEquals([5, 15, 30, 50, 80]));
      expect(isUnlocked(accessories.first, 4), isFalse);
      expect(isUnlocked(accessories.first, 5), isTrue);
      expect(newlyUnlocked(0, 4), isEmpty);
      expect(newlyUnlocked(4, 5).map((a) => a.id), ['party-hat']);
      expect(newlyUnlocked(14, 52).map((a) => a.id), ['glasses', 'bow', 'crown']); // several at once
      expect(newlyUnlocked(80, 90), isEmpty);
      expect(accessoryById('crown')?.unlockStars, 50);
      expect(accessoryById('nope'), isNull);
    });

    test('total stars = best result per lesson and activity', () async {
      final c = containerWith(await testOverrides());
      addTearDown(c.dispose);
      final n = c.read(progressProvider.notifier);
      final t = DateTime(2026, 10, 5);
      await n.record(rec('1', 'k', 'letter-a', 'trace', 1, t));
      await n.record(rec('2', 'k', 'letter-a', 'trace', 3, t)); // replaces, not adds
      await n.record(rec('3', 'k', 'letter-a', 'match-picture', 2, t));
      await n.record(rec('4', 'k', 'letter-b', 'trace', 3, t));
      expect(n.totalStars('k'), 8);
      expect(n.totalStars('other'), 0);
    });

    test('equipping is stored per child, survives a restart, and can be removed', () async {
      final overrides = await testOverrides();
      final c1 = containerWith(overrides);
      addTearDown(c1.dispose);
      final a = await c1.read(profilesProvider.notifier).add(name: 'A', avatarKey: 'star', birthYear: 2022);
      final b = await c1.read(profilesProvider.notifier).add(name: 'B', avatarKey: 'sun', birthYear: 2021);
      await c1.read(profilesProvider.notifier).equip(a.id, 'crown');

      final c2 = containerWith(overrides);
      addTearDown(c2.dispose);
      final profiles = c2.read(profilesProvider);
      expect(profiles.firstWhere((p) => p.id == a.id).equippedAccessory, 'crown');
      expect(profiles.firstWhere((p) => p.id == b.id).equippedAccessory, isNull);

      await c2.read(profilesProvider.notifier).equip(a.id, null);
      expect(c2.read(profilesProvider).firstWhere((p) => p.id == a.id).equippedAccessory, isNull);
      await c2.read(profilesProvider.notifier).update(a.id, name: 'A2'); // editing the name must not lose the accessory choice
    });

    testWidgets('wardrobe: locked items cannot be worn; unlocked ones toggle on and off', (tester) async {
      final content = realContent();
      final overrides = await testOverrides(content: content);
      final container = containerWith(overrides);
      addTearDown(container.dispose);
      final child = await container.read(profilesProvider.notifier).add(name: 'Omar', avatarKey: 'star', birthYear: 2022);
      container.read(activeChildIdProvider.notifier).select(child.id);
      // 6 stars: enough for the party hat (5) but not the glasses (15)
      final t = DateTime(2026, 10, 5);
      await container.read(progressProvider.notifier).record(rec('1', child.id, 'letter-a', 'trace', 3, t));
      await container.read(progressProvider.notifier).record(rec('2', child.id, 'letter-a', 'match-picture', 3, t));

      await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const MaterialApp(home: WardrobeScreen())));
      await tester.pump();
      expect(find.text('6'), findsOneWidget);

      await tester.tap(find.byKey(const Key('accessory-glasses')));
      await tester.pump();
      expect(container.read(profilesProvider).single.equippedAccessory, isNull); // locked: nothing happens

      await tester.tap(find.byKey(const Key('accessory-party-hat')));
      await tester.pump();
      expect(container.read(profilesProvider).single.equippedAccessory, 'party-hat');
      expect(find.byKey(const Key('worn-party-hat')), findsOneWidget);

      await tester.tap(find.byKey(const Key('accessory-party-hat')));
      await tester.pump();
      expect(container.read(profilesProvider).single.equippedAccessory, isNull);
      expect(find.byKey(const Key('worn-party-hat')), findsNothing);
    });

    testWidgets('the stars screen shows a reveal when a result unlocked an accessory', (tester) async {
      final content = realContent();
      final overrides = await testOverrides(content: content);
      await tester.pumpWidget(ProviderScope(
        overrides: [...overrides, audioServiceOverride],
        child: MaterialApp(
          home: Scaffold(
            body: ActivityResultView(stars: 3, lesson: content.lessons.first, unlocked: [accessories.first], onDone: () {}),
          ),
        ),
      ));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const Key('new-accessory')), findsOneWidget);
    });
  });

  group('guards', () {
    test('wardrobe needs a selected child', () {
      expect(guardRoute(location: '/wardrobe', onboarded: true, hasProfiles: true, parentUnlocked: false, hasActiveChild: false), '/who');
      expect(guardRoute(location: '/wardrobe', onboarded: true, hasProfiles: true, parentUnlocked: false, hasActiveChild: true), isNull);
    });
  });

  group('sync service', () {
    late FakeSyncApi api;
    late MemoryTokenStore tokens;
    late SyncStore store;
    late SyncService service;
    final t0 = DateTime.utc(2026, 10, 5, 9);

    setUp(() async {
      api = FakeSyncApi();
      tokens = MemoryTokenStore();
      store = SyncStore(await mockPrefs());
      service = SyncService(apiFor: (_) => api, store: store, tokens: tokens, batchSize: 2);
      await service.login('http://10.0.2.2:5080', 'mom@example.com', 'secret');
    });

    test('first sync creates each child once and sends all records; the second sync sends nothing', () async {
      final children = [kid('c1'), kid('c2', 'Sara')];
      final records = [
        rec('r1', 'c1', 'letter-a', 'trace', 3, t0),
        rec('r2', 'c1', 'letter-a', 'listen-and-tap', 2, t0.add(const Duration(minutes: 1))),
        rec('r3', 'c1', 'letter-b', 'trace', 1, t0.add(const Duration(minutes: 2))),
        rec(newUuid(), 'c2', 'letter-a', 'match-picture', 3, t0),
      ];

      final first = await service.syncNow(children: children, progress: records);
      expect(first.childrenCreated, 2);
      expect(first.recordsPushed, 4);
      expect(api.createdChildren, ['Omar', 'Sara']);
      expect(api.stored['server-0'], hasLength(3));
      expect(api.stored['server-1'], hasLength(1));
      expect(api.stored['server-0']!.every(isUuid), isTrue); // legacy ids were converted to GUIDs

      final second = await service.syncNow(children: children, progress: records);
      expect([second.childrenCreated, second.recordsPushed], [0, 0]);
      expect(api.createdChildren, hasLength(2)); // not created again
    });

    test('only new records are sent on later syncs', () async {
      final children = [kid('c1')];
      final r1 = rec('r1', 'c1', 'letter-a', 'trace', 3, t0);
      await service.syncNow(children: children, progress: [r1]);
      final r2 = rec('r2', 'c1', 'letter-a', 'trace', 3, t0.add(const Duration(days: 1)));
      final report = await service.syncNow(children: children, progress: [r1, r2]);
      expect(report.recordsPushed, 1);
      expect(api.stored['server-0'], hasLength(2));
    });

    test('a failure mid-way keeps what was delivered and the next sync finishes the rest without duplicates', () async {
      final children = [kid('c1')];
      final records = [for (var i = 0; i < 5; i++) rec('r$i', 'c1', 'letter-a', 'trace', 2, t0.add(Duration(minutes: i)))];
      api.failSubmitAfter = 1; // batches of 2: the 2nd batch fails

      await expectLater(service.syncNow(children: children, progress: records), throwsA(isA<SyncException>()));
      expect(api.stored['server-0'], hasLength(2)); // first batch arrived
      expect(store.load().pushed, hasLength(2)); // ...and was remembered
      expect(store.load().childMap, {'c1': 'server-0'}); // the child exists and is remembered

      api.failSubmitAfter = -1;
      final report = await service.syncNow(children: children, progress: records);
      expect(report.childrenCreated, 0);
      expect(api.createdChildren, hasLength(1));
      expect(api.stored['server-0'], hasLength(5));
      expect(report.duplicates, 0);
    });

    test('lost local state is harmless: the server ignores records it already has', () async {
      final children = [kid('c1')];
      final records = [rec(newUuid(), 'c1', 'letter-a', 'trace', 3, t0)];
      await service.syncNow(children: children, progress: records);
      // pretend the progress-delivered list was lost, but the child mapping survived
      final s = store.load();
      await store.save(SyncState(baseUrl: s.baseUrl, email: s.email, childMap: s.childMap));
      final again = await service.syncNow(children: children, progress: records);
      expect([again.recordsPushed, again.duplicates], [0, 1]);
    });

    test('offline or signed out: a clear error and no state is lost', () async {
      final children = [kid('c1')];
      final records = [rec('r1', 'c1', 'letter-a', 'trace', 3, t0)];
      api.offline = true;
      await expectLater(service.syncNow(children: children, progress: records),
          throwsA(isA<SyncException>().having((e) => e.kind, 'kind', SyncErrorKind.network)));
      api.offline = false;
      expect((await service.syncNow(children: children, progress: records)).recordsPushed, 1);

      await service.signOut();
      expect(await service.isSignedIn(), isFalse);
      await expectLater(service.syncNow(children: children, progress: records),
          throwsA(isA<SyncException>().having((e) => e.kind, 'kind', SyncErrorKind.auth)));
    });

    test('the rotating refresh token is stored after every sync', () async {
      await service.syncNow(children: [kid('c1')], progress: []);
      expect(tokens.token, 'refresh-1');
      await service.syncNow(children: [kid('c1')], progress: []);
      expect(tokens.token, 'refresh-2');
    });

    test('signing in as a different account does not reuse the old mapping', () async {
      await service.syncNow(children: [kid('c1')], progress: [rec('r1', 'c1', 'letter-a', 'trace', 3, t0)]);
      await service.login('http://10.0.2.2:5080', 'other@example.com', 'secret');
      expect(store.load().childMap, isEmpty);
      expect(store.load().pushed, isEmpty);
    });

    test('the password is never stored on the device', () async {
      final raw = (await mockPrefs()).getKeys().join();
      expect(raw.contains('secret'), isFalse);
      expect(store.load().toJson().toString().contains('secret'), isFalse);
    });
  });

  group('http client', () {
    test('rejects malformed server addresses', () {
      expect(() => HttpSyncApi('not a url ::'), throwsA(isA<SyncException>()));
      expect(() => HttpSyncApi('ftp://x.com'), throwsA(isA<SyncException>()));
      HttpSyncApi('api.example.com'); // https:// is assumed
    });
  });

  group('settings sync section', () {
    testWidgets('sign in, sync now, see the result, sign out', (tester) async {
      final api = FakeSyncApi();
      final tokens = MemoryTokenStore();
      final base = await testOverrides();
      final container = ProviderContainer(overrides: [
        ...base,
        syncApiFactoryProvider.overrideWithValue((_) => api),
        tokenStoreProvider.overrideWithValue(tokens),
      ]);
      addTearDown(container.dispose);
      await container.read(profilesProvider.notifier).add(name: 'Omar', avatarKey: 'star', birthYear: 2022);

      await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const MaterialApp(home: SettingsScreen())));
      await tester.pump();
      await tester.scrollUntilVisible(find.byKey(const Key('sync-url')), 200, scrollable: find.byType(Scrollable).first);

      await tester.enterText(find.byKey(const Key('sync-url')), 'http://10.0.2.2:5080');
      await tester.enterText(find.byKey(const Key('sync-email')), 'mom@example.com');
      await tester.enterText(find.byKey(const Key('sync-password')), 'secret');
      await tester.tap(find.byKey(const Key('sync-login')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sync-signed-in')), findsOneWidget);
      expect(find.text('تم تسجيل الدخول'), findsOneWidget);

      await tester.tap(find.byKey(const Key('sync-now')));
      await tester.pumpAndSettle();
      expect(find.text('تمت المزامنة'), findsOneWidget);
      expect(api.createdChildren, ['Omar']);

      await tester.tap(find.byKey(const Key('sync-signout')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sync-login')), findsOneWidget);
    });

    testWidgets('wrong password shows a friendly error and stays signed out', (tester) async {
      final api = FakeSyncApi()..failLogin = true;
      final base = await testOverrides();
      final container = ProviderContainer(overrides: [
        ...base,
        syncApiFactoryProvider.overrideWithValue((_) => api),
        tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const MaterialApp(home: SettingsScreen())));
      await tester.pump();
      await tester.scrollUntilVisible(find.byKey(const Key('sync-url')), 200, scrollable: find.byType(Scrollable).first);
      await tester.enterText(find.byKey(const Key('sync-url')), 'http://x');
      await tester.enterText(find.byKey(const Key('sync-email')), 'mom@example.com');
      await tester.enterText(find.byKey(const Key('sync-password')), 'nope');
      await tester.tap(find.byKey(const Key('sync-login')));
      await tester.pumpAndSettle();
      expect(find.text('البريد أو كلمة المرور غير صحيحة'), findsOneWidget);
      expect(find.byKey(const Key('sync-signed-in')), findsNothing);
    });
  });
}

/// The stars screen plays a praise line; keep the real audio plugin out of tests.
final audioServiceOverride = audioServiceProvider.overrideWithValue(FakeAudio());
