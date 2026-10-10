import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../profiles/child_profile.dart';
import '../progress/progress.dart';
import '../skills/skills.dart';
import '../units/unit_meta.dart';
import 'sync_controller.dart';

/// Where the automatic sync stands, for the small status line in the parent's settings (never shown to the child).
enum SyncStatus {
  /// No account: everything stays on this device and nothing is ever sent.
  off,

  /// Everything is on the server.
  saved,

  /// A sync is running or about to start.
  saving,

  /// Saved on this phone, waiting for the connection (or the server) to send.
  waiting,
}

class AutoSyncState {
  const AutoSyncState({this.status = SyncStatus.off});
  final SyncStatus status;
}

/// When the app may sync by itself: tests turn it off, the real app has it on.
final autoSyncEnabledProvider = Provider<bool>((ref) => true);

/// The connection as a stream of "online" / "offline" (tests give their own).
final connectivityProvider = Provider<Stream<bool>>((ref) => Connectivity().onConnectivityChanged.map((r) => r.any((x) => x != ConnectivityResult.none)));

/// Every timing of the automatic sync in one place (tests make them short).
class AutoSyncTimings {
  const AutoSyncTimings({this.debounce = const Duration(seconds: 4), this.periodic = const Duration(minutes: 5), this.firstRetry = const Duration(seconds: 30), this.maxRetry = const Duration(minutes: 15)});
  final Duration debounce;
  final Duration periodic;
  final Duration firstRetry;
  final Duration maxRetry;
}

final autoSyncTimingsProvider = Provider<AutoSyncTimings>((ref) => const AutoSyncTimings());

/// Sync that runs on its own, without a button: when the app starts and comes back to the front, when the connection returns, a few
/// seconds after any change (so a burst of changes is one sync), and every few minutes while the app is open. A failure is retried with
/// a growing wait. Nothing blocks the screen: it all happens in the background, and every change is already saved on the phone first.
/// With no account it never does anything.
class AutoSyncNotifier extends Notifier<AutoSyncState> {
  Timer? _debounce;
  Timer? _periodic;
  Timer? _retry;
  bool _running = false;
  bool _again = false; // a change arrived while a sync was running: run once more
  bool _online = true;
  int _failures = 0;
  StreamSubscription<bool>? _connection;

  AutoSyncTimings get _t => ref.read(autoSyncTimingsProvider);

  @override
  AutoSyncState build() {
    ref.onDispose(() {
      _debounce?.cancel();
      _periodic?.cancel();
      _retry?.cancel();
      _connection?.cancel();
    });
    return const AutoSyncState();
  }

  /// Called once when the app opens.
  Future<void> start() async {
    if (!ref.read(autoSyncEnabledProvider)) return;
    _connection ??= ref.read(connectivityProvider).listen((online) {
      final back = online && !_online;
      _online = online;
      if (back) _runSoon(const Duration(seconds: 1)); // the connection came back: send what waited
      if (!online && state.status == SyncStatus.saving) state = const AutoSyncState(status: SyncStatus.waiting);
    });
    await ref.read(syncControllerProvider.notifier).refreshStatus();
    if (!ref.read(syncControllerProvider).signedIn) return;
    _startPeriodic();
    await run(pullBack: true);
  }

  void _startPeriodic() {
    _periodic ??= Timer.periodic(_t.periodic, (_) => run(pullBack: true));
  }

  /// Something changed on this phone (a child, progress, a reward): sync shortly, once for a burst of changes.
  void changed() {
    if (!ref.read(autoSyncEnabledProvider)) return;
    if (!ref.read(syncControllerProvider).signedIn) return;
    state = const AutoSyncState(status: SyncStatus.saving);
    _runSoon(_t.debounce);
  }

  /// The app came back to the front.
  void resumed() {
    if (!ref.read(autoSyncEnabledProvider)) return;
    unawaited(() async {
      await ref.read(syncControllerProvider.notifier).refreshStatus();
      if (ref.read(syncControllerProvider).signedIn) {
        _startPeriodic();
        await run(pullBack: true);
      }
    }());
  }

  /// An account was just created or signed in to: start syncing and send everything that is already here.
  Future<void> accountReady() async {
    if (!ref.read(autoSyncEnabledProvider)) return;
    await ref.read(syncControllerProvider.notifier).refreshStatus();
    if (!ref.read(syncControllerProvider).signedIn) return;
    _startPeriodic();
    await run(pullBack: true);
  }

  /// The account was removed or signed out: stop everything.
  void stopped() {
    _debounce?.cancel();
    _periodic?.cancel();
    _periodic = null;
    _retry?.cancel();
    _failures = 0;
    state = const AutoSyncState(status: SyncStatus.off);
  }

  void _runSoon(Duration after) {
    _debounce?.cancel();
    _debounce = Timer(after, () => run());
  }

  /// One sync now. Failures are quiet: the status says it will sync when online, and it tries again later with a growing wait.
  Future<void> run({bool? pullBack}) async {
    if (!ref.read(autoSyncEnabledProvider)) return;
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    _debounce?.cancel();
    _retry?.cancel();
    try {
      final controller = ref.read(syncControllerProvider.notifier);
      state = const AutoSyncState(status: SyncStatus.saving);
      final outcome = await controller.syncQuietly(pullBack: pullBack);
      switch (outcome) {
        case SyncOutcome.skipped:
          state = const AutoSyncState(status: SyncStatus.off);
          _periodic?.cancel();
          _periodic = null;
        case SyncOutcome.done:
          _failures = 0;
          state = const AutoSyncState(status: SyncStatus.saved);
        case SyncOutcome.failed:
          _failures++;
          state = const AutoSyncState(status: SyncStatus.waiting);
          final wait = _t.firstRetry * (1 << (_failures - 1).clamp(0, 10));
          _retry = Timer(wait > _t.maxRetry ? _t.maxRetry : wait, () => run());
      }
    } finally {
      _running = false;
    }
    if (_again) {
      _again = false;
      _runSoon(_t.debounce);
    }
  }
}

final autoSyncProvider = NotifierProvider<AutoSyncNotifier, AutoSyncState>(AutoSyncNotifier.new);

/// Starts the automatic sync with the app, reacts to the app coming back to the front and to every change worth sending.
class AutoSync extends ConsumerStatefulWidget {
  const AutoSync({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AutoSync> createState() => _AutoSyncState();
}

class _AutoSyncState extends ConsumerState<AutoSync> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() async {
      await _convertOldChildren();
      await ref.read(autoSyncProvider.notifier).start();
    });
  }

  /// Children saved before the skills list get the skills that match their old answer (once; the active track is kept).
  Future<void> _convertOldChildren() async {
    try {
      final config = await ref.read(skillsConfigProvider.future);
      await convertOldChildren(
        config: config,
        children: [for (final c in ref.read(profilesProvider)) (id: c.id, skills: c.skills)],
        placedOf: (id) => ref.read(unitMetaProvider).of(id).placed,
        save: (id, skills) => ref.read(profilesProvider.notifier).setSkillsQuietly(id, skills),
      );
    } on Object {
      // the list could not be read: the children stay as they are and it is tried again next start
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) ref.read(autoSyncProvider.notifier).resumed();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(autoSyncProvider.notifier);
    ref.listen(profilesProvider, (_, _) => notifier.changed());
    ref.listen(progressProvider, (_, _) => notifier.changed());
    ref.listen(unitMetaProvider, (_, _) => notifier.changed());
    return widget.child;
  }
}
