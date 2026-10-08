import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/ids.dart';
import '../../core/palette.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../audio/audio_service.dart';
import '../child/child_scope.dart';
import '../content/content_models.dart';
import '../content/content_repository.dart';
import '../profiles/child_profile.dart';
import '../progress/progress.dart';
import '../rewards/accessories.dart';
import '../session/session.dart';
import '../sync/sync_controller.dart';
import '../units/unit_logic.dart';
import '../units/unit_meta.dart';
import 'activity_logic.dart';
import 'color_the_object_activity.dart';
import 'build_picture_activity.dart';
import 'count_along_activity.dart';
import 'memory_activity.dart';
import 'mix_colors_activity.dart';
import 'odd_one_out_activity.dart';
import 'sort_activity.dart';
import 'story_feeling_activity.dart';
import 'turns_activity.dart';
import 'dandoona_says_activity.dart';
import 'habitat_activity.dart';
import 'listen_and_tap_activity.dart';
import 'match_picture_activity.dart';
import 'record_listen_activity.dart';
import 'trace_activity.dart';

/// Hosts one activity of one lesson: times it, saves the result as progress, then shows the stars.
class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key, required this.lessonId, required this.activity});

  final String lessonId;
  final String activity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(contentProvider);
    return ChildScope(
      child: SessionGuard(
        child: Scaffold(
          body: SafeArea(
            child: content.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(Strings.en('loadError'))),
              data: (track) {
                final lesson = track.lessonById(lessonId);
                if (lesson == null || !lesson.activities.contains(activity)) {
                  return Center(child: Text(Strings.en('loadError')));
                }
                return _ActivityHost(lesson: lesson, track: track, activity: activity);
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityHost extends ConsumerStatefulWidget {
  const _ActivityHost({required this.lesson, required this.track, required this.activity});

  final Lesson lesson;
  final TrackContent track;
  final String activity;

  @override
  ConsumerState<_ActivityHost> createState() => _ActivityHostState();
}

class _ActivityHostState extends ConsumerState<_ActivityHost> {
  final _stopwatch = Stopwatch()..start();
  ActivityResult? _result;
  List<Accessory> _unlocked = const [];

  /// Set when this result finished a unit for the first time: the celebration and certificate come before the map.
  String? _celebrateUnit;

  Future<void> _finished(ActivityResult result) async {
    if (_result != null) return;
    setState(() => _result = result);
    final childId = ref.read(activeChildIdProvider);
    if (childId == null) return;
    final progress = ref.read(progressProvider.notifier);
    final before = progress.totalStars(childId);
    await progress.record(ProgressRecord(
          clientRecordId: newRecordId(),
          childId: childId,
          lessonId: widget.lesson.id,
          activity: widget.activity,
          stars: result.stars,
          attempts: result.attempts,
          timeSpentSeconds: _stopwatch.elapsed.inSeconds,
          completedAt: ref.read(clockProvider)(),
        ));
    unawaited(ref.read(syncControllerProvider.notifier).syncQuietly()); // with an account connected, progress goes to the server in the background
    final unit = widget.track.unitOfLesson(widget.lesson.id);
    final firstFinish = unit != null &&
        isUnitFinished(unit, (id) => progress.hasProgress(childId, id)) &&
        !ref.read(unitMetaProvider).of(childId).celebrated.contains(unit.id);
    if (mounted) {
      setState(() {
        _unlocked = newlyUnlocked(before, progress.totalStars(childId));
        if (firstFinish) _celebrateUnit = unit.id;
      });
    }
  }

  void _done() {
    final celebrate = _celebrateUnit;
    if (celebrate != null) {
      context.go('/unit/$celebrate/celebrate');
    } else {
      context.go('/unit/${widget.track.unitOfLesson(widget.lesson.id)?.id ?? widget.track.units.first.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: IconButton(
              key: const Key('activity-back'),
              constraints: const BoxConstraints(minWidth: kMinTapTarget, minHeight: kMinTapTarget),
              iconSize: 32,
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
        ),
        Expanded(
          child: result != null
              ? ActivityResultView(stars: result.stars, lesson: widget.lesson, mascot: widget.track.mascot, unlocked: _unlocked, onDone: _done)
              : switch (widget.activity) {
                  'listen-and-tap' => ListenAndTapActivity(lesson: widget.lesson, track: widget.track, onFinished: _finished),
                  'match-picture' => MatchPictureActivity(lesson: widget.lesson, onFinished: _finished),
                  'trace' => TraceActivity(lesson: widget.lesson, onFinished: _finished),
                  'trace-small' => TraceActivity(lesson: widget.lesson, onFinished: _finished, small: true),
                  'record-and-listen' => RecordListenActivity(lesson: widget.lesson, onFinished: _finished),
                  'animal-sounds' => ListenAndTapActivity(lesson: widget.lesson, track: widget.track, onFinished: _finished, sounds: true),
                  'dandoona-says' => DandoonaSaysActivity(lesson: widget.lesson, onFinished: _finished),
                    'sort' => SortActivity(lesson: widget.lesson, track: widget.track, onFinished: _finished),
                  'memory' => MemoryActivity(lesson: widget.lesson, track: widget.track, onFinished: _finished),
                  'odd-one-out' => OddOneOutActivity(lesson: widget.lesson, track: widget.track, onFinished: _finished),
                  'sentence' => ListenAndTapActivity(lesson: widget.lesson, track: widget.track, onFinished: _finished, sentences: true),
                  'count-along' => CountAlongActivity(lesson: widget.lesson, track: widget.track, onFinished: _finished),
                  'mix-colors' => MixColorsActivity(lesson: widget.lesson, track: widget.track, onFinished: _finished),
                  'build-picture' => BuildPictureActivity(lesson: widget.lesson, onFinished: _finished),
                  'turns' => TurnsActivity(lesson: widget.lesson, track: widget.track, onFinished: _finished),
                  'story-feeling' => StoryFeelingActivity(lesson: widget.lesson, track: widget.track, onFinished: _finished),
                  'habitat' => HabitatActivity(lesson: widget.lesson, onFinished: _finished),
                    'color-the-object' => ColorTheObjectActivity(lesson: widget.lesson, track: widget.track, onFinished: _finished),
                  _ => Center(child: Text(Strings.en('loadError'))),
                },
        ),
      ],
    );
  }
}

String newRecordId() => newUuid();

/// Celebration: stars pop in one by one, the mascot, and a spoken praise line.
class ActivityResultView extends ConsumerStatefulWidget {
  const ActivityResultView({super.key, required this.stars, required this.lesson, required this.onDone, this.mascot, this.unlocked = const []});

  final int stars;
  final Lesson lesson;
  final String? mascot;
  final VoidCallback onDone;

  /// Accessories this result just unlocked (shown with a sparkle so the child sees the reward).
  final List<Accessory> unlocked;

  @override
  ConsumerState<ActivityResultView> createState() => _ActivityResultViewState();
}

class _ActivityResultViewState extends ConsumerState<ActivityResultView> {
  @override
  void initState() {
    super.initState();
    final praise = widget.lesson.audio.praise;
    if (praise.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(ref.read(audioServiceProvider).playAsset(praise[Random().nextInt(praise.length)]));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.mascot != null) AssetPicture(widget.mascot!, size: 180),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++)
                  TweenAnimationBuilder<double>(
                    key: Key('result-star-$i'),
                    tween: Tween(begin: 0, end: i < widget.stars ? 1 : 0.35),
                    duration: Duration(milliseconds: 400 + i * 300),
                    curve: Curves.elasticOut,
                    builder: (context, scale, _) => Transform.scale(
                      scale: scale.clamp(0.0, 1.4).toDouble(),
                      child: Icon(Icons.star_rounded, size: 84, color: i < widget.stars ? Palette.yellow : Palette.tan),
                    ),
                  ),
              ],
            ),
            if (widget.unlocked.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                key: const Key('new-accessory'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: Palette.yellow, size: 40),
                  for (final a in widget.unlocked)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: Palette.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Palette.yellow, width: 5),
                      ),
                      child: Padding(padding: const EdgeInsets.all(6), child: SvgPicture.asset(a.assetPath)),
                    ),
                  const Icon(Icons.auto_awesome_rounded, color: Palette.yellow, size: 40),
                ],
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('result-done'),
              style: FilledButton.styleFrom(
                backgroundColor: Palette.green,
                minimumSize: const Size(kMinTapTarget * 2, kMinTapTarget * 1.2),
              ),
              onPressed: widget.onDone,
              child: const Icon(Icons.check_rounded, size: 44, color: Palette.white),
            ),
          ],
        ),
      ),
    );
  }
}
