import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/app.dart';
import 'package:kids_english_app/core/type.dart';
import 'package:kids_english_app/features/audio/audio_service.dart';
import 'package:kids_english_app/features/content/content_models.dart';
import 'package:kids_english_app/features/profiles/child_profile.dart';
import 'package:kids_english_app/features/router_state.dart';
import 'package:kids_english_app/router.dart';

import 'helpers.dart';
import 'pack_content.dart';

/// The phone's text size is respected, but stops at 1.3x in the child area and 1.5x in the parent area, and no key screen overflows there.
const _kids = '[{"id":"c1","name":"Lina","avatarKey":"rocket","birthYear":2022,"track":"little-learners","createdAt":"2026-01-01T00:00:00Z"},'
    '{"id":"c2","name":"Omar","avatarKey":"bear","birthYear":2019,"birthMonth":2,"track":"explorers","createdAt":"2026-01-02T00:00:00Z"}]';

Future<(ProviderContainer, GoRouterLike)> _open(WidgetTester t, {required double systemScale, Size size = const Size(411, 890)}) async {
  t.view.physicalSize = size * 3;
  t.view.devicePixelRatio = 3;
  t.platformDispatcher.textScaleFactorTestValue = systemScale;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  final overrides = await testOverrides(
    content: contentWithPacks(),
    explorers: realExplorersContent(),
    prefs: {
      'settings.v1': '{"languageCode":"en","sessionMinutes":15,"unlockAll":false,"onboarded":true,"languageChosen":true}',
      'children.v1': _kids,
    },
  );
  final c = ProviderContainer(overrides: [...overrides, audioServiceProvider.overrideWithValue(FakeAudio())]);
  addTearDown(c.dispose);
  await t.pumpWidget(UncontrolledProviderScope(container: c, child: const KidsEnglishApp()));
  await t.pumpAndSettle();
  return (c, GoRouterLike(c));
}

class GoRouterLike {
  GoRouterLike(this.c);
  final ProviderContainer c;
  void go(String path) => c.read(routerProvider).go(path);
}

double _scaleAt(WidgetTester t) => MediaQuery.textScalerOf(t.element(find.byType(Scaffold).last)).scale(100) / 100;

void main() {
  test('the two areas are told apart by their routes', () {
    for (final p in ['/who', '/map', '/unit/letters', '/lesson/letter-a/trace', '/practice', '/chest/letters']) {
      expect(isChildRoute(p), isTrue, reason: p);
    }
    for (final p in ['/parent', '/parent/settings', '/onboarding', '/setup/name', '/auth', '/legal/privacy']) {
      expect(isChildRoute(p), isFalse, reason: p);
    }
  });

  const childRoutes = ['/who', '/map', '/unit/letters', '/lesson/letter-a', '/lesson/letter-a/listen-and-tap', '/lesson/letter-a/match-picture', '/practice', '/stickers', '/wardrobe'];
  const parentRoutes = ['/parent', '/parent/settings', '/parent/children', '/parent/child/c1', '/parent/children/c1', '/setup/name'];

  for (final child in ['c1', 'c2']) {
    testWidgets('child area at the largest text size ($child): clamped to 1.3x and nothing overflows', (t) async {
      final (c, router) = await _open(t, systemScale: 3.0);
      c.read(activeChildIdProvider.notifier).select(child);
      for (final r in childRoutes) {
        router.go(r);
        await t.pump();
        await t.pump(const Duration(milliseconds: 600));
        expect(_scaleAt(t), closeTo(kidMaxTextScale, 0.001), reason: r);
        expect(t.takeException(), isNull, reason: 'no overflow at $r');
      }
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 5));
    });
  }

  for (final child in ['c1', 'c2']) {
    testWidgets('a small phone (360 x 640 dp) at the largest text size ($child): the child screens and the parent screens do not overflow', (t) async {
      final (c, router) = await _open(t, systemScale: 3.0, size: const Size(360, 640));
      c.read(activeChildIdProvider.notifier).select(child);
      c.read(parentSessionProvider.notifier).unlock();
      for (final r in [...childRoutes, ...parentRoutes]) {
        router.go(r);
        await t.pump();
        await t.pump(const Duration(milliseconds: 600));
        expect(t.takeException(), isNull, reason: 'no overflow at $r on a small phone');
      }
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 5));
    });
  }

  testWidgets('parent area at the largest text size: clamped to 1.5x and nothing overflows', (t) async {
    final (c, router) = await _open(t, systemScale: 3.0);
    c.read(activeChildIdProvider.notifier).select('c1');
    c.read(parentSessionProvider.notifier).unlock();
    for (final r in parentRoutes) {
      router.go(r);
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      expect(_scaleAt(t), closeTo(parentMaxTextScale, 0.001), reason: r);
      expect(t.takeException(), isNull, reason: 'no overflow at $r');
    }
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('a smaller text size is left alone', (t) async {
    final (c, router) = await _open(t, systemScale: 1.1);
    c.read(activeChildIdProvider.notifier).select('c1');
    router.go('/map');
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(_scaleAt(t), closeTo(1.1, 0.001));
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  });
}
