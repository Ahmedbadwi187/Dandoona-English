import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/palette.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../gate/parental_gate.dart';
import '../profiles/child_profile.dart';
import '../router_state.dart';
import 'child_scope.dart';

/// "Who is playing?" Big avatars to tap; the small lock button leads to the parent area through the gate.
class ProfilePickerScreen extends ConsumerStatefulWidget {
  const ProfilePickerScreen({super.key});

  @override
  ConsumerState<ProfilePickerScreen> createState() => _ProfilePickerScreenState();
}

class _ProfilePickerScreenState extends ConsumerState<ProfilePickerScreen> {
  @override
  void initState() {
    super.initState();
    // Arriving here always closes any open parent session and the active child.
    Future.microtask(() {
      if (!mounted) return;
      ref.read(parentSessionProvider.notifier).lock();
      ref.read(activeChildIdProvider.notifier).select(null);
    });
  }

  Future<void> _openParentArea() async {
    if (await showParentalGate(context) && mounted) {
      ref.read(parentSessionProvider.notifier).unlock();
      context.go('/parent');
    }
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(profilesProvider);
    return ChildScope(
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(Strings.en('whoIsPlaying'),
                          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Palette.ink)),
                      const SizedBox(height: 28),
                      Wrap(
                        spacing: 28,
                        runSpacing: 28,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final p in profiles)
                            GestureDetector(
                              key: Key('pick-${p.id}'),
                              onTap: () {
                                ref.read(activeChildIdProvider.notifier).select(p.id);
                                context.go('/map');
                              },
                              child: Column(
                                children: [
                                  AvatarCircle(p.avatarKey, size: 128),
                                  const SizedBox(height: 8),
                                  Text(p.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  key: const Key('open-parent-area'),
                  constraints: const BoxConstraints(minWidth: kMinTapTarget, minHeight: kMinTapTarget),
                  iconSize: 32,
                  color: Palette.gray,
                  tooltip: 'Parents',
                  onPressed: _openParentArea,
                  icon: const Icon(Icons.lock_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
