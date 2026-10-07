import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders the ten balloon pictures on one sheet: `flutter test test_screenshots/numbers_preview_test.dart --update-goldens`.
void main() {
  testWidgets('shapes sheet', (t) async {
    t.view.physicalSize = const Size(1200, 600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    const dirs = {'circle': 'shapes-1', 'square': 'shapes-1', 'triangle': 'shapes-1', 'rectangle': 'shapes-2', 'oval': 'shapes-2', 'diamond': 'shapes-2', 'star': 'shapes-3', 'heart': 'shapes-3'};
    await t.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFFDF8E6),
        body: Wrap(children: [
          for (final e in dirs.entries) SizedBox(width: 300, height: 300, child: SvgPicture.file(File('../../content/art/little-learners/${e.value}/${e.key}.svg'))),
        ]),
      ),
    ));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await t.pump();
    await expectLater(find.byType(Scaffold), matchesGoldenFile('shapes_sheet.png'));
  });
}
