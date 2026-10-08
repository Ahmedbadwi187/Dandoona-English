import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every self-drawn picture of the later units on one sheet: `flutter test test_screenshots/things_preview_test.dart --update-goldens`.
void main() {
  testWidgets('things sheet', (t) async {
    final root = Directory('../../content/art/little-learners');
    final dirs = ['clothes-1', 'clothes-2', 'clothes-3', 'toys-3', 'my-home-1', 'my-home-2', 'my-home-3', 'opposites-2', 'transport-1', 'transport-2', 'transport-3'];
    final files = [for (final d in dirs) ...(Directory('${root.path}/$d').listSync().whereType<File>().where((f) => f.path.endsWith('.svg')).toList()..sort((a, b) => a.path.compareTo(b.path)))];
    const cols = 6;
    final rows = (files.length / cols).ceil();
    t.view.physicalSize = Size(cols * 220.0, rows * 220.0);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(backgroundColor: const Color(0xFFFDF8E6), body: Wrap(children: [for (final f in files) SizedBox(width: 220, height: 220, child: SvgPicture.file(f))])),
    ));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 800)));
    await t.pump();
    await expectLater(find.byType(Scaffold), matchesGoldenFile('things_sheet.png'));
  });
}
