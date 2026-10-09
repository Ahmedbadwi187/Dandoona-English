import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../settings/settings.dart';
import 'onboarding_screens.dart';

/// The language of the phone: `ar` when it is Arabic, otherwise `en`. A provider so tests can pretend.
final deviceLanguageProvider = Provider<String>((ref) => ui.PlatformDispatcher.instance.locale.languageCode == 'ar' ? 'ar' : 'en');

/// The very first screen of a fresh install. The phone's language is pre-selected, so one tap confirms it; the choice sets
/// the parent area's language and direction from then on (and is changed later in Settings, behind the parental gate).
class LanguageRoute extends ConsumerStatefulWidget {
  const LanguageRoute({super.key});

  @override
  ConsumerState<LanguageRoute> createState() => _LanguageRouteState();
}

class _LanguageRouteState extends ConsumerState<LanguageRoute> {
  // the phone's language the first time; the language already chosen when the parent comes back to this screen
  late String _selected = ref.read(settingsProvider).languageChosen ? ref.read(settingsProvider).languageCode : ref.read(deviceLanguageProvider);

  @override
  Widget build(BuildContext context) {
    return LanguageScreen(
      selected: _selected,
      onSelect: (code) => setState(() => _selected = code),
      onContinue: () async {
        await ref.read(settingsProvider.notifier).chooseLanguage(_selected);
        if (context.mounted) context.go('/onboarding');
      },
    );
  }
}
