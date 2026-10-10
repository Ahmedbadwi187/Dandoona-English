import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/core/ids.dart';
import 'package:kids_english_app/features/activities/activity_screen.dart';
import 'package:kids_english_app/features/audio/audio_service.dart';
import 'package:go_router/go_router.dart';
import 'package:kids_english_app/features/parent/edit_child_screen.dart';
import 'package:kids_english_app/features/parent/settings_screen.dart';
import 'package:kids_english_app/features/parent/weekly_view.dart';
import 'package:kids_english_app/features/profiles/child_profile.dart';
import 'package:kids_english_app/features/progress/progress.dart';
import 'package:kids_english_app/features/progress/weekly_summary.dart';
import 'package:kids_english_app/features/rewards/accessories.dart';
import 'package:kids_english_app/features/settings/settings.dart';
import 'package:kids_english_app/features/rewards/wardrobe_screen.dart';
import 'package:kids_english_app/core/strings.dart';
import 'package:kids_english_app/features/sync/sync_api.dart';
import 'package:kids_english_app/features/units/unit_meta.dart';
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
  /// Every sign-up the app sent (what the server would store about consent).
  final registrations = <({String email, String displayName, bool guardianConfirmed, bool termsAccepted})>[];
  /// What the "server" already holds for this parent (for the sign-in pull): children and their records.
  final List<ServerChild> serverChildren = [];
  final Map<String, List<ServerProgress>> serverProgress = {};
  final List<String> createdChildren = [];
  final List<int?> createdBirthMonths = []; // the birth month each created child was sent with
  final Map<String, Set<String>> stored = {}; // server child id -> client record guids
  int refreshCalls = 0;
  int submitCalls = 0;
  bool failLogin = false;
  bool offline = false;
  int failSubmitAfter = -1; // fail on the Nth submit (0-based); -1 = never

  void _net() {
    if (offline) throw const SyncException(SyncErrorKind.network, 'offline');
  }

  /// Like the real server, refresh tokens are single-use: using one rotates it, and an old one is rejected.
  final Set<String> _validRefresh = {};

  @override
  Future<AuthTokens> register({required String email, required String password, required String displayName, bool guardianConfirmed = false, bool termsAccepted = false}) async {
    _net();
    registrations.add((email: email, displayName: displayName, guardianConfirmed: guardianConfirmed, termsAccepted: termsAccepted));
    _validRefresh.add('refresh-0');
    return const AuthTokens(accessToken: 'access-0', refreshToken: 'refresh-0');
  }

  /// The addresses a reset code was asked for, and the last new password set (with the code the "server" accepts).
  final forgotten = <String>[];
  String validResetCode = '123456';
  String? passwordSetTo;

  @override
  Future<void> forgotPassword(String email) async {
    _net();
    forgotten.add(email);
  }

  @override
  Future<void> resetPassword({required String email, required String code, required String newPassword}) async {
    _net();
    if (code != validResetCode || newPassword.length < 8) throw const SyncException(SyncErrorKind.validation, 'The code is not valid.');
    passwordSetTo = newPassword;
    validResetCode = ''; // used once
  }

  @override
  Future<AuthTokens> login({required String email, required String password}) async {
    _net();
    if (failLogin) throw const SyncException(SyncErrorKind.auth, 'bad credentials');
    _validRefresh.add('refresh-0');
    return const AuthTokens(accessToken: 'access-0', refreshToken: 'refresh-0');
  }

  @override
  Future<AuthTokens> refresh(String refreshToken) async {
    _net();
    if (!_validRefresh.remove(refreshToken)) throw const SyncException(SyncErrorKind.auth, 'Invalid refresh token.');
    refreshCalls++;
    _validRefresh.add('refresh-$refreshCalls');
    return AuthTokens(accessToken: 'access-$refreshCalls', refreshToken: 'refresh-$refreshCalls');
  }

  @override
  Future<String> createChild(String accessToken, {required String name, required String avatarKey, required int birthYear, required String track, int? birthMonth}) async {
    _net();
    final id = 'server-${createdChildren.length}';
    createdBirthMonths.add(birthMonth);
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

  @override
  Future<List<ServerChild>> listChildren(String accessToken) async {
    _net();
    return [...serverChildren];
  }

  @override
  Future<List<ServerProgress>> listProgress(String accessToken, String serverChildId) async {
    _net();
    return [...?serverProgress[serverChildId]];
  }

  /// Achievements per server child: (kind|key) -> the one kept (earliest date), like the real server.
  final Map<String, Map<String, ServerAchievement>> achievements = {};
  int achievementCalls = 0;

  @override
  Future<void> submitAchievements(String accessToken, String serverChildId, List<ServerAchievement> items) async {
    _net();
    achievementCalls++;
    final mine = achievements.putIfAbsent(serverChildId, () => {});
    for (final i in items) {
      final k = '${i.kind}|${i.key}';
      final known = mine[k];
      if (known == null || i.earnedAt.isBefore(known.earnedAt)) mine[k] = i;
    }
  }

  @override
  Future<List<ServerAchievement>> listAchievements(String accessToken, String serverChildId) async {
    _net();
    return [...?achievements[serverChildId]?.values];
  }

  final List<String> deletedChildren = [];
  bool childAlreadyGone = false;

  @override
  Future<void> deleteChild(String accessToken, String serverChildId) async {
    _net();
    if (childAlreadyGone) throw const SyncException(SyncErrorKind.notFound, 'Child not found.');
    deletedChildren.add(serverChildId);
    stored.remove(serverChildId); // hard delete: the child's progress goes with it
    serverChildren.removeWhere((c) => c.id == serverChildId); // and it is no longer listed
  }

  bool accountDeleted = false;
  String? deletedWithPassword;
  bool wrongPassword = false;

  @override
  Future<void> deleteAccount(String accessToken, String password) async {
    _net();
    deletedWithPassword = password;
    if (wrongPassword) throw const SyncException(SyncErrorKind.auth, 'Password is incorrect');
    accountDeleted = true;
  }
}

