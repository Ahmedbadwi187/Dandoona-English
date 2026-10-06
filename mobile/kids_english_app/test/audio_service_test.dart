import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/features/audio/audio_service.dart';

void main() {
  test('completes when the player reports the end of the clip', () async {
    final controller = StreamController<Object?>.broadcast();
    final done = firstEventOrTimeout(controller.stream, const Duration(seconds: 30));
    controller.add(null);
    await done;
    await controller.close();
  });

  test('gives up after the timeout instead of throwing or hanging (regression: a wrongly typed onTimeout threw before any clip played)', () async {
    final controller = StreamController<Object?>.broadcast();
    await firstEventOrTimeout(controller.stream, const Duration(milliseconds: 20));
    await controller.close();
  });

  test('works with the typed event stream the audioplayers package exposes', () async {
    final controller = StreamController<int>.broadcast();
    final done = firstEventOrTimeout(controller.stream, const Duration(seconds: 30));
    controller.add(1);
    await done;
    await controller.close();
  });
}
