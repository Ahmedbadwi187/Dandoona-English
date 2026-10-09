import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/loading_action.dart';
import '../../core/palette.dart';
import '../onboarding/onboarding_widgets.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../audio/activity_speech.dart';
import '../audio/audio_service.dart';
import '../content/content_models.dart';
import 'activity_logic.dart';
import 'activity_widgets.dart';
import '../../core/type.dart';

/// "My turn, your turn": Dandoona takes a toy and says its name, then it is the child's turn to take one, and so on until four toys
/// have been taken. Taking turns is the lesson: there is nothing to get wrong, so finishing always gives three stars.
class TurnsActivity extends ConsumerStatefulWidget {
  const TurnsActivity({super.key, required this.lesson, required this.track, required this.onFinished, this.random, this.dandoonaDelay = const Duration(milliseconds: 1400)});

  final Lesson lesson;
  final TrackContent track;
  final FutureOr<void> Function(ActivityResult) onFinished;
  final Random? random;

  /// How long Dandoona takes before it is the child's turn.
  final Duration dandoonaDelay;

  @override
  ConsumerState<TurnsActivity> createState() => _TurnsActivityState();
}

class _TurnsActivityState extends ConsumerState<TurnsActivity> {
  late final List<LessonWord> _toys = ([...unitWordsOf(widget.track, widget.lesson)]..shuffle(widget.random ?? Random())).take(6).toList();
  late final ActivitySpeech _speech;
  static const _turns = 4;
  final List<String> _taken = [];
  bool _dandoonasTurn = true;
  String? _lastDandoona;

  @override
  void initState() {
    super.initState();
    _speech = ActivitySpeech(ref.read(audioServiceProvider));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_dandoonaTakes());
    });
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }

  Future<void> _dandoonaTakes() async {
    final free = _toys.where((t) => !_taken.contains(t.word)).toList();
    final toy = free[(_taken.length * 2 + 1) % free.length];
    setState(() {
      _dandoonasTurn = true;
      _lastDandoona = toy.word;
    });
    unawaited(_speech.say(then: toy.audio));
    await Future<void>.delayed(widget.dandoonaDelay);
    if (!mounted) return;
    setState(() {
      _taken.add(toy.word);
      _dandoonasTurn = false;
    });
    if (_taken.length >= _turns) await _finish();
  }

  Future<void> _childTakes(LessonWord toy) async {
    if (_dandoonasTurn || _taken.contains(toy.word)) return;
    setState(() => _taken.add(toy.word));
    unawaited(_speech.say(then: toy.audio));
    if (_taken.length >= _turns) {
      await _finish();
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (mounted) unawaited(_dandoonaTakes());
  }

  Future<void> _finish() async => await widget.onFinished(const ActivityResult(stars: 3, attempts: _turns));

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          RoundDots(total: _turns, index: max(0, _taken.length - 1)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DandoonaView(pose: _dandoonasTurn ? DandoonaPose.pointingUp : DandoonaPose.waving, size: 96),
              const SizedBox(width: 8),
              Flexible(child: Container(
                key: const Key('turn-badge'),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: _dandoonasTurn ? Palette.orange : Palette.green, borderRadius: BorderRadius.circular(24), border: Border.all(color: Palette.ink, width: 4)),
                child: FittedBox(fit: BoxFit.scaleDown, child: Text(_dandoonasTurn ? 'My turn!' : 'Your turn!', style: kidBody.copyWith(fontWeight: FontWeight.w900, color: Palette.white))),
              )),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            alignment: WrapAlignment.center,
            children: [
              for (final toy in _toys)
                LoadingTap(
                  key: Key('toy-${toy.word}'),
                  onTap: () => _childTakes(toy),
                  child: Opacity(
                    opacity: _taken.contains(toy.word) ? 0.3 : 1,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(minWidth: kMinTapTarget, minHeight: kMinTapTarget),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: _lastDandoona == toy.word && _dandoonasTurn ? Palette.orange : Palette.tan, width: 6),
                      ),
                      child: AssetPicture(toy.image, size: 110, semanticLabel: toy.word),
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
