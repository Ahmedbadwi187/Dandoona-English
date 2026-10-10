import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/app.dart';
import 'package:kids_english_app/features/audio/audio_service.dart';
import 'package:kids_english_app/features/sync/sync_controller.dart';
import 'package:kids_english_app/features/sync/sync_service.dart';

import 'helpers.dart';
import 'rewards_sync_test.dart' show FakeSyncApi;

const _settings = '{"languageCode":"en","sessionMinutes":15,"unlockAll":false,"onboarded":false,"languageChosen":true}';

Future<FakeSyncApi> _toLogin(WidgetTester t, {FakeSyncApi? api}) async {
  t.view.physicalSize = const Size(1080, 2400);
  t.view.devicePixelRatio = 1080 / 411;
  addTearDown(t.view.reset);
  final fake = api ?? FakeSyncApi();
  final overrides = await testOverrides(prefs: {'settings.v1': _settings});
  final c = ProviderContainer(overrides: [
    ...overrides,
    syncApiFactoryProvider.overrideWithValue((_) => fake),
    tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
    audioServiceProvider.overrideWithValue(FakeAudio()),
  ]);
  addTearDown(c.dispose);
  await t.pumpWidget(UncontrolledProviderScope(container: c, child: const KidsEnglishApp()));
  await t.pumpAndSettle();
  await t.tap(find.byKey(const Key('welcome-account')));
  await t.pump();
  await t.tap(find.byKey(const Key('ob-continue')));
  await t.pumpAndSettle();
  await t.tap(find.byKey(const Key('ob-secondary'))); // "I already have an account"
  await t.pump();
  return fake;
}

Future<void> _text(WidgetTester t, String key, String value) async {
  await t.enterText(find.byKey(Key(key)), value);
  await t.pump();
}

void main() {
  testWidgets('the link is only on the log-in form, not on sign-up', (t) async {
    await _toLogin(t);
    expect(find.byKey(const Key('auth-forgot')), findsOneWidget);
    await t.tap(find.byKey(const Key('ob-secondary'))); // back to sign-up
    await t.pump();
    expect(find.byKey(const Key('auth-forgot')), findsNothing);
  });

  testWidgets('email, then the 6-digit code with a new password, then back to log in', (t) async {
    final api = await _toLogin(t);
    await _text(t, 'auth-email', 'mom@example.com');
    await t.tap(find.byKey(const Key('auth-forgot')));
    await t.pumpAndSettle();

    // step 1: the address is already there; the button waits for a valid one
    expect(find.text('Reset your password'), findsOneWidget);
    await t.tap(find.byKey(const Key('ob-continue')));
    await t.pumpAndSettle();
    expect(api.forgotten, ['mom@example.com']);

    // step 2: the code and a new password; the button waits for both
    expect(find.byKey(const Key('forgot-code')), findsOneWidget);
    await _text(t, 'forgot-code', '123456');
    await _text(t, 'forgot-password', 'short');
    expect(t.widget<FilledButton>(find.byKey(const Key('ob-continue'))).onPressed, isNull);

    await _text(t, 'forgot-code', '000000');
    await _text(t, 'forgot-password', 'a-new-password');
    await t.tap(find.byKey(const Key('ob-continue')));
    await t.pumpAndSettle();
    expect(find.text('The code is wrong or has expired, or the password is shorter than 8 characters.'), findsOneWidget); // a wrong code says so

    await _text(t, 'forgot-code', '123456');
    await t.tap(find.byKey(const Key('ob-continue')));
    await t.pumpAndSettle();
    expect(api.passwordSetTo, 'a-new-password');
    expect(find.text('Password changed. Log in with it.'), findsOneWidget);
    expect(find.byKey(const Key('auth-email')), findsOneWidget); // back on the log-in form
  });

  testWidgets('offline: a clear message, and the parent can try again', (t) async {
    final api = await _toLogin(t, api: FakeSyncApi()..offline = true);
    await t.tap(find.byKey(const Key('auth-forgot')));
    await t.pumpAndSettle();
    await _text(t, 'forgot-email', 'mom@example.com');
    await t.tap(find.byKey(const Key('ob-continue')));
    await t.pumpAndSettle();
    expect(find.text('Could not reach the server'), findsOneWidget);
    expect(find.byKey(const Key('forgot-email')), findsOneWidget);
    api.offline = false;
    await t.tap(find.byKey(const Key('ob-continue')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('forgot-code')), findsOneWidget);
  });
}
