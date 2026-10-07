import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/core/storage.dart';
import 'package:kids_english_app/features/profiles/child_profile.dart';
import 'package:kids_english_app/features/progress/progress.dart';
import 'package:kids_english_app/features/sync/sync_api.dart';
import 'package:kids_english_app/features/sync/sync_controller.dart';
import 'package:kids_english_app/features/sync/sync_service.dart';

import 'helpers.dart';
import 'rewards_sync_test.dart' show FakeSyncApi;

void main() {
  group('child profile', () {
    test('keeps the birth month and the daily goal through JSON, and a profile saved before them still loads', () {
      final p = ChildProfile(id: 'a', name: 'Omar', avatarKey: 'bunny', birthYear: 2022, birthMonth: 3, goalMinutes: 10, createdAt: DateTime.utc(2026, 1, 1));
      final back = ChildProfile.fromJson(p.toJson());
      expect((back.birthMonth, back.goalMinutes), (3, 10));

      final old = ChildProfile.fromJson({'id': 'b', 'name': 'Sara', 'avatarKey': 'star', 'birthYear': 2021, 'createdAt': '2026-01-01T00:00:00Z'});
      expect((old.birthMonth, old.goalMinutes), (null, null));
      expect(old.toJson().containsKey('birthMonth'), isFalse);
    });

    test('changing the answers later keeps everything else', () async {
      final prefs = await mockPrefs();
      final c = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
      addTearDown(c.dispose);
      final n = c.read(profilesProvider.notifier);
      final p = await n.add(name: 'Omar', avatarKey: 'bunny', birthYear: 2022, birthMonth: 3, goalMinutes: 5);
      await n.update(p.id, goalMinutes: 15, birthMonth: 11);
      final now = c.read(profilesProvider).single;
      expect((now.name, now.avatarKey, now.birthYear, now.birthMonth, now.goalMinutes), ('Omar', 'bunny', 2022, 11, 15));
    });
  });

  group('the birth month travels with the account', () {
    test('it is sent to the server with the child', () async {
      final api = FakeSyncApi();
      final service = SyncService(apiFor: (_) => api, store: SyncStore(await mockPrefs()), tokens: MemoryTokenStore());
      await service.login('http://x', 'mom@example.com', 'pw');
      final now = DateTime.utc(2026, 1, 1);
      await service.syncNow(
        children: [
          ChildProfile(id: 'a', name: 'Omar', avatarKey: 'bunny', birthYear: 2022, birthMonth: 3, createdAt: now),
          ChildProfile(id: 'b', name: 'Sara', avatarKey: 'owl', birthYear: 2021, createdAt: now),
        ],
        progress: const [],
      );
      expect(api.createdBirthMonths, [3, null]);
    });

    test('a child brought from the server after sign-in has the month too', () async {
      final api = FakeSyncApi()
        ..serverChildren.add(const ServerChild(id: 's1', name: 'Sara', avatarKey: 'owl', birthYear: 2021, track: 'little-learners', birthMonth: 8));
      final base = await testOverrides();
      final c = ProviderContainer(overrides: [...base, syncApiFactoryProvider.overrideWithValue((_) => api), tokenStoreProvider.overrideWithValue(MemoryTokenStore())]);
      addTearDown(c.dispose);
      await c.read(syncControllerProvider.notifier).signIn('http://x', 'mom@example.com', 'pw');
      expect(c.read(profilesProvider).single.birthMonth, 8);
      expect(c.read(progressProvider), isEmpty);
    });
  });
}
