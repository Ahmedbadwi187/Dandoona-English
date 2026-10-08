import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// The drawings of the Word Families unit on one sheet: `flutter test test_screenshots/families_preview_test.dart --update-goldens`.
void main() {
  testWidgets('word families sheet', (t) async {
    final files = Directory('../../content/art/explorers').listSync(recursive: true).whereType<File>().where((f) => f.path.contains('word-families') && f.path.endsWith('.svg')).toList()..sort((a, b) => a.path.compareTo(b.path));
    const cols = 4;
    final rows = (files.length / cols).ceil();
    t.view.physicalSize = Size(cols * 260.0, rows * 290.0);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Wrap(children: [
          for (final f in files)
            SizedBox(width: 260, height: 290, child: Column(children: [SvgPicture.file(f, width: 250, height: 250), Text(f.uri.pathSegments.last, style: const TextStyle(fontSize: 14, color: Colors.black))])),
        ]),
      ),
    ));
    await t.runAsync(() async => Future<void>.delayed(const Duration(milliseconds: 500)));
    await t.pump();
    await expectLater(find.byType(Scaffold), matchesGoldenFile('families_sheet.png'));
  });
}
