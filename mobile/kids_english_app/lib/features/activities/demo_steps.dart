import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/audio_service.dart';
import 'hand_demo.dart';

/// The games that show their own demo (the Explorers games, through PhonicsGame and the sentence games).
const ownDemoActivities = {
  'sound-tap', 'word-builder', 'spell-it', 'read-and-pick', 'find-the-word', 'sentence-builder', 'fill-the-gap', 'true-or-false', 'sight-word-hunt',
};

/// What the hand does in each of the other games. The pieces are found by the keys the games already give them.
const _tapOption = DemoStep.tapFirst('option-');

const Map<String, List<DemoStep>> _hostedDemos = {
  'listen-and-tap': [DemoStep.tapFirst('hear-again'), _tapOption],
  'animal-sounds': [DemoStep.tapFirst('hear-again'), _tapOption],
  'sentence': [DemoStep.tapFirst('hear-again'), _tapOption],
  'match-picture': [DemoStep.tapFirst('sound-'), DemoStep.tapFirst('image-')],
  'trace': [DemoStep.dragFirst('trace-board', 'trace-board')],
  'trace-small': [DemoStep.dragFirst('trace-board', 'trace-board')],
  'record-and-listen': [DemoStep.tapFirst('record-hear'), DemoStep.tapFirst('record-mic')],
  'dandoona-says': [DemoStep.tapFirst('says-picture'), DemoStep.tapFirst('says-done')],
  'sort': [DemoStep.dragFirst('sort-picture', 'bin-')],
  'memory': [DemoStep.tapFirst('card-0'), DemoStep.tapFirst('card-1')],
  'odd-one-out': [DemoStep.tapFirst('odd-')],
  'count-along': [DemoStep.tapFirst('balloon-'), DemoStep.tapFirst('balloon-')],
  'mix-colors': [DemoStep.tapFirst('mix-option-')],
  'build-picture': [DemoStep.tapFirst('piece-')],
  'turns': [DemoStep.tapFirst('toy-')],
  'story-feeling': [DemoStep.tapFirst('feeling-')],
  'habitat': [DemoStep.tapFirst('habitat-animal'), DemoStep.tapFirst('home-')],
  'color-the-object': [DemoStep.tapFirst('swatch-'), DemoStep.tapFirst('color-drawing')],
};

List<DemoStep> hostedDemoSteps(String activity) => _hostedDemos[activity] ?? const [];

bool hasHostedDemo(String activity) => !ownDemoActivities.contains(activity) && _hostedDemos.containsKey(activity);

/// A game hosted by a screen other than the activity screen (Practice, Review): the same hand demo on open, and a "?" in the corner.
class DemoFrame extends ConsumerStatefulWidget {
  const DemoFrame({super.key, required this.activity, required this.instruction, required this.child});

  final String activity;

  /// The spoken instruction played again by the "?" (null when there is none).
  final String? instruction;
  final Widget child;

  @override
  ConsumerState<DemoFrame> createState() => _DemoFrameState();
}

class _DemoFrameState extends ConsumerState<DemoFrame> {
  late bool _demo = ref.read(autoDemoEveryTimeProvider);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        HandDemo(running: _demo, steps: hostedDemoSteps(widget.activity), onDone: () => setState(() => _demo = false), child: widget.child),
        Positioned(
          right: 8,
          top: 0,
          child: DemoHelpButton(onTap: () async {
            setState(() => _demo = true);
            final line = widget.instruction;
            if (line != null && line.isNotEmpty) await ref.read(audioServiceProvider).playAsset(line);
          }),
        ),
      ],
    );
  }
}
