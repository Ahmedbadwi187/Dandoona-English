import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/loading_action.dart';
import '../../core/palette.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../gate/parental_gate.dart';
import '../settings/settings.dart';
import '../../core/type.dart';

/// Seconds of play in the current session (in memory; a new app launch starts a fresh session).
class SessionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void tick([int seconds = 1]) => state += seconds;
  void reset() => state = 0;
}

final sessionSecondsProvider = NotifierProvider<SessionNotifier, int>(SessionNotifier.new);

/// True once the parent's session limit is reached.
final sessionOverProvider = Provider<bool>((ref) {
  final limit = ref.watch(settingsProvider).sessionMinutes * 60;
  return ref.watch(sessionSecondsProvider) >= limit;
});

/// Wraps the child area: counts play time while the app is in the foreground and, when the parent's limit
/// is reached, covers the screen until an adult passes the parental gate.
class SessionGuard extends ConsumerStatefulWidget {
  const SessionGuard({super.key, required this.child, this.tickEvery = const Duration(seconds: 1)});

  final Widget child;
  final Duration tickEvery;

  @override
  ConsumerState<SessionGuard> createState() => _SessionGuardState();
}

class _SessionGuardState extends ConsumerState<SessionGuard> with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.tickEvery, (_) {
      if (!ref.read(sessionOverProvider)) ref.read(sessionSecondsProvider.notifier).tick();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only foreground time counts.
    if (state == AppLifecycleState.resumed) {
      _start();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final over = ref.watch(sessionOverProvider);
    return Stack(
      children: [
        widget.child,
        if (over) const Positioned.fill(child: _TimeUpOverlay()),
      ],
    );
  }
}

class _TimeUpOverlay extends ConsumerWidget {
  const _TimeUpOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return Material(
      key: const Key('time-up-overlay'),
      color: Palette.ink.withValues(alpha: 0.92),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            // The child sees English; the adult-facing continue button follows the parent's language.
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bedtime_rounded, color: Palette.yellow, size: 96),
                const SizedBox(height: 16),
                Text(Strings.en('timeUpTitle'),
                    textAlign: TextAlign.center,
                    style: kidTitle.copyWith(color: Palette.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(Strings.en('timeUpBody'),
                    textAlign: TextAlign.center, style: kidCaption.copyWith(color: Palette.cream)),
                const SizedBox(height: 28),
                LoadingAction(
                  onPressed: () async {
                    final passed = await showParentalGate(context);
                    if (context.mounted && passed) ref.read(sessionSecondsProvider.notifier).reset();
                  },
                  builder: (onPressed, loading) => FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(kMinTapTarget * 3, kMinTapTarget)),
                    onPressed: onPressed,
                    child: LoadingContent(loading: loading, child: Text(s('continue'))),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
