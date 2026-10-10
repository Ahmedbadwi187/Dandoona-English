import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/features/profiles/child_profile.dart';
import 'package:kids_english_app/features/progress/progress.dart';
import 'package:kids_english_app/features/settings/settings.dart';
import 'package:kids_english_app/features/sync/auto_sync.dart';
import 'package:kids_english_app/features/sync/sync_api.dart';
import 'package:kids_english_app/features/sync/sync_controller.dart';
import 'package:kids_english_app/features/sync/sync_service.dart';

import 'helpers.dart';
import 'rewards_sync_test.dart' show FakeSyncApi, rec;

/// Sync with no button: it runs by itself, waits for the connection, never loses a change, and the newest change wins.
const _fast = AutoSyncTimings(debounce: Duration(milliseconds: 30), periodic: Duration(hours: 1), firstRetry: Duration(milliseconds: 60), maxRetry: Duration(milliseconds: 200));

class _Rig {
  _Rig(this.c, this.api, this.online, this.tokens);
  final ProviderContainer c;
  final FakeSyncApi api;
  final StreamController<bool> online;
  final MemoryTokenStore tokens;

  AutoSyncNotifier get auto => c.read(autoSyncProvider.notifier);
  SyncStatus get status => c.read(autoSyncProvider).status;

  Future<void> settle([int ms = 250]) => Future<void>.delayed(Duration(milliseconds: ms));
}

Future<_Rig> _rig({FakeSyncApi? api, bool signedIn = true, Map<String, Object>? prefs}) async {
  final fake = api ?? FakeSyncApi();
  final online = StreamController<bool>.broadcast();
  final tokens = MemoryTokenStore();
  final overrides = await testOverrides(prefs: prefs ?? {}, autoSync: true);
  final c = ProviderContainer(overrides: [
    ...overrides,
    autoSyncTimingsProvider.overrideWithValue(_fast),
    connectivityProvider.overrideWithValue(online.stream),
    syncApiFactoryProvider.overrideWithValue((_) => fake),
    tokenStoreProvider.overrideWithValue(tokens),
  ]);
  addTearDown(() {
    c.dispose();
    online.close();
  });
  if (signedIn) {
    await c.read(syncServiceProvider).login('http://x', 'mom@example.com', 'pw');
    await c.read(syncControllerProvider.notifier).refreshStatus();
  }
  return _Rig(c, fake, online, tokens);
}