/// The edit-child screen with a router, so that deleting can go back to the (placeholder) list.
Widget _editApp(ProviderContainer container, String childId) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: GoRouter(routes: [
          GoRoute(path: '/', builder: (_, _) => EditChildScreen(childId: childId)),
          GoRoute(path: '/parent/children', builder: (_, _) => const Scaffold(body: Text('list'))),
        ]),
      ),
    );

void main() {
  pullTests();
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

    testWidgets('week tiles and chart show the numbers and seven bars in the parent language', (tester) async {
      final w = summarizeWeek([rec('1', 'a', 'letter-a', 'trace', 3, DateTime(2026, 10, 5, 9))], 'a', monday);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Column(children: [WeekTiles(summary: w, s: Strings.ar), WeekChart(summary: w, s: Strings.ar, goalMinutes: 10, today: monday)]))));
      expect(find.text('النجوم'), findsOneWidget);
      for (var i = 0; i < 7; i++) {
        expect(find.byKey(Key('week-bar-$i')), findsOneWidget);
      }
      expect(find.text('١/٧'), findsOneWidget); // active days, in Arabic digits
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

  group('child deletion reaches the server (queued when offline)', () {
    late FakeSyncApi api;
    late MemoryTokenStore tokens;
    late SyncStore store;
    late SyncService service;
    final t0 = DateTime.utc(2026, 10, 5, 9);

    setUp(() async {
      api = FakeSyncApi();
      tokens = MemoryTokenStore();
      store = SyncStore(await mockPrefs());
      service = SyncService(apiFor: (_) => api, store: store, tokens: tokens);
      await service.login('http://x', 'mom@example.com', 'secret');
      await service.syncNow(
          children: [kid('c1'), kid('c2', 'Sara')],
          progress: [rec(newUuid(), 'c1', 'letter-a', 'trace', 3, t0), rec(newUuid(), 'c2', 'letter-a', 'trace', 3, t0)]);
    });

    test('a synced child is queued and then hard-deleted on the server with its progress; the sibling stays', () async {
      expect(await service.queueChildDelete('c1'), isTrue);
      expect(service.pendingDeleteCount, 1);
      expect(store.load().childMap.containsKey('c1'), isFalse);

      expect(await service.flushDeletes(), 1);
      expect(api.deletedChildren, ['server-0']);
      expect(api.stored.containsKey('server-0'), isFalse); // progress gone with the child
      expect(api.stored['server-1'], hasLength(1)); // sibling untouched
      expect(service.pendingDeleteCount, 0);
    });

    test('a child that was never synced has nothing to delete on the server', () async {
      expect(await service.queueChildDelete('never-synced'), isFalse);
      expect(service.pendingDeleteCount, 0);
      expect(await service.flushDeletes(), 0);
      expect(api.deletedChildren, isEmpty);
    });

    test('offline: the delete stays queued, survives a restart, and goes out first on the next sync', () async {
      await service.queueChildDelete('c1');
      api.offline = true;
      await expectLater(service.flushDeletes(), throwsA(isA<SyncException>().having((e) => e.kind, 'kind', SyncErrorKind.network)));
      expect(service.pendingDeleteCount, 1);

      // "restart": a new service over the same storage still knows about the queued delete
      final again = SyncService(apiFor: (_) => api, store: store, tokens: tokens);
      expect(again.pendingDeleteCount, 1);

      api.offline = false;
      final report = await again.syncNow(children: [kid('c2', 'Sara')], progress: []);
      expect(api.deletedChildren, ['server-0']);
      expect(again.pendingDeleteCount, 0);
      expect(report.childrenCreated, 0); // the deleted child was not recreated
      expect(api.createdChildren, hasLength(2));
    });

    test('a child that is already gone on the server counts as deleted', () async {
      await service.queueChildDelete('c1');
      api.childAlreadyGone = true;
      expect(await service.flushDeletes(), 1);
      expect(service.pendingDeleteCount, 0);
    });

    test('a failing delete keeps the rest of the queue intact', () async {
      await service.queueChildDelete('c1');
      await service.queueChildDelete('c2');
      expect(service.pendingDeleteCount, 2);
      api.offline = true;
      await expectLater(service.flushDeletes(), throwsA(isA<SyncException>()));
      expect(service.pendingDeleteCount, 2);
      api.offline = false;
      expect(await service.flushDeletes(), 2);
      expect(service.pendingDeleteCount, 0);
    });

    test('deleting while signed out queues it; signing back in as the same account sends it', () async {
      await service.signOut();
      expect(await service.queueChildDelete('c1'), isTrue); // the mapping survived the sign-out
      await expectLater(service.flushDeletes(), throwsA(isA<SyncException>().having((e) => e.kind, 'kind', SyncErrorKind.auth)));
      expect(service.pendingDeleteCount, 1);

      await service.login('http://x', 'mom@example.com', 'secret');
      expect(await service.flushDeletes(), 1);
      expect(api.deletedChildren, ['server-0']);
    });

    test('signing in as a different account drops the queue (those ids belong to another account)', () async {
      await service.queueChildDelete('c1');
      await service.signOut();
      await service.login('http://x', 'someone-else@example.com', 'secret');
      expect(service.pendingDeleteCount, 0);
      expect(api.deletedChildren, isEmpty);
    });

    test('the queue is cleared when the whole account is deleted', () async {
      await service.queueChildDelete('c1');
      await service.deleteAccount('secret');
      expect(service.pendingDeleteCount, 0);
    });

    testWidgets('edit child: delete + confirm removes locally and on the server', (tester) async {
      final base = await testOverrides();
      final container = ProviderContainer(overrides: [
        ...base,
        syncApiFactoryProvider.overrideWithValue((_) => api),
        tokenStoreProvider.overrideWithValue(tokens),
      ]);
      addTearDown(container.dispose);
      // a real local profile that has been synced
      final omar = await container.read(profilesProvider.notifier).add(name: 'Omar', avatarKey: 'star', birthYear: 2022);
      final svc = container.read(syncServiceProvider);
      await svc.login('http://x', 'mom@example.com', 'secret');
      await svc.syncNow(children: [omar], progress: []);
      final serverId = container.read(syncStoreProvider).load().childMap[omar.id]!;

      tester.view.physicalSize = const Size(1080, 4200); // tall, so the whole form is built
      tester.view.devicePixelRatio = 1080 / 411;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_editApp(container, omar.id));
      await tester.pump();
      await tester.tap(find.byKey(const Key('edit-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-delete')));
      await tester.pumpAndSettle();

      expect(container.read(profilesProvider), isEmpty);
      expect(api.deletedChildren, contains(serverId));
      expect(svc.pendingDeleteCount, 0);
    });

    testWidgets('edit child while offline: the profile is deleted now, the server delete waits and is shown as pending', (tester) async {
      api.offline = true;
      final base = await testOverrides();
      final container = ProviderContainer(overrides: [
        ...base,
        syncApiFactoryProvider.overrideWithValue((_) => api),
        tokenStoreProvider.overrideWithValue(tokens),
      ]);
      addTearDown(container.dispose);
      final omar = await container.read(profilesProvider.notifier).add(name: 'Omar', avatarKey: 'star', birthYear: 2022);
      // sync state with a mapping for this child (as if it had synced earlier)
      await container.read(syncStoreProvider).save(SyncState(baseUrl: 'http://x', email: 'mom@example.com', childMap: {omar.id: 'server-9'}));
      await tokens.saveRefreshToken('refresh-0');

      tester.view.physicalSize = const Size(1080, 4200); // tall, so the whole form is built
      tester.view.devicePixelRatio = 1080 / 411;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_editApp(container, omar.id));
      await tester.pump();
      await tester.tap(find.byKey(const Key('edit-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-delete')));
      await tester.pumpAndSettle();

      expect(container.read(profilesProvider), isEmpty); // gone locally right away
      expect(container.read(syncServiceProvider).pendingDeleteCount, 1); // queued for the server
      expect(api.deletedChildren, isEmpty);
    });
  });

  group('delete account', () {
    test('deletes on the server, forgets the account locally, keeps the address', () async {
      final api = FakeSyncApi();
      final tokens = MemoryTokenStore();
      final store = SyncStore(await mockPrefs());
      final service = SyncService(apiFor: (_) => api, store: store, tokens: tokens);
      await service.login('http://x', 'mom@example.com', 'secret');
      await service.syncNow(children: [kid('c1')], progress: []);

      await service.deleteAccount('secret');
      expect(api.accountDeleted, isTrue);
      expect(api.deletedWithPassword, 'secret');
      expect(await service.isSignedIn(), isFalse);
      expect(tokens.token, isNull);
      expect(store.load().childMap, isEmpty); // a future account starts from scratch
      expect(store.load().baseUrl, 'http://x');
    });

    test('a wrong password leaves the account and the sign-in untouched', () async {
      final api = FakeSyncApi()..wrongPassword = true;
      final tokens = MemoryTokenStore();
      final service = SyncService(apiFor: (_) => api, store: SyncStore(await mockPrefs()), tokens: tokens);
      await service.login('http://x', 'mom@example.com', 'secret');
      await expectLater(service.deleteAccount('nope'), throwsA(isA<SyncException>()));
      expect(api.accountDeleted, isFalse);
      expect(await service.isSignedIn(), isTrue);

      // the refused attempt used (and rotated) the refresh token: a second attempt must still work
      api.wrongPassword = false;
      await service.deleteAccount('secret');
      expect(api.accountDeleted, isTrue);
    });

    testWidgets('settings: the confirm dialog needs a password, then signs out', (tester) async {
      final api = FakeSyncApi();
      final base = await testOverrides();
      final container = ProviderContainer(overrides: [
        ...base,
        syncApiFactoryProvider.overrideWithValue((_) => api),
        tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
      ]);
      addTearDown(container.dispose);
      await container.read(syncServiceProvider).login('http://x', 'mom@example.com', 'secret');

      await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const MaterialApp(home: SettingsScreen())));
      await tester.pump();
      await tester.scrollUntilVisible(find.byKey(const Key('sync-delete')), 200, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.byKey(const Key('sync-delete')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('sync-delete')));
      await tester.pumpAndSettle();
      expect(find.text('حذف الحساب نهائيًا؟'), findsOneWidget);
      await tester.tap(find.byKey(const Key('delete-confirm'))); // empty password: nothing is sent
      await tester.pumpAndSettle();
      expect(api.accountDeleted, isFalse);

      await tester.tap(find.byKey(const Key('sync-delete')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('delete-password')), 'secret');
      await tester.tap(find.byKey(const Key('delete-confirm')));
      await tester.pumpAndSettle();
      expect(api.accountDeleted, isTrue);
      expect(find.text('تم حذف الحساب'), findsOneWidget);
      expect(find.byKey(const Key('sync-open-auth')), findsOneWidget);
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
    Future<ProviderContainer> open(FakeSyncApi api, WidgetTester tester, {bool signedIn = false}) async {
      final base = await testOverrides();
      final container = ProviderContainer(overrides: [
        ...base,
        syncApiFactoryProvider.overrideWithValue((_) => api),
        tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
      ]);
      addTearDown(container.dispose);
      await container.read(profilesProvider.notifier).add(name: 'Omar', avatarKey: 'star', birthYear: 2022);
      if (signedIn) await container.read(syncControllerProvider.notifier).signIn('http://x', 'mom@example.com', 'secret');
      await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const MaterialApp(home: SettingsScreen())));
      await tester.pump();
      await tester.scrollUntilVisible(find.byKey(const Key('sync-section')), 200, scrollable: find.byType(Scrollable).first);
      return container;
    }

    testWidgets('without an account there is one button (no form here): the account screen is shared with the first-launch flow', (tester) async {
      await open(FakeSyncApi(), tester);
      expect(find.byKey(const Key('sync-open-auth')), findsOneWidget);
      expect(find.byKey(const Key('sync-url')), findsNothing);
      expect(find.byKey(const Key('sync-email')), findsNothing);
      expect(find.byKey(const Key('sync-now')), findsNothing);
    });

    testWidgets('signed in: sync now sends the children, then sign out returns to the button', (tester) async {
      final api = FakeSyncApi();
      await open(api, tester, signedIn: true);
      await tester.pump();
      expect(find.byKey(const Key('sync-signed-in')), findsOneWidget);

      await tester.tap(find.byKey(const Key('sync-now')));
      await tester.pumpAndSettle();
      expect(find.text('تمت المزامنة'), findsOneWidget);
      expect(api.createdChildren, ['Omar']);

      await tester.tap(find.byKey(const Key('sync-signout')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sync-open-auth')), findsOneWidget);
    });
  });
}

