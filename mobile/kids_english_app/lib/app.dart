import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/strings.dart';
import 'core/theme.dart';
import 'features/settings/settings.dart';
import 'router.dart';

class KidsEnglishApp extends ConsumerWidget {
  const KidsEnglishApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp.router(
      onGenerateTitle: (_) => Strings.forCode(settings.languageCode)('appName'),
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // The parent area follows this locale (Arabic = RTL by default); the child area overrides it to English.
      locale: Locale(settings.languageCode),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(routerProvider),
    );
  }
}
