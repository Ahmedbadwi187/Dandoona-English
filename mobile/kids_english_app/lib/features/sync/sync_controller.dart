import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage.dart';
import '../profiles/child_profile.dart';
import '../progress/progress.dart';
import '../settings/settings.dart';
import 'sync_api.dart';
import 'sync_service.dart';

/// The server address the app talks to, baked in at build time: `--dart-define=API_BASE_URL=https://api.example.com`.
/// Debug builds default to the host machine as seen from the Android emulator, so `flutter run` works against a local API.
const _definedApiBaseUrl = String.fromEnvironment('API_BASE_URL');
String get defaultApiBaseUrl => _definedApiBaseUrl.isNotEmpty ? _definedApiBaseUrl : (kDebugMode ? 'http://10.0.2.2:5080' : '');

final syncStoreProvider = Provider<SyncStore>((ref) => SyncStore(ref.read(sharedPreferencesProvider)));
final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());
final syncApiFactoryProvider = Provider<SyncApi Function(String)>((ref) => (url) => HttpSyncApi(url));

final syncServiceProvider = Provider<SyncService>((ref) => SyncService(
      apiFor: ref.read(syncApiFactoryProvider),
      store: ref.read(syncStoreProvider),
      tokens: ref.read(tokenStoreProvider),
    ));

class SyncUiState {
  const SyncUiState({this.busy = false, this.signedIn = false, this.messageKey, this.messageIsError = false});

  final bool busy;
  final bool signedIn;

  /// A strings key (localised by the screen), e.g. 'syncDone'.
  final String? messageKey;
  final bool messageIsError;

  SyncUiState copyWith({bool? busy, bool? signedIn, String? messageKey, bool? messageIsError, bool clearMessage = false}) => SyncUiState(
        busy: busy ?? this.busy,
        signedIn: signedIn ?? this.signedIn,
        messageKey: clearMessage ? null : (messageKey ?? this.messageKey),
        messageIsError: messageIsError ?? this.messageIsError,
      );
}

class SyncController extends Notifier<SyncUiState> {
  @override
  SyncUiState build() => const SyncUiState();

  SyncService get _service => ref.read(syncServiceProvider);

  Future<void> refreshStatus() async {
    final signedIn = await _service.isSignedIn();
    state = state.copyWith(signedIn: signedIn);
  }

  /// Signs in (or creates the account) and brings the family's children and progress from the server to this device.
  Future<void> signIn(String baseUrl, String email, String password, {bool register = false, String firstName = '', bool guardianConfirmed = true, bool termsAccepted = true}) => _run(() async {
        if (register) {
          await _service.register(baseUrl.trim(), email.trim(), password, firstName: firstName, guardianConfirmed: guardianConfirmed, termsAccepted: termsAccepted);
        } else {
          await _service.login(baseUrl.trim(), email.trim(), password);
        }
        await _pullIntoLocal();
        return 'signedInOk';
      });

  /// Local copies of what the server has. A child already known here (by the saved link) is updated, never duplicated.
  Future<void> _pullIntoLocal() async {
    final pulled = await _service.pull();
    final profiles = ref.read(profilesProvider.notifier);
    final progress = ref.read(progressProvider.notifier);
    final childMap = ref.read(syncStoreProvider).load().childMap;
    for (final p in pulled) {
      String? localId;
      for (final e in childMap.entries) {
        if (e.value == p.child.id) localId = e.key;
      }
      localId ??= (await profiles.add(
        name: p.child.name,
        avatarKey: p.child.avatarKey,
        birthYear: p.child.birthYear,
        birthMonth: p.child.birthMonth,
        track: p.child.track,
      ))
          .id;
      await progress.addAll([
        for (final r in p.progress)
          ProgressRecord(
            clientRecordId: r.clientRecordId,
            childId: localId,
            lessonId: r.lessonId,
            activity: r.activity,
            stars: r.stars,
            attempts: r.attempts,
            timeSpentSeconds: r.timeSpentSeconds,
            completedAt: r.completedAt,
          ),
      ]);
      await _service.rememberPulled(localChildId: localId, serverChildId: p.child.id, serverRecordGuids: p.progress.map((r) => r.clientRecordId));
    }
    // A parent who already has children does not start from the "add your first child" screen.
    if (pulled.isNotEmpty) await ref.read(settingsProvider.notifier).completeOnboarding();
  }

  Future<void> syncNow() => _run(() async {
        await _service.syncNow(children: ref.read(profilesProvider), progress: ref.read(progressProvider));
        return 'syncDone';
      });

  /// Sends new children and progress in the background (after an activity, after adding a child). Silent on failure:
  /// everything stays on the device and goes out with the next attempt.
  Future<void> syncQuietly() async {
    if (state.busy) return;
    try {
      if (!await _service.isSignedIn()) return;
      await _service.syncNow(children: ref.read(profilesProvider), progress: ref.read(progressProvider));
      state = state.copyWith();
    } on SyncException {
      // offline or session expired: try again next time
    }
  }

  Future<void> deleteAccount(String password) => _run(() async {
        await _service.deleteAccount(password);
        return 'accountDeleted';
      });

  /// A child profile was deleted on this device: queue (and, if signed in and online, immediately send) the hard delete of
  /// its server copy. Failures are silent here; the deletion stays queued and is retried on the next sync.
  Future<void> childDeleted(String localChildId) async {
    final queued = await _service.queueChildDelete(localChildId);
    if (!queued) return;
    try {
      if (await _service.isSignedIn()) await _service.flushDeletes();
    } on SyncException {
      // offline or signed out: stays queued
    }
    state = state.copyWith(); // let the settings screen refresh its "waiting" count
  }

  /// Signs out. Children and progress stay on this device (the app works without an account); anything not sent yet
  /// is sent first, quietly.
  Future<void> signOut() async {
    await syncQuietly();
    await _service.signOut();
    state = state.copyWith(signedIn: false, clearMessage: true);
  }

  Future<void> _run(Future<String> Function() action) async {
    if (state.busy) return;
    state = state.copyWith(busy: true, clearMessage: true);
    try {
      final key = await action();
      final signedIn = await _service.isSignedIn();
      state = state.copyWith(busy: false, signedIn: signedIn, messageKey: key, messageIsError: false);
    } on SyncException catch (e) {
      final key = switch (e.kind) {
        SyncErrorKind.network => 'syncNetwork',
        SyncErrorKind.auth => 'syncAuth',
        SyncErrorKind.validation => 'syncInvalid',
        SyncErrorKind.notFound || SyncErrorKind.server => 'syncFailed',
      };
      state = state.copyWith(busy: false, messageKey: key, messageIsError: true);
    }
  }
}

final syncControllerProvider = NotifierProvider<SyncController, SyncUiState>(SyncController.new);
