import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// One round of "how does Dandoona feel": the story page that is read, the feeling it is about, and the pictures to choose from.
class FeelingRound {
  const FeelingRound(this.page, this.answer, this.options);
  final StoryPage page;
  final LessonWord answer;
  final List<LessonWord> options;
}

/// The pages of the unit's story that are about exactly one feeling of the unit make the rounds (at most four), with three pictures each.
List<FeelingRound> buildFeelingRounds(Lesson lesson, TrackContent track, Random random, {int max = 4}) {
  final unit = track.unitOfLesson(lesson.id);
  final story = unit?.story;
  if (unit == null || story == null) return const [];
  final feelings = unitWordsOf(track, lesson);
  final rounds = <FeelingRound>[];
  for (final page in story.pages) {
    final names = page.words.toSet();
    if (names.length != 1) continue;
    final answer = feelings.where((w) => w.word == names.first).firstOrNull;
    if (answer == null) continue;
    final others = feelings.where((w) => w.word != answer.word).toList()..shuffle(random);
    rounds.add(FeelingRound(page, answer, [answer, ...others.take(2)]..shuffle(random)));
  }
  rounds.shuffle(random);
  return rounds.take(max).toList();
}

/// "How does Dandoona feel?": the story sentence is read aloud ("Her toy falls. Now she is sad.") and the child chooses the face.
class StoryFeelingActivity extends ConsumerStatefulWidget {
  const StoryFeelingActivity({super.key, required this.lesson, required this.track, required this.onFinished, this.random, this.nextDelay = const Duration(milliseconds: 800)});

  final Lesson lesson;
  final TrackContent track;
  final ValueChanged<ActivityResult> onFinished;
  final Random? random;
  final Duration nextDelay;

  @override
  ConsumerState<StoryFeelingActivity> createState() => _StoryFeelingActivityState();
}

class _StoryFeelingActivityState extends ConsumerState<StoryFeelingActivity> {
  late final List<FeelingRound> _rounds = buildFeelingRounds(widget.lesson, widget.track, widget.random ?? Random());
  late final ActivitySpeech _speech;
  int _index = 0;
  int _mistakes = 0;
  String? _wrong;
  String? _right;
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    _speech = ActivitySpeech(ref.read(audioServiceProvider));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_speech.say(instruction: widget.lesson.audio.instructions['story-feeling'], then: _rounds[_index].page.audio));
    });
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }

  Future<void> _tap(LessonWord w) async {
    if (_locked) return;
    final round = _rounds[_index];
    if (w.word == round.answer.word) {
      _locked = true;
      setState(() => _right = w.word);
      unawaited(_speech.say(then: w.audio));
      await Future<void>.delayed(widget.nextDelay);
      if (!mounted) return;
      if (_index + 1 >= _rounds.length) {
        widget.onFinished(ActivityResult(stars: starsForMistakes(_mistakes), attempts: _rounds.length + _mistakes));
        return;
      }
      setState(() {
        _index++;
        _right = null;
        _locked = false;
      });
      unawaited(_speech.say(then: _rounds[_index].page.audio));
    } else {
      _mistakes++;
      setState(() => _wrong = w.word);
      unawaited(_speech.say(then: round.page.audio));
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mounted) setState(() => _wrong = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final round = _rounds[_index];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          RoundDots(total: _rounds.length, index: _index),
          const SizedBox(height: 12),
          GestureDetector(
            key: const Key('feeling-story'),
            onTap: () => unawaited(_speech.say(then: round.page.audio)),
            child: Column(
              children: [
                const DandoonaView(pose: DandoonaPose.thinking, size: 170),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Palette.nightInk, width: 3)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: Text(round.page.text, style: kidBody.copyWith(fontWeight: FontWeight.w800, color: Palette.nightInk))),
                      const SizedBox(width: 8),
                      const Icon(Icons.volume_up_rounded, color: Palette.plum, size: 30),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            alignment: WrapAlignment.center,
            children: [
              for (final w in round.options)
                GestureDetector(
                  key: Key('feeling-${w.word}'),
                  onTap: () => unawaited(_tap(w)),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(minWidth: kMinTapTarget, minHeight: kMinTapTarget),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: _right == w.word ? Palette.green : (_wrong == w.word ? Palette.red : Palette.tan), width: 6),
                    ),
                    child: AssetPicture(w.image, size: 120, semanticLabel: w.word),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