void main() {
  group('no account', () {
    test('nothing is ever sent, and the status stays off', () async {
      final r = await _rig(signedIn: false);
      await r.auto.start();
      await r.c.read(profilesProvider.notifier).add(name: 'Omar', avatarKey: 'bear', birthYear: DateTime.now().year - 4);
      r.auto.changed();
      await r.settle();
      expect(r.api.createdChildren, isEmpty);
      expect(r.api.refreshCalls, 0);
      expect(r.status, SyncStatus.off);
    });
  });

  group('offline', () {
    test('changes made offline are kept, shown as waiting, and sent by themselves when the connection returns', () async {
      final r = await _rig();
      await r.auto.start();
      r.api.offline = true;

      final omar = await r.c.read(profilesProvider.notifier).add(name: 'Omar', avatarKey: 'bear', birthYear: DateTime.now().year - 4, goalMinutes: 10, skills: {'colors'});
      await r.c.read(progressProvider.notifier).record(rec('11111111-1111-4111-8111-111111111111', omar.id, 'letter-a', 'trace', 3, DateTime.utc(2026, 10, 1)));
      r.auto.changed();
      await r.settle();
      expect(r.status, SyncStatus.waiting); // saved on the phone, "will sync when online"
      expect(r.api.createdChildren, isEmpty);
      expect(r.c.read(profilesProvider).single.skills, {'colors'}); // nothing was lost

      r.api.offline = false;
      r.online.add(false);
      r.online.add(true); // the connection comes back
      await r.settle();
      expect(r.status, SyncStatus.saved);
      expect(r.api.createdChildren, ['Omar']);
      expect(r.api.stored.values.single, hasLength(1));
      expect(r.api.profiles.values.single.skills, {'colors'});
      expect(r.api.profiles.values.single.goalMinutes, 10);
    });

    test('a failed sync is retried with a wait, with no help from the parent', () async {
      final r = await _rig();
      await r.auto.start();
      r.api.offline = true;
      await r.c.read(profilesProvider.notifier).add(name: 'Omar', avatarKey: 'bear', birthYear: DateTime.now().year - 4);
      r.auto.changed();
      await r.settle(120);
      expect(r.status, SyncStatus.waiting);
      r.api.offline = false; // no connectivity event this time: only the retry timer
      await r.settle(500);
      expect(r.status, SyncStatus.saved);
      expect(r.api.createdChildren, ['Omar']);
    });

    test('the app works normally with no network: children and progress are added and read, nothing throws', () async {
      final r = await _rig();
      r.api.offline = true;
      await r.auto.start();
      final p = r.c.read(profilesProvider.notifier);
      final a = await p.add(name: 'A', avatarKey: 'bear', birthYear: DateTime.now().year - 5);
      await p.update(a.id, name: 'A2', goalMinutes: 5);
      await r.c.read(progressProvider.notifier).record(rec('22222222-2222-4222-8222-222222222222', a.id, 'letter-a', 'trace', 2, DateTime.utc(2026, 10, 1)));
      r.auto.changed();
      await r.settle();
      expect(r.c.read(profilesProvider).single.name, 'A2');
      expect(r.c.read(progressProvider).length, 1);
      expect(r.status, SyncStatus.waiting);
    });
  });

  group('changes go out shortly after, once for a burst', () {
    test('three quick changes make one sync', () async {
      final r = await _rig();
      await r.auto.start();
      await r.settle(100);
      final before = r.api.refreshCalls;
      final p = r.c.read(profilesProvider.notifier);
      final a = await p.add(name: 'A', avatarKey: 'bear', birthYear: DateTime.now().year - 5);
      r.auto.changed();
      await p.update(a.id, name: 'A1');
      r.auto.changed();
      await p.update(a.id, name: 'A2');
      r.auto.changed();
      await r.settle();
      expect(r.api.refreshCalls - before, 1);
      expect(r.api.profiles.values.single.name, 'A2');
    });
  });

  group('sign-up and sign-in', () {
    test('creating an account uploads the children and progress that are already on the phone', () async {
      final r = await _rig(signedIn: false);
      final kids = r.c.read(profilesProvider.notifier);
      final a = await kids.add(name: 'Sara', avatarKey: 'cat', birthYear: DateTime.now().year - 6, birthMonth: 3, goalMinutes: 15, track: 'explorers', skills: {'all-letters', 'some-letters'});
      await kids.add(name: 'Adam', avatarKey: 'fox', birthYear: DateTime.now().year - 4);
      await r.c.read(progressProvider.notifier).record(rec('33333333-3333-4333-8333-333333333333', a.id, 'letter-a', 'trace', 3, DateTime.utc(2026, 10, 1)));

      await r.c.read(syncControllerProvider.notifier).signIn('http://x', 'mom@example.com', 'pw', register: true);
      await r.auto.accountReady();
      await r.settle();

      expect(r.api.createdChildren, unorderedEquals(['Sara', 'Adam']));
      final sara = r.api.profiles.values.firstWhere((p) => p.name == 'Sara');
      expect((sara.track, sara.goalMinutes, sara.birthMonth), ('explorers', 15, 3));
      expect(sara.skills, {'all-letters', 'some-letters'});
      expect(r.api.stored.values.expand((e) => e).length, 1);
      expect(r.status, SyncStatus.saved);
    });

    test('logging in on a new phone brings the children, their skills, track and goal back', () async {
      final api = FakeSyncApi()
        ..serverChildren.add(ServerChild(id: 'srv-1', name: 'Lina', avatarKey: 'owl', birthYear: 2019, birthMonth: 2, track: 'explorers', goalMinutes: 10, skills: const {'reads-words', 'all-letters'}, updatedAt: DateTime.utc(2026, 10, 5)));
      final r = await _rig(api: api, signedIn: false);
      await r.c.read(syncControllerProvider.notifier).signIn('http://x', 'mom@example.com', 'pw');
      final lina = r.c.read(profilesProvider).single;
      expect((lina.name, lina.track, lina.goalMinutes), ('Lina', 'explorers', 10));
      expect(lina.skills, {'reads-words', 'all-letters'});
      expect(lina.updatedAt, DateTime.utc(2026, 10, 5));
      await r.settle();
      expect(api.updates, isEmpty, reason: 'what the server just gave is not sent back');
    });
  });

  group('two phones, the same child', () {
    Future<(_Rig, ChildProfile)> twoPhones({required DateTime local, required DateTime server}) async {
      final api = FakeSyncApi();
      final r = await _rig(api: api);
      final kid = await r.c.read(profilesProvider.notifier).add(name: 'Lina', avatarKey: 'owl', birthYear: DateTime.now().year - 7, goalMinutes: 10, skills: {'colors'});
      await r.c.read(profilesProvider.notifier).applyFromServer(kid.id, name: 'Lina', avatarKey: 'owl', birthYear: kid.birthYear, goalMinutes: 10, track: 'explorers', skills: {'colors'}, updatedAt: local);
      await r.c.read(syncServiceProvider).syncNow(children: r.c.read(profilesProvider), progress: []);
      // the other phone changed the profile on the server
      final id = r.c.read(syncStoreProvider).load().childMap[kid.id]!;
      api.profiles[id] = ServerChild(id: id, name: 'Lina Z', avatarKey: 'fox', birthYear: kid.birthYear, track: 'little-learners', goalMinutes: 5, skills: const {'animals'}, updatedAt: server);
      return (r, r.c.read(profilesProvider).single);
    }

    test('the other phone changed it later: its profile and skills win here', () async {
      final (r, _) = await twoPhones(local: DateTime.utc(2026, 10, 1), server: DateTime.utc(2026, 10, 3));
      await r.c.read(syncControllerProvider.notifier).syncQuietly(pullBack: true);
      final k = r.c.read(profilesProvider).single;
      expect((k.name, k.avatarKey, k.track, k.goalMinutes), ('Lina Z', 'fox', 'little-learners', 5));
      expect(k.skills, {'animals'});
    });

    test('this phone changed it later: its profile wins, the server takes it', () async {
      final (r, kid) = await twoPhones(local: DateTime.utc(2026, 10, 4), server: DateTime.utc(2026, 10, 3));
      await r.c.read(profilesProvider.notifier).applyFromServer(kid.id, name: 'Lina B', avatarKey: 'owl', birthYear: kid.birthYear, goalMinutes: 15, track: 'explorers', skills: {'colors', 'counting'}, updatedAt: DateTime.utc(2026, 10, 4, 1));
      await r.c.read(syncControllerProvider.notifier).syncQuietly(pullBack: true);
      final k = r.c.read(profilesProvider).single;
      expect((k.name, k.goalMinutes), ('Lina B', 15));
      expect(k.skills, {'colors', 'counting'});
      final held = r.api.profiles.values.single;
      expect((held.name, held.goalMinutes), ('Lina B', 15));
      expect(held.skills, {'colors', 'counting'});
    });

    test('the best result per lesson and the union of rewards survive from both phones', () async {
      final api = FakeSyncApi();
      final r = await _rig(api: api);
      final kid = await r.c.read(profilesProvider.notifier).add(name: 'Lina', avatarKey: 'owl', birthYear: DateTime.now().year - 7);
      await r.c.read(progressProvider.notifier).record(rec('44444444-4444-4444-8444-444444444444', kid.id, 'letter-a', 'trace', 1, DateTime.utc(2026, 10, 1)));
      await r.c.read(syncControllerProvider.notifier).syncQuietly(pullBack: true);
      final id = r.c.read(syncStoreProvider).load().childMap[kid.id]!;
      // the other phone played the same lesson better, and earned a certificate
      api.serverProgress[id] = [ServerProgress(clientRecordId: '55555555-5555-4555-8555-555555555555', lessonId: 'letter-a', activity: 'trace', stars: 3, attempts: 1, timeSpentSeconds: 30, completedAt: DateTime.utc(2026, 10, 2))];
      await r.c.read(syncControllerProvider.notifier).syncQuietly(pullBack: true);
      final records = r.c.read(progressProvider).where((x) => x.lessonId == 'letter-a').toList();
      expect(records.map((x) => x.stars).reduce((a, b) => a > b ? a : b), 3, reason: 'the best result counts');
      expect(records, hasLength(2), reason: 'both phones\' records are kept');
    });
  });

  group('settings', () {
    test('the sync section has no sync button any more: only the status line', () {
      // (the widget side is covered in rewards_sync_test.dart: no `sync-now` key exists)
      expect(SyncStatus.values, containsAll([SyncStatus.off, SyncStatus.saved, SyncStatus.saving, SyncStatus.waiting]));
    });

    test('settings stay as they are while syncing', () async {
      final r = await _rig();
      await r.auto.start();
      expect(r.c.read(settingsProvider).languageChosen, isFalse);
    });
  });
}
