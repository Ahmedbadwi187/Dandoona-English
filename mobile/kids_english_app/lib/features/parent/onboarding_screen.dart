import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/palette.dart';
import '../../core/widgets.dart';
import '../content/content_repository.dart';
import '../settings/settings.dart';

/// First launch: welcome (Arabic, RTL) then create the first child profile.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final mascot = ref.watch(contentProvider).maybeWhen(data: (c) => c.mascot, orElse: () => null);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (mascot != null) AssetPicture(mascot, size: 220, semanticLabel: s('appName')),
                  const SizedBox(height: 16),
                  Text(s('appName'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Palette.ink)),
                  const SizedBox(height: 8),
                  Text(s('welcomeTitle'),
                      textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(s('welcomeBody'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, height: 1.5)),
                  const SizedBox(height: 28),
                  FilledButton(
                    key: const Key('onboarding-start'),
                    onPressed: () => context.go('/onboarding/child'),
                    child: Text(s('start')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
