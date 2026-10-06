import 'dart:async';

import 'audio_service.dart';

/// Speaks an activity's instruction and then an optional clip (usually the target word). Any newer call (a tap, a
/// replay) or [cancel] (leaving the screen) stops the rest of the sequence, so a late clip never plays over the child's
/// next action. Missing audio (an old lesson file without instructions) is simply skipped.
class ActivitySpeech {
  ActivitySpeech(this._audio);

  final AudioService _audio;
  int _generation = 0;

  Future<void> say({String? instruction, String? then}) async {
    final mine = ++_generation;
    if (instruction != null) {
      await _audio.playAsset(instruction);
      if (mine != _generation) return;
    }
    if (then != null) await _audio.playAsset(then);
  }

  void cancel() {
    _generation++;
    unawaited(_audio.stop());
  }
}

/// Calls [onIdle] when the child has done nothing for [after]; any interaction should call [arm] again.
class IdleHint {
  IdleHint(this.after, this.onIdle);

  final Duration after;
  final void Function() onIdle;
  Timer? _timer;

  void arm() {
    _timer?.cancel();
    _timer = Timer(after, onIdle);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}
