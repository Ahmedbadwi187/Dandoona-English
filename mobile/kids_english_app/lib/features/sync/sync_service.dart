import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/ids.dart';
import '../../core/storage.dart';
import '../profiles/child_profile.dart';
import '../progress/progress.dart';
import 'sync_api.dart';

/// Where the refresh token lives. The real one uses the platform keystore; tests use memory.
abstract class TokenStore {
  Future<String?> readRefreshToken();
  Future<void> saveRefreshToken(String token);
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  static const _key = 'kids_english_refresh_token';

  @override
  Future<String?> readRefreshToken() async {
    try {
      return await _storage.read(key: _key);
    } on Object {
      return null; // an unreadable keystore just means "signed out"
    }
  }

  @override
  Future<void> saveRefreshToken(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

class MemoryTokenStore implements TokenStore {
  String? token;
  @override
  Future<String?> readRefreshToken() async => token;
  @override
  Future<void> saveRefreshToken(String t) async => token = t;
  @override
  Future<void> clear() async => token = null;
}

/// Sync bookkeeping kept on the device: the server address, the account e-mail (never the password), which local
/// child maps to which server child, and which progress records were already delivered.
class SyncState {
  const SyncState({
    this.baseUrl = '',
    this.email = '',
    this.childMap = const {},
    this.pushed = const {},
    this.pendingDeletes = const {},
    this.profilePushed = const {},
    this.lastSyncUtc,
  });

  final String baseUrl;
  final String email;
  final Map<String, String> childMap; // local child id -> server child id
  final Set<String> pushed; // local clientRecordIds already accepted by the server
  /// Server child ids whose local profile was deleted but the server copy is not confirmed deleted yet (e.g. it was offline).
  final Set<String> pendingDeletes;

  /// local child id -> the `updatedAt` of the profile version the server already has (a profile that differs is sent again).
  final Map<String, String> profilePushed;
  final DateTime? lastSyncUtc;

  SyncState copyWith({
    String? baseUrl,
    String? email,
    Map<String, String>? childMap,
    Set<String>? pushed,
    Set<String>? pendingDeletes,
    Map<String, String>? profilePushed,
    DateTime? lastSyncUtc,
  }) =>
      SyncState(
        baseUrl: baseUrl ?? this.baseUrl,
        email: email ?? this.email,
        childMap: childMap ?? this.childMap,
        pushed: pushed ?? this.pushed,
        pendingDeletes: pendingDeletes ?? this.pendingDeletes,
        profilePushed: profilePushed ?? this.profilePushed,
        lastSyncUtc: lastSyncUtc ?? this.lastSyncUtc,
      );

  Map<String, dynamic> toJson() => {
        'baseUrl': baseUrl,
        'email': email,
        'childMap': childMap,
        'pushed': pushed.toList(),
        'pendingDeletes': pendingDeletes.toList(),
        'profilePushed': profilePushed,
        if (lastSyncUtc != null) 'lastSyncUtc': lastSyncUtc!.toUtc().toIso8601String(),
      };

  factory SyncState.fromJson(Map<String, dynamic> json) => SyncState(
        baseUrl: (json['baseUrl'] as String?) ?? '',
        email: (json['email'] as String?) ?? '',
        childMap: ((json['childMap'] as Map?) ?? {}).map((k, v) => MapEntry(k as String, v as String)),
        pushed: ((json['pushed'] as List?) ?? []).cast<String>().toSet(),
        pendingDeletes: ((json['pendingDeletes'] as List?) ?? []).cast<String>().toSet(),
        profilePushed: ((json['profilePushed'] as Map?) ?? {}).map((k, v) => MapEntry(k as String, v as String)),
        lastSyncUtc: json['lastSyncUtc'] == null ? null : DateTime.parse(json['lastSyncUtc'] as String),
      );
}

class SyncStore {
  SyncStore(this._prefs);
  final SharedPreferences _prefs;
  static const _key = 'sync.v1';

  SyncState load() {
    final raw = _prefs.readJson(_key);
    if (raw is Map<String, dynamic>) {
      try {
        return SyncState.fromJson(raw);
      } on Object {
        // corrupted: start clean (everything is re-sent safely because the server is idempotent)
      }
    }
    return const SyncState();
  }

  Future<void> save(SyncState state) => _prefs.writeJson(_key, state.toJson());
  Future<void> clear() => _prefs.remove(_key);
}

/// What the server holds for the signed-in parent: each child with all their progress.
class PulledChild {
  const PulledChild({required this.child, required this.progress, this.achievements = const []});
  final ServerChild child;
  final List<ServerProgress> progress;
  final List<ServerAchievement> achievements;
}

class SyncReport {
  const SyncReport({this.childrenCreated = 0, this.recordsPushed = 0, this.duplicates = 0, this.pulled = const {}, this.newerProfiles = const {}, this.profilesPushed = 0});
  final int childrenCreated;
  final int recordsPushed;
  final int duplicates;
  final int profilesPushed;

  /// Profiles the server holds in a newer version than this phone's (another phone changed them later): the controller applies them.
  final Map<String, ServerChild> newerProfiles;

  /// With `pullBack`: what the server holds for each local child (progress and achievements from every phone).
  final Map<String, PulledChild> pulled;
}

/// Pushes local children and progress to the server. Safe to run repeatedly or after a dropped connection:
/// the server ignores records it already has, and progress is only marked delivered after the server accepted it.
class SyncService {
  SyncService({required this.apiFor, required this.store, required this.tokens, this.batchSize = 100});

  final SyncApi Function(String baseUrl) apiFor;
  final SyncStore store;
  final TokenStore tokens;
  final int batchSize;

  /// [firstName] is the parent's optional first name; both confirmations (parent or guardian aged 18+, privacy policy and terms) are required by the server.
  Future<void> register(String baseUrl, String email, String password, {String firstName = '', bool guardianConfirmed = true, bool termsAccepted = true}) async {
    final api = apiFor(baseUrl);
    final t = await api.register(
      email: email,
      password: password,
      displayName: firstName.trim(),
      guardianConfirmed: guardianConfirmed,
      termsAccepted: termsAccepted,
    );
    await _signedIn(baseUrl, email, t);
  }

  Future<void> login(String baseUrl, String email, String password) async {
    final api = apiFor(baseUrl);
    final t = await api.login(email: email, password: password);
    await _signedIn(baseUrl, email, t);
  }

  /// Sends the 6-digit reset code to [email] (always looks successful: the server never says whether the address has an account).
  Future<void> forgotPassword(String baseUrl, String email) => apiFor(baseUrl).forgotPassword(email);

  Future<void> resetPassword(String baseUrl, String email, String code, String newPassword) =>
      apiFor(baseUrl).resetPassword(email: email, code: code, newPassword: newPassword);

  Future<void> _signedIn(String baseUrl, String email, AuthTokens t) async {
    await tokens.saveRefreshToken(t.refreshToken);
    final previous = store.load();
    // A different account or server must not reuse the old child/record mapping.
    final sameAccount = previous.baseUrl == baseUrl && previous.email == email;
    await store.save(sameAccount ? previous : SyncState(baseUrl: baseUrl, email: email));
  }

  /// Forgets the login only. The child mapping and any queued deletions stay, so signing back in resumes cleanly and a
  /// deletion made while signed out still reaches the server later.
  Future<void> signOut() async => tokens.clear();

  /// Deletes the server account and every record on it, then forgets the account on this device.
  /// Local profiles and progress stay on the device (they belong to the family, not the account).
  Future<void> deleteAccount(String password) async {
    final state = store.load();
    final refreshToken = await tokens.readRefreshToken();
    if (refreshToken == null || state.baseUrl.isEmpty) throw const SyncException(SyncErrorKind.auth, 'Not signed in');
    final api = apiFor(state.baseUrl);
    final auth = await api.refresh(refreshToken);
    await tokens.saveRefreshToken(auth.refreshToken); // tokens rotate: a refused (wrong-password) attempt must not strand the old one
    await api.deleteAccount(auth.accessToken, password);
    await tokens.clear();
    await store.save(SyncState(baseUrl: state.baseUrl));
  }

  /// A local child was deleted: if it had been synced, queue a hard delete of its server copy (profile + all progress).
  /// Returns false when there is nothing on the server to delete (the child was never synced).
  Future<bool> queueChildDelete(String localChildId) async {
    final state = store.load();
    final serverId = state.childMap[localChildId];
    if (serverId == null) return false;
    await store.save(state.copyWith(
      childMap: Map.of(state.childMap)..remove(localChildId),
      pendingDeletes: {...state.pendingDeletes, serverId},
    ));
    return true;
  }

  int get pendingDeleteCount => store.load().pendingDeletes.length;

  /// Sends the queued child deletions. Anything still unconfirmed stays queued for the next attempt.
  Future<int> flushDeletes() async {
    final state = store.load();
    if (state.pendingDeletes.isEmpty) return 0;
    final refreshToken = await tokens.readRefreshToken();
    if (refreshToken == null || state.baseUrl.isEmpty) throw const SyncException(SyncErrorKind.auth, 'Not signed in');
    final api = apiFor(state.baseUrl);
    final auth = await api.refresh(refreshToken);
    await tokens.saveRefreshToken(auth.refreshToken);
    return _deletePending(api, auth.accessToken);
  }

  Future<int> _deletePending(SyncApi api, String accessToken) async {
    var done = 0;
    for (final serverId in store.load().pendingDeletes.toList()) {
      try {
        await api.deleteChild(accessToken, serverId);
      } on SyncException catch (e) {
        if (e.kind != SyncErrorKind.notFound) rethrow; // already gone on the server counts as done
      }
      final current = store.load();
      await store.save(current.copyWith(pendingDeletes: {...current.pendingDeletes}..remove(serverId)));
      done++;
    }
    return done;
  }

  /// Reads the family's children and progress from the server (used right after sign-in, so a new phone shows the same
  /// children). Children that were deleted here and are still waiting to be deleted on the server are not brought back.
  Future<List<PulledChild>> pull() async {
    final state = store.load();
    final refreshToken = await tokens.readRefreshToken();
    if (refreshToken == null || state.baseUrl.isEmpty) throw const SyncException(SyncErrorKind.auth, 'Not signed in');
    final api = apiFor(state.baseUrl);
    final auth = await api.refresh(refreshToken);
    await tokens.saveRefreshToken(auth.refreshToken);
    await _deletePending(api, auth.accessToken);
    final result = <PulledChild>[];
    for (final child in await api.listChildren(auth.accessToken)) {
      result.add(PulledChild(
        child: child,
        progress: await api.listProgress(auth.accessToken, child.id),
        achievements: await api.listAchievements(auth.accessToken, child.id),
      ));
    }
    return result;
  }

  /// Records that a server child now exists on this device as [localChildId], and that the given server records are
  /// already on the server (so the next sync does not send them again).
  Future<void> rememberPulled({required String localChildId, required String serverChildId, required Iterable<String> serverRecordGuids}) async {
    final state = store.load();
    await store.save(state.copyWith(
      childMap: {...state.childMap, localChildId: serverChildId},
      pushed: {...state.pushed, ...serverRecordGuids},
    ));
  }

  /// The server's version of a profile is now this phone's too: it is not sent back.
  Future<void> markProfileKnown(String localChildId, DateTime updatedAt) async {
    final state = store.load();
    await store.save(state.copyWith(profilePushed: {...state.profilePushed, localChildId: updatedAt.toUtc().toIso8601String()}));
  }

  /// True while something on this phone has not reached the server yet: a child never sent, a profile changed since it was sent,
  /// progress records or deletions waiting. (Achievements are always sent as a whole, so they are not counted here.)
  bool hasUnsentChanges({required List<ChildProfile> children, required List<ProgressRecord> progress}) {
    final state = store.load();
    if (state.pendingDeletes.isNotEmpty) return true;
    for (final c in children) {
      if (!state.childMap.containsKey(c.id)) return true;
      if (state.profilePushed[c.id] != (c.updatedAt?.toUtc().toIso8601String() ?? '')) return true;
    }
    return progress.any((r) => !state.pushed.contains(r.clientRecordId));
  }

  Future<bool> isSignedIn() async => (await tokens.readRefreshToken()) != null && store.load().baseUrl.isNotEmpty;

  /// Sends new children, progress and every child's achievements. With [pullBack] it then reads back what the server holds
  /// for each child (the server is the source of truth: results from the family's other phones come back this way).
  Future<SyncReport> syncNow({
    required List<ChildProfile> children,
    required List<ProgressRecord> progress,
    Map<String, List<ServerAchievement>> achievements = const {},
    bool pullBack = false,
  }) async {
    var state = store.load();
    final refreshToken = await tokens.readRefreshToken();
    if (refreshToken == null || state.baseUrl.isEmpty) {
      throw const SyncException(SyncErrorKind.auth, 'Not signed in');
    }
    final api = apiFor(state.baseUrl);

    final auth = await api.refresh(refreshToken); // refresh tokens rotate: persist the new one immediately
    await tokens.saveRefreshToken(auth.refreshToken);

    await _deletePending(api, auth.accessToken); // queued deletions first, so a removed child is never resurrected
    state = store.load();

    var created = 0, pushedCount = 0, duplicates = 0;

    final childMap = Map<String, String>.of(state.childMap);
    for (final child in children) {
      if (childMap.containsKey(child.id)) continue;
      childMap[child.id] = await api.createChild(auth.accessToken,
          name: child.name, avatarKey: child.avatarKey, birthYear: child.birthYear, track: child.track, birthMonth: child.birthMonth, goalMinutes: child.goalMinutes, skills: child.skills, updatedAt: child.updatedAt);
      created++;
      state = state.copyWith(childMap: Map.of(childMap), profilePushed: {...state.profilePushed, child.id: child.updatedAt?.toUtc().toIso8601String() ?? ''});
      await store.save(state); // never create the same child twice, even if a later step fails
    }

    // A profile changed on this phone since it was last sent (name, avatar, birth, track, goal, skills) goes out too. The server keeps the
    // most recent change: when another phone changed it later, what the server holds comes back and is applied here.
    var profilesPushed = 0;
    final newerProfiles = <String, ServerChild>{};
    for (final child in children) {
      final version = child.updatedAt?.toUtc().toIso8601String() ?? '';
      if (state.profilePushed[child.id] == version) continue;
      final answer = await api.updateChild(auth.accessToken, childMap[child.id]!,
          name: child.name, avatarKey: child.avatarKey, birthYear: child.birthYear, track: child.track, birthMonth: child.birthMonth, goalMinutes: child.goalMinutes, skills: child.skills, updatedAt: child.updatedAt);
      profilesPushed++;
      final serverIsNewer = answer.updatedAt != null && (child.updatedAt == null || answer.updatedAt!.isAfter(child.updatedAt!));
      if (serverIsNewer) newerProfiles[child.id] = answer;
      state = state.copyWith(profilePushed: {...state.profilePushed, child.id: serverIsNewer ? answer.updatedAt!.toUtc().toIso8601String() : version});
      await store.save(state);
    }

    final pushed = Set<String>.of(state.pushed);
    for (final child in children) {
      final serverId = childMap[child.id]!;
      final pending = progress.where((r) => r.childId == child.id && !pushed.contains(r.clientRecordId)).toList()
        ..sort((a, b) => a.completedAt.compareTo(b.completedAt));
      for (var i = 0; i < pending.length; i += batchSize) {
        final batch = pending.sublist(i, i + batchSize > pending.length ? pending.length : i + batchSize);
        final result = await api.submitProgress(auth.accessToken, serverId, [
          for (final r in batch)
            {
              'clientRecordId': guidFor(r.clientRecordId),
              'lessonId': r.lessonId,
              'activity': r.activity,
              'stars': r.stars,
              'attempts': r.attempts,
              'timeSpentSeconds': r.timeSpentSeconds,
              'completedAt': r.completedAt.toUtc().toIso8601String(),
            }
        ]);
        pushedCount += result.accepted;
        duplicates += result.duplicates;
        pushed.addAll(batch.map((r) => r.clientRecordId));
        state = state.copyWith(pushed: Set.of(pushed));
        await store.save(state);
      }
    }

    for (final child in children) {
      final items = achievements[child.id];
      if (items != null && items.isNotEmpty) await api.submitAchievements(auth.accessToken, childMap[child.id]!, items);
    }

    final pulled = <String, PulledChild>{};
    if (pullBack) {
      final serverChildren = {for (final c in await api.listChildren(auth.accessToken)) c.id: c};
      for (final child in children) {
        final serverId = childMap[child.id]!;
        pulled[child.id] = PulledChild(
          child: serverChildren[serverId] ?? ServerChild(id: serverId, name: child.name, avatarKey: child.avatarKey, birthYear: child.birthYear, track: child.track, birthMonth: child.birthMonth),
          progress: await api.listProgress(auth.accessToken, serverId),
          achievements: await api.listAchievements(auth.accessToken, serverId),
        );
      }
    }

    await store.save(state.copyWith(lastSyncUtc: DateTime.now().toUtc()));
    return SyncReport(childrenCreated: created, recordsPushed: pushedCount, duplicates: duplicates, pulled: pulled, newerProfiles: newerProfiles, profilesPushed: profilesPushed);
  }
}
