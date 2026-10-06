import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/features/audio/audio_service.dart';

void main() {
  gateTests();
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

void gateTests() {
  group('ClipGate', () {
    test('a newer clip releases the older waiter', () async {
      final gate = ClipGate();
      var released = false;
      unawaited(gate.open().then((_) => released = true));
      gate.open();
      await Future<void>.delayed(Duration.zero);
      expect(released, isTrue);
    });

    test('stop then play (release twice, then open) never throws', () async {
      final gate = ClipGate();
      gate.open();
      gate.release();
      gate.release(); // stop() after the clip was already released
      gate.open(); // the next clip
      gate.open();
      gate.release();
    });
  });
}
