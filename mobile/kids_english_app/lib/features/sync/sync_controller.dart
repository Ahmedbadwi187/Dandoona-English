import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage.dart';
import '../profiles/child_profile.dart';
import '../progress/progress.dart';
import 'sync_api.dart';
import 'sync_service.dart';

/// Default server address baked in at build time: `--dart-define=API_BASE_URL=https://api.example.com`.
const defaultApiBaseUrl = String.fromEnvironment('API_BASE_URL');

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

  Future<void> signIn(String baseUrl, String email, String password, {bool register = false}) => _run(() async {
        if (register) {
          await _service.register(baseUrl.trim(), email.trim(), password);
        } else {
          await _service.login(baseUrl.trim(), email.trim(), password);
        }
        return 'signedInOk';
      });

  Future<void> syncNow() => _run(() async {
        await _service.syncNow(children: ref.read(profilesProvider), progress: ref.read(progressProvider));
        return 'syncDone';
      });

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

  Future<void> signOut() async {
    await _service.signOut();
    state = state.copyWith(signedIn: false, clearMessage: true);
  }

  Future<void> _run(Future<String> Function() action) async {
    if (state.busy) return;
    state = state.copyWith(busy: true, clearMessage: true);
    try {
      final key = await action();
      state = state.copyWith(busy: false, signedIn: await _service.isSignedIn(), messageKey: key, messageIsError: false);
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