/// The stars screen plays a praise line; keep the real audio plugin out of tests.
final audioServiceOverride = audioServiceProvider.overrideWithValue(FakeAudio());

/// Signing in on a phone brings the account's children and progress from the server.
void pullTests() {
  ServerProgress rec(String guid, String lesson, String activity, {int stars = 3}) => ServerProgress(
      clientRecordId: guid,
      lessonId: lesson,
      activity: activity,
      stars: stars,
      attempts: 1,
      timeSpentSeconds: 20,
      completedAt: DateTime.utc(2026, 9, 1, 10));

  Future<(ProviderContainer, FakeSyncApi)> open() async {
    final api = FakeSyncApi()
      ..serverChildren.addAll(const [
        ServerChild(id: 'srv-sara', name: 'Sara', avatarKey: 'rocket', birthYear: 2021, track: 'little-learners'),
        ServerChild(id: 'srv-adam', name: 'Adam', avatarKey: 'cloud', birthYear: 2022, track: 'little-learners'),
      ])
      ..serverProgress['srv-sara'] = [
        rec('11111111-1111-4111-8111-111111111111', 'letter-a', 'trace'),
        rec('22222222-2222-4222-8222-222222222222', 'color-red', 'color-the-object'),
      ]
      ..serverProgress['srv-adam'] = [rec('33333333-3333-4333-8333-333333333333', 'letter-a', 'trace', stars: 2)];
    final base = await testOverrides();
    final container = ProviderContainer(overrides: [
      ...base,
      syncApiFactoryProvider.overrideWithValue((_) => api),
      tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
    ]);
    addTearDown(container.dispose);
    return (container, api);
  }

  group('sign-in brings the family\'s data to the device', () {
    test('children and every progress record arrive, and the app starts past the first-child screen', () async {
      final (c, _) = await open();
      await c.read(syncControllerProvider.notifier).signIn('http://x', 'mom@example.com', 'pw');

      final kids = c.read(profilesProvider);
      expect(kids.map((k) => k.name), ['Sara', 'Adam']);
      final sara = kids.first;
      final records = c.read(progressProvider).where((r) => r.childId == sara.id).toList();
      expect(records.map((r) => '${r.lessonId}/${r.activity}'), ['letter-a/trace', 'color-red/color-the-object']);
      expect(c.read(settingsProvider).onboarded, isTrue);
    });

    test('what was just downloaded is not uploaded again, and signing in twice does not duplicate anything', () async {
      final (c, api) = await open();
      final n = c.read(syncControllerProvider.notifier);
      await n.signIn('http://x', 'mom@example.com', 'pw');
      await n.syncNow();
      expect(api.createdChildren, isEmpty);
      expect(api.submitCalls, 0);

      await n.signOut();
      await n.signIn('http://x', 'mom@example.com', 'pw');
      expect(c.read(profilesProvider), hasLength(2));
      expect(c.read(progressProvider), hasLength(3));
    });


    test('certificates, chests, reviews and stories come back on a new phone; a certificate from another phone is not celebrated again', () async {
      final (c, api) = await open();
      api.achievements['srv-sara'] = {
        'certificate|letters': ServerAchievement(kind: 'certificate', key: 'letters', earnedAt: DateTime.utc(2026, 9, 1)),
        'chest|letters': ServerAchievement(kind: 'chest', key: 'letters', earnedAt: DateTime.utc(2026, 9, 1)),
        'story|letters': ServerAchievement(kind: 'story', key: 'letters', earnedAt: DateTime.utc(2026, 9, 2)),
      };
      await c.read(syncControllerProvider.notifier).signIn('http://x', 'mom@example.com', 'pw');
      final sara = c.read(profilesProvider).first;
      final meta = c.read(unitMetaProvider).of(sara.id);
      expect(meta.certificates, {'letters': '2026-09-01'});
      expect(meta.celebrated, contains('letters'));
      expect(meta.chests, {'letters'});
      expect(meta.stories, {'letters'});
    });

    test('"Sync now" sends this phone\'s achievements and brings back results from the family\'s other phones', () async {
      final (c, api) = await open();
      final n = c.read(syncControllerProvider.notifier);
      await n.signIn('http://x', 'mom@example.com', 'pw');
      final sara = c.read(profilesProvider).first;
      await c.read(unitMetaProvider.notifier).merge(sara.id, [(kind: 'chest', key: 'letters', earnedAt: DateTime.utc(2026, 9, 3))]); // opened here

      // meanwhile, another phone played letter-a better and passed a review
      api.serverProgress['srv-sara'] = [...api.serverProgress['srv-sara']!, rec('44444444-4444-4444-8444-444444444444', 'letter-a', 'trace', stars: 3)];
      api.achievements['srv-sara'] = {'review|review-1': ServerAchievement(kind: 'review', key: 'review-1', earnedAt: DateTime.utc(2026, 9, 4))};

      await n.syncNow();
      expect(api.achievements['srv-sara']!.keys, containsAll(['chest|letters', 'review|review-1']));
      expect(c.read(unitMetaProvider).of(sara.id).reviews, {'review-1'});
      expect(c.read(progressProvider.notifier).starsFor(sara.id, 'letter-a'), 3); // the best result per lesson wins
      expect(api.submitCalls, 0); // records that came from the server are not sent back
    });

    test('an account with no children changes nothing locally', () async {
      final (c, api) = await open();
      api.serverChildren.clear();
      await c.read(syncControllerProvider.notifier).signIn('http://x', 'mom@example.com', 'pw');
      expect(c.read(profilesProvider), isEmpty);
      expect(c.read(settingsProvider).onboarded, isFalse);
    });

    test('a child deleted here and still waiting to be deleted on the server is not brought back', () async {
      final (c, api) = await open();
      final n = c.read(syncControllerProvider.notifier);
      await n.signIn('http://x', 'mom@example.com', 'pw');
      final sara = c.read(profilesProvider).first;
      api.offline = true;
      await c.read(profilesProvider.notifier).remove(sara.id);
      await n.childDeleted(sara.id); // queued: the server is unreachable
      api.offline = false;
      api.serverChildren.removeWhere((x) => x.id == 'srv-adam'); // keep the fake simple: Sara is the one that stays "on the server"
      await n.signIn('http://x', 'mom@example.com', 'pw');
      expect(api.deletedChildren, contains('srv-sara'));
      expect(c.read(profilesProvider).map((k) => k.name), isNot(contains('Sara')));
    });
  });
}
