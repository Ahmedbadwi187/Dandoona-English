import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/palette.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../audio/audio_service.dart';
import '../content/content_models.dart';
import 'activity_logic.dart';

/// Match each sound card to the picture it belongs to: tap a sound (it plays), then tap its picture.
class MatchPictureActivity extends ConsumerStatefulWidget {
  const MatchPictureActivity({super.key, required this.lesson, required this.onFinished, this.random});

  final Lesson lesson;
  final ValueChanged<ActivityResult> onFinished;
  final Random? random;

  @override
  ConsumerState<MatchPictureActivity> createState() => _MatchPictureActivityState();
}

class _MatchPictureActivityState extends ConsumerState<MatchPictureActivity> {
  late final MatchPairs _pairs = buildMatchPairs(widget.lesson, widget.random ?? Random());
  final Set<String> _matched = {};
  String? _selectedSound;
  String? _wrongPicture;
  int _mistakes = 0;

  void _tapSound(LessonWord w) {
    if (_matched.contains(w.word)) return;
    setState(() => _selectedSound = w.word);
    unawaited(ref.read(audioServiceProvider).playAsset(w.audio));
  }

  Future<void> _tapPicture(LessonWord w) async {
    if (_matched.contains(w.word) || _selectedSound == null) return;
    if (_selectedSound == w.word) {
      setState(() {
        _matched.add(w.word);
        _selectedSound = null;
      });
      if (_matched.length == _pairs.pictures.length) {
        await Future<void>.delayed(const Duration(milliseconds: 700));
        if (mounted) widget.onFinished(ActivityResult(stars: starsForMistakes(_mistakes), attempts: _pairs.pictures.length + _mistakes));
      }
    } else {
      _mistakes++;
      setState(() {
        _wrongPicture = w.word;
        _selectedSound = null;
      });
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mounted) setState(() => _wrongPicture = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              for (final w in _pairs.sounds)
                GestureDetector(
                  key: Key('sound-${w.word}'),
                  onTap: () => _tapSound(w),
                  child: Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      color: _matched.contains(w.word) ? Palette.green : Palette.blue,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: _selectedSound == w.word ? Palette.yellow : Palette.ink, width: _selectedSound == w.word ? 8 : 4),
                    ),
                    child: Icon(_matched.contains(w.word) ? Icons.check_rounded : Icons.volume_up_rounded, size: 56, color: Palette.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 36),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              for (final w in _pairs.pictures)
                GestureDetector(
                  key: Key('image-${w.word}'),
                  onTap: () => _tapPicture(w),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(minWidth: kMinTapTarget, minHeight: kMinTapTarget),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: _matched.contains(w.word) ? Palette.green : (_wrongPicture == w.word ? Palette.red : Palette.tan),
                        width: 6,
                      ),
                    ),
                    child: Opacity(opacity: _matched.contains(w.word) ? 0.6 : 1, child: AssetPicture(w.image, size: 140, semanticLabel: w.word)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
