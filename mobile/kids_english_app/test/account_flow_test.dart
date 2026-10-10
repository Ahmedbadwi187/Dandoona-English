import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/app.dart';
import 'package:kids_english_app/features/onboarding/account_routes.dart';
import 'package:kids_english_app/features/audio/audio_service.dart';
import 'package:kids_english_app/features/profiles/child_profile.dart';
import 'package:kids_english_app/features/router_state.dart';
import 'package:kids_english_app/features/settings/settings.dart';
import 'package:kids_english_app/router.dart';
import 'package:kids_english_app/features/sync/sync_api.dart';
import 'package:kids_english_app/features/sync/sync_controller.dart';
import 'package:kids_english_app/features/sync/sync_service.dart';

import 'helpers.dart';
import 'rewards_sync_test.dart' show FakeSyncApi;

const _settings = '{"languageCode":"en","sessionMinutes":15,"unlockAll":false,"onboarded":false,"languageChosen":true}';

Future<(ProviderContainer, FakeSyncApi)> _start(WidgetTester t, {FakeSyncApi? api, Map<String, Object>? prefs}) async {
  t.view.physicalSize = const Size(1080, 2400); // a phone, so every card is on screen
  t.view.devicePixelRatio = 1080 / 411;
  addTearDown(t.view.reset);
  final fake = api ?? FakeSyncApi();
  final overrides = await testOverrides(prefs: prefs ?? {'settings.v1': _settings});
  final container = ProviderContainer(overrides: [
    ...overrides,
    syncApiFactoryProvider.overrideWithValue((_) => fake),
    tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
    audioServiceProvider.overrideWithValue(FakeAudio()),
  ]);
  addTearDown(container.dispose);
  await t.pumpWidget(UncontrolledProviderScope(container: container, child: const KidsEnglishApp()));
  await t.pumpAndSettle();
  return (container, fake);
}

Future<void> _text(WidgetTester t, String key, String value) async {
  await t.enterText(find.byKey(Key(key)), value);
  await t.pump();
}

/// Ticks a checkbox by its box (the middle of the "I agree" row is the Privacy Policy link).
Future<void> _box(WidgetTester t, String rowKey) async {
  await t.tap(find.descendant(of: find.byKey(Key(rowKey)), matching: find.byType(Checkbox)));
  await t.pump();
}

FilledButton _continue(WidgetTester t) => t.widget<FilledButton>(find.byKey(const Key('ob-continue')));

