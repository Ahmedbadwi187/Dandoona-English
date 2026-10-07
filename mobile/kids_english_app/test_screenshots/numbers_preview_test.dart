import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders the ten balloon pictures on one sheet: `flutter test test_screenshots/numbers_preview_test.dart --update-goldens`.
void main() {
  testWidgets('numbers sheet', (t) async {
    t.view.physicalSize = const Size(1500, 600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    const dirs = {'one': 'number-1-3', 'two': 'number-1-3', 'three': 'number-1-3', 'four': 'number-4-6', 'five': 'number-4-6', 'six': 'number-4-6', 'seven': 'number-7-10', 'eight': 'number-7-10', 'nine': 'number-7-10', 'ten': 'number-7-10'};
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
    await expectLater(find.byType(Scaffold), matchesGoldenFile('numbers_sheet.png'));
  });
}
