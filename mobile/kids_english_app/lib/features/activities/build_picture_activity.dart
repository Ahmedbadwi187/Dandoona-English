import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/palette.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../audio/activity_speech.dart';
import '../audio/audio_service.dart';
import '../content/content_models.dart';
import 'activity_logic.dart';

/// One piece of a picture made of shapes: the shape [word] and where it goes on the board (fractions of the board's side).
class BuildPiece {
  const BuildPiece(this.word, this.left, this.top, this.size);
  final String word;
  final double left;
  final double top;
  final double size;
}

/// The pictures children build, by lesson: a house, a robot, a badge. Every shape is a word of that lesson.
const buildRecipes = {
  'shapes-1': [BuildPiece('square', 0.2, 0.42, 0.6), BuildPiece('triangle', 0.12, 0.08, 0.76), BuildPiece('circle', 0.7, 0.0, 0.24)],
  'shapes-2': [BuildPiece('rectangle', 0.22, 0.5, 0.56), BuildPiece('oval', 0.3, 0.16, 0.4), BuildPiece('diamond', 0.4, 0.0, 0.2)],
  'shapes-3': [BuildPiece('heart', 0.16, 0.3, 0.68), BuildPiece('star', 0.36, 0.0, 0.28)],
};

/// Build a picture from shapes: the board shows faint places; the child taps the shapes in the tray and each right shape jumps to the
/// next free place (and says its name). A wrong shape shakes. The pieces of a picture are at most three, so it is quick.
class BuildPictureActivity extends ConsumerStatefulWidget {
  const BuildPictureActivity({super.key, required this.lesson, required this.onFinished, this.random});

  final Lesson lesson;
  final ValueChanged<ActivityResult> onFinished;
  final Random? random;

  @override
  ConsumerState<BuildPictureActivity> createState() => _BuildPictureActivityState();
}

class _BuildPictureActivityState extends ConsumerState<BuildPictureActivity> {
  late final List<BuildPiece> _recipe = buildRecipes[widget.lesson.id] ?? const [];
  late final ActivitySpeech _speech;
  late final List<String> _tray = [for (final p in _recipe) p.word]..shuffle(widget.random ?? Random());
  final Set<String> _placed = {};

  LessonWord? _word(String name) => widget.lesson.words.where((w) => w.word == name).firstOrNull;

  @override
  void initState() {
    super.initState();
    _speech = ActivitySpeech(ref.read(audioServiceProvider));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_speech.say(instruction: widget.lesson.audio.instructions['build-picture']));
    });
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }

  /// Any shape of the tray can go first: it jumps to its own place on the board and says its name.
  Future<void> _tap(String name) async {
    if (_placed.contains(name)) return;
    unawaited(_speech.say(then: _word(name)?.audio));
    setState(() => _placed.add(name));
    if (_placed.length == _recipe.length) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (mounted) widget.onFinished(ActivityResult(stars: 3, attempts: _recipe.length));
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final side = min(constraints.maxWidth - 32, 340.0);
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              key: const Key('build-board'),
              width: side,
              height: side,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), border: Border.all(color: Palette.ink, width: 4)),
              child: Stack(
                children: [
                  for (final (i, p) in _recipe.indexed)
                    Positioned(
                      left: p.left * side,
                      top: p.top * side,
                      width: p.size * side,
                      height: p.size * side,
                      child: Container(
                        key: Key('slot-$i'),
                        decoration: _placed.contains(p.word) ? null : BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Palette.tan, width: 3)),
                        child: _placed.contains(p.word)
                            ? AssetPicture(_word(p.word)!.image, size: p.size * side)
                            : Opacity(opacity: 0.18, child: AssetPicture(_word(p.word)!.image, size: p.size * side)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                for (final name in _tray)
                  if (!_placed.contains(name))
                    GestureDetector(
                      key: Key('piece-$name'),
                      onTap: () => unawaited(_tap(name)),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(minWidth: kMinTapTarget, minHeight: kMinTapTarget),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Palette.tan, width: 6)),
                        child: AssetPicture(_word(name)!.image, size: 110, semanticLabel: name),
                      ),
                    ),
              ],
            ),
          ],
        ),
      );
    });
  }
}
