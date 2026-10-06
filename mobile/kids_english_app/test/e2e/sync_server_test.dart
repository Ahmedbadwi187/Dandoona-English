import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kids_english_app/core/ids.dart';
import 'package:kids_english_app/features/profiles/child_profile.dart';
import 'package:kids_english_app/features/progress/progress.dart';
import 'package:kids_english_app/features/sync/sync_api.dart';
import 'package:kids_english_app/features/sync/sync_service.dart';
import 'dart:convert';

import '../helpers.dart';

/// End-to-end check of the real HTTP contract against a running API. Skipped unless KIDS_API_URL is set:
///   set KIDS_API_URL=http://localhost:5080   (API running in Development against a throwaway database)
///   flutter test test/e2e/sync_server_test.dart
void main() {
  final url = Platform.environment['KIDS_API_URL'];
  final skip = url == null ? 'set KIDS_API_URL to run against a live API' : false;

  test('register, sync children + progress, retry is idempotent, weekly summary matches', () async {
    final email = 'e2e-${newUuid().substring(0, 8)}@test.com';
    final prefs = await mockPrefs();
    final tokens = MemoryTokenStore();
    final service = SyncService(apiFor: (u) => HttpSyncApi(u), store: SyncStore(prefs), tokens: tokens, batchSize: 3);

    await service.register(url!, email, 'Passw0rd!x');
    expect(await service.isSignedIn(), isTrue);

    final now = DateTime.now().toUtc();
    final child = ChildProfile(id: 'local-1', name: 'Omar', avatarKey: 'star', birthYear: now.year - 4, createdAt: now);
    final records = [
      for (var i = 0; i < 7; i++)
        ProgressRecord(
          clientRecordId: i < 4 ? newUuid() : 'legacy-$i', // new UUIDs and ids from older app versions
          childId: child.id,
          lessonId: 'letter-${String.fromCharCode(97 + i % 3)}',
          activity: const ['trace', 'listen-and-tap', 'record-and-listen', 'match-picture'][i % 4],
          stars: 1 + i % 3,
          attempts: 1,
          timeSpentSeconds: 20,
          completedAt: now.subtract(Duration(seconds: 30 + i)),
        ),
    ];

    final first = await service.syncNow(children: [child], progress: records);
    expect(first.childrenCreated, 1);
    expect(first.recordsPushed, 7);

    // lose the "already delivered" list: the server must ignore every record it already has
    final s = SyncStore(prefs).load();
    await SyncStore(prefs).save(SyncState(baseUrl: s.baseUrl, email: s.email, childMap: s.childMap));
    final again = await service.syncNow(children: [child], progress: records);
    expect([again.recordsPushed, again.duplicates], [0, 7]);

    // read it back through the API as the same parent
    final api = HttpSyncApi(url);
    final auth = await api.login(email: email, password: 'Passw0rd!x');
    final serverChild = SyncStore(prefs).load().childMap[child.id]!;
    final res = await http.get(Uri.parse('$url/api/children/$serverChild/summary'), headers: {'Authorization': 'Bearer ${auth.accessToken}'});
    expect(res.statusCode, 200);
    final summary = jsonDecode(res.body) as Map<String, dynamic>;
    expect(summary['childName'], 'Omar');
    expect(summary['activitiesCompleted'], 7);
    expect(summary['totalStars'], records.fold<int>(0, (a, r) => a + r.stars));
  }, skip: skip);

  test('a wrong password is reported as an auth error, an unreachable server as a network error', () async {
    final email = 'e2e-${newUuid().substring(0, 8)}@test.com';
    final api = HttpSyncApi(url!);
    await api.register(email: email, password: 'Passw0rd!x', displayName: 'Parent');
    await expectLater(api.login(email: email, password: 'wrong-password'),
        throwsA(isA<SyncException>().having((e) => e.kind, 'kind', SyncErrorKind.auth)));
    await expectLater(HttpSyncApi('http://127.0.0.1:1', timeout: const Duration(seconds: 3)).login(email: email, password: 'x'),
        throwsA(isA<SyncException>().having((e) => e.kind, 'kind', SyncErrorKind.network)));
  }, skip: skip);
}
