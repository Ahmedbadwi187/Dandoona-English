import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('around sheet', (t) async {
    t.view.physicalSize = const Size(1200, 300);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final files = ['letter-b/ball', 'letter-w/window', 'letter-k/kite', 'letter-e/egg'];
    await t.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(backgroundColor: const Color(0xFFFDF8E6), body: Row(children: [for (final f in files) SizedBox(width: 300, height: 300, child: SvgPicture.file(File('../../content/art/little-learners/$f.svg')))])),
    ));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await t.pump();
    await expectLater(find.byType(Scaffold), matchesGoldenFile('around_sheet.png'));
  });
}
