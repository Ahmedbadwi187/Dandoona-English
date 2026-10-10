import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../profiles/child_profile.dart';
import '../settings/settings.dart';
import '../../core/type.dart';
import '../sync/auto_sync.dart';
import '../sync/sync_api.dart';
import '../sync/sync_controller.dart';
import 'onboarding_screens.dart';

/// Where a parent who finished the welcome (and sign-up, if they chose it) goes to add the first child.
const firstChildRoute = '/onboarding/child';

/// Step 2: start without an account (the default) or create an account / log in.
class ParentWelcomeRoute extends ConsumerStatefulWidget {
  const ParentWelcomeRoute({super.key});

  @override
  ConsumerState<ParentWelcomeRoute> createState() => _ParentWelcomeRouteState();
}

class _ParentWelcomeRouteState extends ConsumerState<ParentWelcomeRoute> {
  bool _withAccount = false;

  @override
  Widget build(BuildContext context) {
    return ParentWelcomeScreen(
      s: ref.watch(stringsProvider),
      withAccount: _withAccount,
      onChoose: (v) => setState(() => _withAccount = v),
      onBack: () => context.go('/language'), // the language can still be changed from here
      onContinue: () {
        if (_withAccount) {
          context.push('/auth');
        } else {
          context.go(firstChildRoute);
        }
      },
    );
  }
}

/// Sign up / log in. Reached from the welcome screen, or from Settings later (`?from=settings`), in which case the
/// children and progress already on this phone are uploaded as soon as the account exists.
class AuthRoute extends ConsumerStatefulWidget {
  const AuthRoute({super.key, this.fromSettings = false});

  final bool fromSettings;

  @override
  ConsumerState<AuthRoute> createState() => _AuthRouteState();
}

class _AuthRouteState extends ConsumerState<AuthRoute> {
  bool _signup = true;
  String _email = '', _password = '', _firstName = '';
  bool _guardian = false, _agreed = false;
  late String _server = ref.read(syncStoreProvider).load().baseUrl.isNotEmpty ? ref.read(syncStoreProvider).load().baseUrl : defaultApiBaseUrl;

  Future<void> _submit() async {
    final controller = ref.read(syncControllerProvider.notifier);
    await controller.signIn(_server, _email, _password, register: _signup, firstName: _firstName, guardianConfirmed: _guardian, termsAccepted: _agreed);
    final ui = ref.read(syncControllerProvider);
    if (!mounted || !ui.signedIn || ui.messageIsError) return;
    unawaited(ref.read(autoSyncProvider.notifier).accountReady()); // from now on it syncs by itself; the children already here go up
    if (widget.fromSettings) {
      await controller.syncNow(); // the children and progress already on this phone go to the new account
      if (mounted) context.pop();
      return;
    }
    // A log-in that brought children goes to child selection; a new account (or one without children) adds the first child.
    context.go(ref.read(profilesProvider).isNotEmpty ? '/who' : firstChildRoute);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final ui = ref.watch(syncControllerProvider);
    return AuthScreen(
      s: s,
      signup: _signup,
      email: _email,
      password: _password,
      firstName: _firstName,
      guardian: _guardian,
      agreed: _agreed,
      busy: ui.busy,
      error: ui.messageIsError && ui.messageKey != null ? s(ui.messageKey!) : null,
      serverUrl: kDebugMode ? _server : null, // development builds only: pick the server (the emulator reaches the PC at 10.0.2.2)
      onServerUrl: (v) => _server = v,
      onToggleMode: () => setState(() => _signup = !_signup),
      onEmail: (v) => setState(() => _email = v),
      onPassword: (v) => setState(() => _password = v),
      onFirstName: (v) => setState(() => _firstName = v),
      onGuardian: (v) => setState(() => _guardian = v),
      onAgreed: (v) => setState(() => _agreed = v),
      onSubmit: _submit,
      onForgot: () => context.push('/forgot-password', extra: (email: _email, server: _server)), // (the address goes in extra, not in the URL)
      onPrivacy: () => context.push('/legal/privacy'),
      onTerms: () => context.push('/legal/terms'),
      onBack: () => context.canPop() ? context.pop() : context.go('/onboarding'),
    );
  }
}

