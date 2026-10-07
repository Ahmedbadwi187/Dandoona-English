import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/core/palette.dart';
import 'package:kids_english_app/core/widgets.dart';

void main() {
  test('a parent can pick Dandoona or one of six friends: eight drawn avatars, all with their picture in the app', () {
    final keys = AvatarOption.pickable.map((a) => a.key).toList();
    expect(keys, ['dandoona', 'bunny', 'cat', 'bear', 'owl', 'goldfish', 'puppy', 'penguin']);
    for (final a in AvatarOption.pickable) {
      expect(a.asset, isNotNull, reason: a.key);
      expect(File(a.asset!).existsSync(), isTrue, reason: '${a.key}: ${a.asset}');
    }
  });

  test('children created with the older icon avatars keep their color and now show a matching character; an unknown key falls back to a valid avatar', () {
    const expected = {'star': ('cat', Palette.yellow), 'rocket': ('puppy', Palette.red), 'flower': ('bunny', Palette.pink), 'sun': ('bear', Palette.orange), 'leaf': ('frog', Palette.green), 'fish': ('fish', Palette.teal), 'cloud': ('penguin', Palette.blue), 'moon': ('owl', Palette.purple)};
    for (final a in AvatarOption.legacy) {
      final (character, color) = expected[a.key]!;
      expect(a.color, color, reason: '${a.key} keeps its color');
      expect(a.asset, 'assets/images/avatars/$character.svg', reason: a.key);
      expect(File(a.asset!).existsSync(), isTrue, reason: a.asset);
    }
    expect(AvatarOption.legacy, hasLength(8));
    expect(AvatarOption.byKey('does-not-exist'), AvatarOption.all.first);
    expect(AvatarOption.all.map((a) => a.key).toSet().length, AvatarOption.all.length, reason: 'keys must be unique');
  });

  testWidgets('every avatar draws (drawn friends and the older icons)', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Wrap(children: [for (final a in AvatarOption.all) AvatarCircle(a.key, size: 60)]),
      ),
    ));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
    await t.pump();
    expect(find.byType(AvatarCircle), findsNWidgets(AvatarOption.all.length));
    expect(t.takeException(), isNull);
  });
}
