import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/loading_action.dart';
import '../../core/palette.dart';
import '../audio/activity_speech.dart';
import '../audio/audio_service.dart';
import '../content/content_models.dart';
import 'activity_logic.dart';
import 'activity_widgets.dart';
import '../../core/type.dart';

/// Which two colors make which (the colors a child can really mix).
const colorRecipes = {
  'orange': ['red', 'yellow'],
  'green': ['blue', 'yellow'],
  'purple': ['red', 'blue'],
  'pink': ['red', 'white'],
};

Color _hex(String hex) => Color(int.parse('FF${hex.substring(1)}', radix: 16));

/// One color of the Colors unit by its name (its lesson carries the name, the hex value and how it is said).
Lesson? colorLesson(TrackContent track, String name) {
  for (final l in track.lessons) {
    if (l.color?.name.toLowerCase() == name) return l;
  }
  return null;
}

/// Mixing colors: two colors come together, the child chooses which color they make. The lesson's own color is the first mix, then
/// one more. A right answer shows the mix and says the color; a wrong one gently shakes.
class MixColorsActivity extends ConsumerStatefulWidget {
  const MixColorsActivity({super.key, required this.lesson, required this.track, required this.onFinished, this.random, this.nextDelay = const Duration(milliseconds: 900)});

  final Lesson lesson;
  final TrackContent track;
  final FutureOr<void> Function(ActivityResult) onFinished;
  final Random? random;
  final Duration nextDelay;

  @override
  ConsumerState<MixColorsActivity> createState() => _MixColorsActivityState();
}

class _MixColorsActivityState extends ConsumerState<MixColorsActivity> {
  late final Random _random = widget.random ?? Random();
  late final ActivitySpeech _speech;
  late final List<String> _mixes = _pickMixes();
  int _index = 0;
  int _mistakes = 0;
  String? _wrong;
  bool _mixed = false;

  List<String> _pickMixes() {
    final own = widget.lesson.color?.name.toLowerCase();
    final first = own != null && colorRecipes.containsKey(own) ? own : colorRecipes.keys.first;
    final others = colorRecipes.keys.where((k) => k != first).toList()..shuffle(_random);
    return [first, others.first];
  }

  String get _result => _mixes[_index];

  late List<String> _options = _optionsFor(_result);

  List<String> _optionsFor(String result) {
    final wrong = ['red', 'blue', 'yellow', 'green', 'orange', 'purple', 'pink', 'brown'].where((c) => c != result && !colorRecipes[result]!.contains(c)).toList()..shuffle(_random);
    return [result, wrong[0], wrong[1]]..shuffle(_random);
  }

  @override
  void initState() {
    super.initState();
    _speech = ActivitySpeech(ref.read(audioServiceProvider));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_speech.say(instruction: widget.lesson.audio.instructions['mix-colors']));
    });
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }

  Color _color(String name) => _hex(colorLesson(widget.track, name)?.color?.hex ?? '#888888');

  Future<void> _choose(String name) async {
    if (_mixed) return;
    if (name == _result) {
      setState(() => _mixed = true);
      unawaited(_speech.say(then: colorLesson(widget.track, name)?.audio.colorName));
      await Future<void>.delayed(widget.nextDelay);
      if (!mounted) return;
      if (_index + 1 >= _mixes.length) {
        await widget.onFinished(ActivityResult(stars: starsForMistakes(_mistakes), attempts: _mixes.length + _mistakes));
        return;
      }
      setState(() {
        _index++;
        _mixed = false;
        _options = _optionsFor(_result);
      });
    } else {
      _mistakes++;
      setState(() => _wrong = name);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mounted) setState(() => _wrong = null);
    }
  }

  Widget _blob(Color c, {double size = 70, Key? key}) =>
      Container(key: key, width: size, height: size, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Palette.ink, width: 5)));

  @override
  Widget build(BuildContext context) {
    final recipe = colorRecipes[_result]!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          RoundDots(total: _mixes.length, index: _index),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _blob(_color(recipe[0]), key: const Key('mix-a')),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.add_rounded, size: 32, color: Palette.ink)),
              _blob(_color(recipe[1]), key: const Key('mix-b')),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.drag_handle_rounded, size: 32, color: Palette.ink)),
              _mixed ? _blob(_color(_result), key: const Key('mix-result')) : Container(key: const Key('mix-result'), width: 70, height: 70, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Palette.ink, width: 5)), child: Text('?', style: kidGameWord.copyWith(fontWeight: FontWeight.w900, color: Palette.ink))),
            ],
          ),
          const SizedBox(height: 40),
          Wrap(
            spacing: 18,
            runSpacing: 18,
            alignment: WrapAlignment.center,
            children: [
              for (final name in _options)
                LoadingTap(
                  key: Key('mix-option-$name'),
                  onTap: () => _choose(name),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(60), border: Border.all(color: _wrong == name ? Palette.red : Palette.tan, width: 6)),
                    child: _blob(_color(name), size: 100),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
