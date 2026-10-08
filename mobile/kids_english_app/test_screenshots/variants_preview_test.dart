import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every generated candidate (both variants of each word) of the lessons named in VARIANT_LESSONS, side by side:
/// `flutter test test_screenshots/variants_preview_test.dart --update-goldens --dart-define=VARIANT_LESSONS=toys-3,my-family-1`.
void main() {
  testWidgets('variants sheet', (t) async {
    const lessons = String.fromEnvironment('VARIANT_LESSONS', defaultValue: 'actions-2,actions-3,toys-2,toys-3');
    final files = <File>[];
    for (final l in lessons.split(',')) {
      final dir = Directory('../../content/generated/little-learners/$l/images/_review');
      if (dir.existsSync()) files.addAll(dir.listSync().whereType<File>().where((f) => f.path.endsWith('.webp')).toList()..sort((a, b) => a.path.compareTo(b.path)));
    }
    final images = <ui.Image>[];
    await t.runAsync(() async {
      for (final f in files) {
        final codec = await ui.instantiateImageCodec(await f.readAsBytes(), targetWidth: 240);
        images.add((await codec.getNextFrame()).image);
      }
    });
    const cols = 6;
    final rows = (files.length / cols).ceil();
    t.view.physicalSize = Size(cols * 250.0, rows * 270.0);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFFDF8E6),
        body: Wrap(children: [
          for (var i = 0; i < files.length; i++)
            SizedBox(width: 250, height: 270, child: Column(children: [RawImage(image: images[i], width: 240, height: 240), Text(files[i].uri.pathSegments.last.replaceAll('.webp', ''), style: const TextStyle(fontSize: 18, color: Colors.black))])),
        ]),
      ),
    ));
    await t.pump();
    await expectLater(find.byType(Scaffold), matchesGoldenFile('variants_sheet.png'));
  });
}
