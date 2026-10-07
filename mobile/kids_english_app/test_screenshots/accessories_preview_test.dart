import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dandoona wearing every accessory drawn in content/art/accessories, on one sheet:
/// `flutter test test_screenshots/accessories_preview_test.dart --update-goldens`.
void main() {
  testWidgets('accessories sheet', (t) async {
    final files = Directory('../../content/art/accessories').listSync().whereType<File>().where((f) => f.path.endsWith('.svg')).toList()..sort((a, b) => a.path.compareTo(b.path));
    final cols = 4;
    final rows = (files.length / cols).ceil();
    t.view.physicalSize = Size(cols * 280.0, rows * 300.0);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFE9F6FB),
        body: Wrap(children: [
          for (final f in files)
            SizedBox(
              width: 280,
              height: 300,
              child: Column(children: [
                SizedBox(width: 260, height: 260, child: Stack(children: [Image.asset('assets/images/mascot/mascot.webp', width: 260, height: 260), Positioned.fill(child: SvgPicture.file(f))])),
                Text(f.uri.pathSegments.last.replaceAll('.svg', ''), style: const TextStyle(fontSize: 16, color: Colors.black)),
              ]),
            ),
        ]),
      ),
    ));
    await t.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 600));
    });
    await t.pump();
    await expectLater(find.byType(Scaffold), matchesGoldenFile('accessories_sheet.png'));
  });
}