/// Forgot password. The server e-mails a 6-digit code (it answers the same whether or not the address has an account); the parent
/// types the code with a new password and goes back to log in.
class ForgotPasswordRoute extends ConsumerStatefulWidget {
  const ForgotPasswordRoute({super.key, this.email = '', this.server = ''});

  final String email;
  final String server;

  @override
  ConsumerState<ForgotPasswordRoute> createState() => _ForgotPasswordRouteState();
}

class _ForgotPasswordRouteState extends ConsumerState<ForgotPasswordRoute> {
  late String _email = widget.email;
  String _code = '', _password = '';
  bool _codeStep = false, _busy = false;
  String? _error;

  String get _server {
    if (widget.server.isNotEmpty) return widget.server;
    final saved = ref.read(syncStoreProvider).load().baseUrl;
    return saved.isNotEmpty ? saved : defaultApiBaseUrl;
  }

  String _messageFor(Object e, Strings s, {required bool resetting}) {
    if (e is SyncException) {
      return switch (e.kind) {
        SyncErrorKind.network => s('syncNetwork'),
        SyncErrorKind.validation => s(resetting ? 'obCodeInvalid' : 'syncInvalid'),
        _ => s('syncFailed'),
      };
    }
    return s('syncFailed');
  }

  Future<void> _send() async {
    final s = ref.read(stringsProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(syncServiceProvider).forgotPassword(_server, _email.trim());
      if (mounted) setState(() => _codeStep = true);
    } on Object catch (e) {
      if (mounted) setState(() => _error = _messageFor(e, s, resetting: false));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _change() async {
    final s = ref.read(stringsProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(syncServiceProvider).resetPassword(_server, _email.trim(), _code.trim(), _password);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s('obPasswordChanged'))));
      context.canPop() ? context.pop() : context.go('/auth');
    } on Object catch (e) {
      if (mounted) setState(() => _error = _messageFor(e, s, resetting: true));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ForgotPasswordScreen(
      s: ref.watch(stringsProvider),
      codeStep: _codeStep,
      email: _email,
      code: _code,
      password: _password,
      busy: _busy,
      error: _error,
      onEmail: (v) => setState(() => _email = v),
      onCode: (v) => setState(() => _code = v),
      onPassword: (v) => setState(() => _password = v),
      onSend: _send,
      onChange: _change,
      onBack: () => _codeStep ? setState(() => _codeStep = false) : (context.canPop() ? context.pop() : context.go('/auth')),
    );
  }
}

/// The privacy policy and the terms, read inside the app from the same draft pages as the website (copied into the assets;
/// a test keeps the copies identical). Shown in the parent's language.
class LegalScreen extends ConsumerWidget {
  const LegalScreen({super.key, required this.doc});

  /// `privacy` or `terms`.
  final String doc;

  static String assetFor(String doc) => doc == 'terms' ? 'assets/legal/terms.html' : 'assets/legal/privacy-policy.html';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final lang = ref.watch(settingsProvider).languageCode;
    return Directionality(
      textDirection: s.direction,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(s(doc == 'terms' ? 'obTerms' : 'obPrivacy'))),
        body: FutureBuilder<String>(
          future: rootBundle.loadString(assetFor(doc), cache: false),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final paragraphs = legalParagraphs(snapshot.data!, lang);
            return ListView(
              key: const Key('legal-text'),
              padding: const EdgeInsets.all(20),
              children: [
                for (var i = 0; i < paragraphs.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(paragraphs[i], style: (i == 0 ? parentSubtitle : parentBody).copyWith(fontWeight: i == 0 || paragraphs[i].length < 60 ? FontWeight.w800 : FontWeight.w400, height: 1.5)),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The readable paragraphs of one language section of a static page (`<section id="en">` / `id="ar"`).
List<String> legalParagraphs(String html, String lang) {
  final section = RegExp('<section id="$lang"[^>]*>(.*?)</section>', dotAll: true).firstMatch(html)?.group(1) ?? html;
  var t = section
      .replaceAll(RegExp(r'<(style|script)[\s\S]*?</\1>'), '')
      .replaceAll(RegExp(r'<li[^>]*>'), '• ')
      .replaceAll(RegExp(r'</(h1|h2|p|li|tr|div|ul|ol|table)>|<br\s*/?>'), '\n\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&nbsp;', ' ');
  t = t.replaceAll(RegExp(r'[ \t]+'), ' ');
  return t.split(RegExp(r'\n\s*\n')).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
}
