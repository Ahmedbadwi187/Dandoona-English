import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../session/session.dart';
import 'activity_logic.dart';
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

  Future<void> _finished(ActivityResult result) async {
    if (_result != null) return;
    setState(() => _result = result);
    final childId = ref.read(activeChildIdProvider);
    if (childId == null) return;
    await ref.read(progressProvider.notifier).record(ProgressRecord(
          clientRecordId: newRecordId(),
          childId: childId,
          lessonId: widget.lesson.id,
          activity: widget.activity,
          stars: result.stars,
          attempts: result.attempts,
          timeSpentSeconds: _stopwatch.elapsed.inSeconds,
          completedAt: ref.read(clockProvider)(),
        ));
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
              ? ActivityResultView(stars: result.stars, lesson: widget.lesson, mascot: widget.track.mascot, onDone: () => context.pop())
              : switch (widget.activity) {
                  'listen-and-tap' => ListenAndTapActivity(lesson: widget.lesson, track: widget.track, onFinished: _finished),
                  'match-picture' => MatchPictureActivity(lesson: widget.lesson, onFinished: _finished),
                  'trace' => TraceActivity(lesson: widget.lesson, onFinished: _finished),
                  'record-and-listen' => RecordListenActivity(lesson: widget.lesson, onFinished: _finished),
                  _ => Center(child: Text(Strings.en('loadError'))),
                },
        ),
      ],
    );
  }
}

String newRecordId() => '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${Random().nextInt(1 << 30).toRadixString(36)}';

/// Celebration: stars pop in one by one, the mascot, and a spoken praise line.
class ActivityResultView extends ConsumerStatefulWidget {
  const ActivityResultView({super.key, required this.stars, required this.lesson, required this.onDone, this.mascot});

  final int stars;
  final Lesson lesson;
  final String? mascot;
  final VoidCallback onDone;

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
