import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/palette.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../audio/activity_speech.dart';
import '../audio/audio_service.dart';
import '../content/content_models.dart';
import 'activity_logic.dart';

/// The homes an animal can be put in, in the order they are shown (the keys are the `home` of a word).
const habitatHomes = [
  HabitatHome('house', Icons.house_rounded, Palette.orange),
  HabitatHome('farm', Icons.agriculture_rounded, Palette.yellow),
  HabitatHome('water', Icons.water_rounded, Palette.blue),
  HabitatHome('wild', Icons.park_rounded, Palette.green),
];

class HabitatHome {
  const HabitatHome(this.key, this.icon, this.color);
  final String key;
  final IconData icon;
  final Color color;
}

/// Where does the animal live? One animal at a time and four homes (house, farm, water, wild). A wrong home is shaken off and the
/// instruction is said again, no scolding; the right home says "A cow lives on the farm." and the next animal comes.
class HabitatActivity extends ConsumerStatefulWidget {
  const HabitatActivity({super.key, required this.lesson, required this.onFinished, this.random, this.nextDelay = const Duration(milliseconds: 600)});

  final Lesson lesson;
  final ValueChanged<ActivityResult> onFinished;
  final Random? random;
  final Duration nextDelay;

  @override
  ConsumerState<HabitatActivity> createState() => _HabitatActivityState();
}

class _HabitatActivityState extends ConsumerState<HabitatActivity> {
  late final Random _random = widget.random ?? Random();
  late final List<LessonWord> _animals = [for (final w in widget.lesson.words) if (w.home != null) w]..shuffle(_random);
  late final ActivitySpeech _speech;
  int _index = 0;
  int _mistakes = 0;
  String? _wrongHome;
  String? _rightHome;
  bool _locked = false;

  LessonWord get _animal => _animals[_index];

  @override
  void initState() {
    super.initState();
    _speech = ActivitySpeech(ref.read(audioServiceProvider));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_speech.say(instruction: widget.lesson.audio.instructions['habitat'], then: _animal.audio));
    });
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }

  Future<void> _tap(HabitatHome home) async {
    if (_locked) return;
    if (home.key == _animal.home) {
      _locked = true;
      setState(() => _rightHome = home.key);
      final lives = _animal.lives;
      await Future.wait([_speech.say(then: lives), Future<void>.delayed(widget.nextDelay)]);
      if (!mounted) return;
      if (_index + 1 >= _animals.length) {
        widget.onFinished(ActivityResult(stars: starsForMistakes(_mistakes), attempts: _animals.length + _mistakes));
      } else {
        setState(() {
          _index++;
          _rightHome = null;
          _locked = false;
        });
        unawaited(_speech.say(instruction: widget.lesson.audio.instructions['habitat'], then: _animal.audio));
      }
    } else {
      _mistakes++;
      setState(() => _wrongHome = home.key);
      unawaited(_speech.say(instruction: widget.lesson.audio.instructions['habitat'], then: _animal.audio));
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mounted) setState(() => _wrongHome = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _animals.length; i++)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: i <= _index ? Palette.orange : Palette.tan),
                ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            key: const Key('habitat-animal'),
            onTap: () => unawaited(_speech.say(then: _animal.audio)),
            child: AssetPicture(_animal.image, size: 190, semanticLabel: _animal.word),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            alignment: WrapAlignment.center,
            children: [
              for (final home in habitatHomes)
                GestureDetector(
                  key: Key('home-${home.key}'),
                  onTap: () => _tap(home),
                  child: Container(
                    width: 150,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    constraints: const BoxConstraints(minHeight: kMinTapTarget),
                    decoration: BoxDecoration(
                      color: home.color.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: _rightHome == home.key ? Palette.green : (_wrongHome == home.key ? Palette.red : home.color), width: _rightHome == home.key ? 10 : 6),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(home.icon, size: 72, color: Palette.ink),
                        Text(Strings.en('habitat_${home.key}'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Palette.ink)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
