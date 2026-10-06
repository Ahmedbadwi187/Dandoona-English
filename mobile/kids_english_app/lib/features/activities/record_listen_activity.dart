import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/palette.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../audio/activity_speech.dart';
import '../audio/audio_service.dart';
import '../content/content_models.dart';
import 'activity_logic.dart';

enum _Phase { idle, recording, playing }

/// Hear a word, say it, then hear the original followed by your own recording so you can compare.
/// No scoring and no speech recognition. The recording is a temp file that is deleted right after play-back
/// (and on leaving the screen); it never leaves the device.
class RecordListenActivity extends ConsumerStatefulWidget {
  const RecordListenActivity({
    super.key,
    required this.lesson,
    required this.onFinished,
    this.maxRecording = const Duration(seconds: 5),
  });

  final Lesson lesson;
  final ValueChanged<ActivityResult> onFinished;
  final Duration maxRecording;

  @override
  ConsumerState<RecordListenActivity> createState() => _RecordListenActivityState();
}

class _RecordListenActivityState extends ConsumerState<RecordListenActivity> {
  int _index = 0;
  _Phase _phase = _Phase.idle;
  bool _micUnavailable = false;
  Timer? _cap;
  String? _pendingFile;
  late final RecorderService _recorder = ref.read(recorderServiceProvider);
  late final AudioService _audio = ref.read(audioServiceProvider);
  late final ActivitySpeech _speech = ActivitySpeech(_audio);

  LessonWord get _word => widget.lesson.words[_index];

  /// The clip played and compared: the phrase in the Colors unit ("A red apple."), else the word.
  String get _clip => _word.phrase ?? _word.audio;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_speech.say(instruction: widget.lesson.audio.instructions['record-and-listen'], then: _clip));
    });
  }

  @override
  void dispose() {
    _speech.cancel();
    _cap?.cancel();
    final file = _pendingFile;
    if (file != null) unawaited(_recorder.delete(file)); // never leave a child's voice behind
    super.dispose();
  }

  void _hear() => unawaited(_speech.say(then: _clip));

  Future<void> _toggleRecord() async {
    if (_phase == _Phase.playing) return;
    if (_phase == _Phase.recording) {
      await _stopAndCompare();
      return;
    }
    try {
      if (!await _recorder.requestPermission()) {
        if (mounted) setState(() => _micUnavailable = true);
        return;
      }
      await _recorder.start();
      if (!mounted) return;
      setState(() => _phase = _Phase.recording);
      _cap = Timer(widget.maxRecording, () => unawaited(_stopAndCompare()));
    } on Object {
      if (mounted) setState(() => _micUnavailable = true);
    }
  }

  Future<void> _stopAndCompare() async {
    _cap?.cancel();
    if (_phase != _Phase.recording) return;
    setState(() => _phase = _Phase.playing);
    String? path;
    try {
      path = await _recorder.stop();
    } on Object {
      path = null;
    }
    _pendingFile = path;
    await _audio.playAsset(_clip); // the original first...
    if (path != null && mounted) await _audio.playFile(path); // ...then the child's own voice
    if (path != null) {
      await _recorder.delete(path);
      _pendingFile = null;
    }
    if (!mounted) return;
    if (_index + 1 >= widget.lesson.words.length) {
      widget.onFinished(ActivityResult(stars: 3, attempts: widget.lesson.words.length)); // taking part earns the stars
    } else {
      setState(() {
        _index++;
        _phase = _Phase.idle;
      });
      _hear();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_micUnavailable) return _buildNoMic();
    final recording = _phase == _Phase.recording;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.lesson.words.length; i++)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: i <= _index ? Palette.orange : Palette.tan),
                ),
            ],
          ),
          const SizedBox(height: 20),
          TapToHear(
            key: const Key('word-picture'),
            semanticLabel: _word.word,
            onTap: () {
              if (_phase == _Phase.idle) _hear();
            },
            child: AssetPicture(_word.image, size: 220, semanticLabel: _word.word),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              BigTap(
                onTap: _phase == _Phase.idle ? _hear : null,
                semanticLabel: 'Hear the word',
                child: Container(
                  key: const Key('record-hear'),
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(color: Palette.blue, shape: BoxShape.circle, border: Border.all(color: Palette.ink, width: 4)),
                  child: const Icon(Icons.volume_up_rounded, size: 56, color: Palette.white),
                ),
              ),
              const SizedBox(width: 36),
              BigTap(
                onTap: _phase == _Phase.playing ? null : _toggleRecord,
                semanticLabel: recording ? 'Stop recording' : 'Record your voice',
                child: AnimatedContainer(
                  key: const Key('record-mic'),
                  duration: const Duration(milliseconds: 200),
                  width: recording ? 128 : 104,
                  height: recording ? 128 : 104,
                  decoration: BoxDecoration(
                    color: recording ? Palette.red : Palette.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Palette.ink, width: 4),
                  ),
                  child: Icon(recording ? Icons.stop_rounded : Icons.mic_rounded, size: 60, color: Palette.white),
                ),
              ),
            ],
          ),
          if (_phase == _Phase.playing) ...[
            const SizedBox(height: 24),
            const Icon(Icons.hearing_rounded, size: 48, color: Palette.ink),
          ],
        ],
      ),
    );
  }

  /// No microphone (denied, or not available on this device): the child can still move on; 1 star.
  Widget _buildNoMic() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.mic_off_rounded, size: 96, color: Palette.gray),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('record-skip'),
            style: FilledButton.styleFrom(minimumSize: const Size(kMinTapTarget * 2, kMinTapTarget * 1.2)),
            onPressed: () => widget.onFinished(const ActivityResult(stars: 1, attempts: 0)),
            child: const Icon(Icons.arrow_forward_rounded, size: 40),
          ),
        ],
      ),
    );
  }
}