void main() {
  group('parent welcome', () {
    testWidgets('both options are offered and "start without an account" is the default; continuing adds the first child', (t) async {
      await _start(t);
      expect(find.byKey(const Key('welcome-no-account')), findsOneWidget);
      expect(find.byKey(const Key('welcome-account')), findsOneWidget);
      expect(find.text('Start without an account'), findsOneWidget);
      expect(find.text('Everything stays on this device'), findsNothing); // (the two lines under the options were removed)
      expect(_continue(t).onPressed, isNotNull);

      await t.tap(find.byKey(const Key('ob-continue')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('ob-name')), findsOneWidget);
    });

    testWidgets('choosing the account option leads to the sign-up screen, and back returns to the welcome', (t) async {
      await _start(t);
      await t.tap(find.byKey(const Key('welcome-account')));
      await t.pump();
      await t.tap(find.byKey(const Key('ob-continue')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('auth-email')), findsOneWidget);
      expect(find.byKey(const Key('auth-guardian')), findsOneWidget);

      await t.tap(find.byKey(const Key('ob-back')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('welcome-account')), findsOneWidget);
    });
  });

  group('sign up', () {
    Future<(ProviderContainer, FakeSyncApi)> openSignup(WidgetTester t, {FakeSyncApi? api}) async {
      final r = await _start(t, api: api);
      await t.tap(find.byKey(const Key('welcome-account')));
      await t.pump();
      await t.tap(find.byKey(const Key('ob-continue')));
      await t.pumpAndSettle();
      return r;
    }

    testWidgets('the button stays disabled until the email, a password of 8 characters and BOTH boxes are done', (t) async {
      await openSignup(t);
      expect(_continue(t).onPressed, isNull);

      await _text(t, 'auth-email', 'mom@example.com');
      await _text(t, 'auth-password', 'secret-pass');
      expect(_continue(t).onPressed, isNull); // the boxes are still empty

      await _box(t, 'auth-guardian');
      await t.pump();
      expect(_continue(t).onPressed, isNull); // one box is not enough
      await _box(t, 'auth-agree');
      await t.pump();
      expect(_continue(t).onPressed, isNotNull);

      await _text(t, 'auth-password', 'short');
      expect(_continue(t).onPressed, isNull);
    });

    testWidgets('the first name is optional; sign-up sends both confirmations and then asks for the first child', (t) async {
      final (container, api) = await openSignup(t);
      await _text(t, 'auth-email', 'mom@example.com');
      await _text(t, 'auth-password', 'secret-pass');
      await _text(t, 'auth-name', 'Sara');
      await _box(t, 'auth-guardian');
      await _box(t, 'auth-agree');
      await t.pump();
      await t.tap(find.byKey(const Key('ob-continue')));
      await t.pumpAndSettle();

      expect(api.registrations.single, (email: 'mom@example.com', displayName: 'Sara', guardianConfirmed: true, termsAccepted: true));
      expect(await container.read(syncServiceProvider).isSignedIn(), isTrue);
      expect(find.byKey(const Key('ob-name')), findsOneWidget); // new account, no children yet: add the first one
    });

    testWidgets('the privacy policy and the terms open inside the app, in the parent\'s language', (t) async {
      await openSignup(t);
      // the two names in "I agree to the Privacy Policy and Terms" are links: press them through their own tap handlers
      void pressLink(String label) {
        final rich = t.widget<RichText>(find.descendant(of: find.byKey(const Key('auth-agree')), matching: find.byType(RichText)).first);
        final spans = <TextSpan>[];
        (rich.text as TextSpan).visitChildren((s) {
          if (s is TextSpan && s.text == label) spans.add(s);
          return true;
        });
        (spans.single.recognizer! as TapGestureRecognizer).onTap!();
      }

      pressLink('Privacy Policy');
      await t.pumpAndSettle();
      expect(find.byKey(const Key('legal-text')), findsOneWidget);
      expect(find.textContaining('DRAFT FOR LEGAL REVIEW'), findsWidgets);
      await t.pageBack();
      await t.pumpAndSettle();

      pressLink('Terms');
      await t.pumpAndSettle();
      expect(find.text('Terms of use'), findsWidgets);
      expect(find.textContaining('Who may use the app'), findsOneWidget);
    });
  });

  group('log in', () {
    testWidgets('an account that already has children goes straight to child selection with the family\'s data', (t) async {
      final api = FakeSyncApi()
        ..serverChildren.add(const ServerChild(id: 'srv-1', name: 'Sara', avatarKey: 'rocket', birthYear: 2021, track: 'little-learners'));
      final (container, _) = await _start(t, api: api);
      await t.tap(find.byKey(const Key('welcome-account')));
      await t.pump();
      await t.tap(find.byKey(const Key('ob-continue')));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const Key('ob-secondary'))); // "I already have an account"
      await t.pump();
      await _text(t, 'auth-email', 'mom@example.com');
      await _text(t, 'auth-password', 'secret-pass');
      expect(find.byKey(const Key('auth-guardian')), findsNothing); // no checkboxes when logging in
      await t.tap(find.byKey(const Key('ob-continue')));
      await t.pumpAndSettle();

      expect(find.text('Who is playing?'), findsOneWidget);
      expect(find.text('Sara'), findsOneWidget);
      expect(container.read(profilesProvider).single.name, 'Sara');
      expect(container.read(settingsProvider).onboarded, isTrue);
    });

    testWidgets('a wrong password shows a friendly message and stays on the screen', (t) async {
      final (_, _) = await _start(t, api: FakeSyncApi()..failLogin = true);
      await t.tap(find.byKey(const Key('welcome-account')));
      await t.pump();
      await t.tap(find.byKey(const Key('ob-continue')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('ob-secondary')));
      await t.pump();
      await _text(t, 'auth-email', 'mom@example.com');
      await _text(t, 'auth-password', 'wrong-pass');
      await t.tap(find.byKey(const Key('ob-continue')));
      await t.pumpAndSettle();
      expect(find.text('Wrong email or password'), findsOneWidget);
      expect(find.byKey(const Key('auth-email')), findsOneWidget);
    });
  });

  testWidgets('an account created later from Settings uploads the children and progress already on the phone', (t) async {
    final (container, api) = await _start(t, prefs: {
      'settings.v1': '{"languageCode":"en","sessionMinutes":15,"unlockAll":false,"onboarded":true,"languageChosen":true}',
    });
    await container.read(profilesProvider.notifier).add(name: 'Omar', avatarKey: 'star', birthYear: 2022);
    container.read(parentSessionProvider.notifier).unlock(); // as if the parental gate was passed
    container.read(routerProvider).go('/parent/settings');
    await t.pumpAndSettle();

    await t.scrollUntilVisible(find.byKey(const Key('sync-open-auth')), 200, scrollable: find.byType(Scrollable).first);
    await t.tap(find.byKey(const Key('sync-open-auth')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('auth-guardian')), findsOneWidget);

    await _text(t, 'auth-email', 'mom@example.com');
    await _text(t, 'auth-password', 'secret-pass');
    await _box(t, 'auth-guardian');
    await _box(t, 'auth-agree');
    await t.pump();
    await t.tap(find.byKey(const Key('ob-continue')));
    await t.pumpAndSettle();

    expect(api.createdChildren, ['Omar']); // uploaded
    expect(find.byKey(const Key('auth-email')), findsNothing); // back on Settings
    await t.scrollUntilVisible(find.byKey(const Key('sync-signed-in')), 200, scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const Key('sync-signed-in')), findsOneWidget);
  });

  group('the legal pages in the app', () {
    test('the copies in the assets are identical to the website pages', () {
      for (final f in ['privacy-policy.html', 'terms.html']) {
        expect(File('assets/legal/$f').readAsStringSync(), File('../../site/$f').readAsStringSync(), reason: '$f: copy ../../site/$f into assets/legal');
      }
    });

    test('a language section becomes readable paragraphs (no tags, entities decoded)', () {
      const html = '<section id="en"><h1>Terms &amp; use</h1><p>First <b>bold</b> line.</p><ul><li>One</li><li>Two</li></ul></section><section id="ar"><h1>شروط</h1></section>';
      expect(legalParagraphs(html, 'en'), ['Terms & use', 'First bold line.', '• One', '• Two']);
      expect(legalParagraphs(html, 'ar'), ['شروط']);
    });
  });
}
