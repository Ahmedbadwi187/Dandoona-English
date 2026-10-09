import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/palette.dart';
import '../../core/sky.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../activities/activity_logic.dart';
import '../activities/demo_steps.dart';
import '../activities/listen_and_tap_activity.dart';
import '../child/child_scope.dart';
import '../content/content_models.dart';
import '../content/content_repository.dart';
import '../onboarding/onboarding_widgets.dart';
import '../profiles/child_profile.dart';
import '../session/session.dart';
import 'map_path.dart';
import 'review_logic.dart';
import 'unit_meta.dart';
import '../../core/type.dart';

/// A review on the map: a quick game with words from the units before it ("Hear the word, tap the picture"). It never fails: a wrong
/// tap just says the word again, and finishing the game passes the review, which opens the next unit.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, required this.reviewId, this.random});

  final String reviewId;
  final Random? random;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  ActivityResult? _result;
  Lesson? _lesson;
  TrackContent? _track;
  bool _prepared = false;

  void _prepare(TrackContent track) {
    if (_prepared) return;
    _prepared = true;
    final units = widget.reviewId == castleId ? [for (final u in track.units) u.id] : (track.reviews.where((r) => r.id == widget.reviewId).firstOrNull?.units ?? const <String>[]);
    _lesson = buildReviewLesson(track, widget.reviewId, units, widget.random ?? Random());
    // The game draws its wrong pictures from the review's own words (a track that is just this lesson uses the lesson's other words).
    if (_lesson != null) _track = TrackContent(track: track.track, units: [CourseUnit(id: 'review', order: 1, title: const {'en': 'Review'}, icon: '', color: '', lessons: [_lesson!])]);
  }

  Future<void> _finished(ActivityResult r) async {
    final childId = ref.read(activeChildIdProvider);
    if (childId != null) await ref.read(unitMetaProvider.notifier).passReview(childId, widget.reviewId);
    if (mounted) setState(() => _result = r);
  }

  @override
  Widget build(BuildContext context) {
    final track = ref.watch(activeContentProvider).asData?.value;
    if (track != null) _prepare(track);
    final lesson = _lesson;

    return ChildScope(
      child: SessionGuard(
        child: Scaffold(
          body: SkyBackground(
            child: SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                      child: IconButton(
                        key: const Key('review-back'),
                        constraints: const BoxConstraints(minWidth: kMinTapTarget, minHeight: kMinTapTarget),
                        iconSize: 32,
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    ),
                  ),
                  Expanded(
                    child: track == null
                        ? const Center(child: CircularProgressIndicator())
                        : lesson == null
                            ? _Nothing(onBack: () => context.pop())
                            : _result != null
                                ? _Passed(stars: _result!.stars, onDone: () => context.pop())
                                : Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                        child: Text(Strings.en('reviewTitle'), key: const Key('review-title'), style: kidBody.copyWith(fontWeight: FontWeight.w900, color: Palette.nightInk)),
                                      ),
                                      Expanded(
                                        child: DemoFrame(
                                          activity: 'listen-and-tap',
                                          instruction: lesson.audio.instructions['listen-and-tap'],
                                          child: ListenAndTapActivity(key: const Key('review-game'), lesson: lesson, track: _track!, onFinished: (r) => unawaited(_finished(r))),
                                        ),
                                      ),
                                    ],
                                  ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Passed extends StatelessWidget {
  const _Passed({required this.stars, required this.onDone});

  final int stars;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          key: const Key('review-passed'),
          mainAxisSize: MainAxisSize.min,
          children: [
            const DandoonaView(pose: DandoonaPose.jumping, size: 220),
            const SizedBox(height: 8),
            Text(Strings.en('reviewPassed'), textAlign: TextAlign.center, style: kidTitle.copyWith(fontWeight: FontWeight.w900, color: Palette.nightInk)),
            const SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [for (var i = 1; i <= 3; i++) Icon(Icons.star_rounded, size: 52, color: i <= stars ? Palette.sunflower : Palette.gray.withValues(alpha: 0.5))],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('review-done'),
                style: FilledButton.styleFrom(backgroundColor: Palette.green, minimumSize: const Size.fromHeight(kMinTapTarget * 1.1)),
                onPressed: onDone,
                child: Text(Strings.en('chestGotIt'), style: kidBody.copyWith(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Nothing extends StatelessWidget {
  const _Nothing({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const DandoonaView(pose: DandoonaPose.thinking, size: 180),
              Text(Strings.en('reviewNotReady'), key: const Key('review-not-ready'), textAlign: TextAlign.center, style: kidBody.copyWith(fontWeight: FontWeight.w800, color: Palette.nightInk)),
              const SizedBox(height: 16),
              FilledButton(onPressed: onBack, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(kMinTapTarget)), child: Text(Strings.en('chestGotIt'), style: kidBody.copyWith(fontWeight: FontWeight.w900))),
            ],
          ),
        ),
      );
}
