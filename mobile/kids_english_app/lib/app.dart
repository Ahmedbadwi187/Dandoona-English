import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/sky.dart';
import 'core/strings.dart';
import 'core/theme.dart';
import 'core/type.dart';
import 'features/settings/settings.dart';
import 'features/splash/dandoona_splash.dart';
import 'router.dart';

class KidsEnglishApp extends ConsumerWidget {
  const KidsEnglishApp({super.key, this.showSplash = false});

  /// Dandoona's animated splash over the app (main.dart turns it on; widget tests leave it off).
  final bool showSplash;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final router = ref.watch(routerProvider);
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
      builder: (context, child) => DandoonaSplash(
        enabled: showSplash,
        child: SkyBackground(
          calm: true,
          // the phone's text size is respected, up to 1.3x in the child area and 1.5x in the parent area
          child: TextScaleArea(
            listenable: router.routerDelegate,
            path: () => router.routerDelegate.currentConfiguration.isEmpty ? '/' : router.routerDelegate.currentConfiguration.uri.path,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
      routerConfig: router,
    );
  }
}
