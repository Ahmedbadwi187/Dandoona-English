import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/features/parent/settings_screen.dart';
import 'package:kids_english_app/features/sync/sync_controller.dart' show defaultApiBaseUrl;

import 'helpers.dart';

void main() {
  test('the cards address is the server address with /cards, however the address ends', () {
    expect(cardsUrl('https://api.example.com'), 'https://api.example.com/cards');
    expect(cardsUrl('https://api.example.com/'), 'https://api.example.com/cards');
    expect(cardsUrl('http://10.0.2.2:5080//'), 'http://10.0.2.2:5080/cards');
  });

  testWidgets('settings offers the link to the printable cards and copies it', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 1080 / 411;
    addTearDown(t.view.reset);
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final overrides = await testOverrides(content: realContent());
    await t.pumpWidget(ProviderScope(overrides: overrides, child: const MaterialApp(home: SettingsScreen())));
    await t.pumpAndSettle();

    await t.ensureVisible(find.byKey(const Key('cards-link')));
    expect(t.widget<SelectableText>(find.byKey(const Key('cards-link'))).data, '${defaultApiBaseUrl.replaceAll(RegExp(r'/+$'), '')}/cards');
    await t.tap(find.byKey(const Key('cards-copy')));
    await t.pumpAndSettle();
    expect(copied, cardsUrl(defaultApiBaseUrl));
    expect(find.byType(SnackBar), findsOneWidget); // "link copied"
  });
}
