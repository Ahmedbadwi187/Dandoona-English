import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/palette.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../content/content_repository.dart';
import '../profiles/child_profile.dart';
import '../progress/progress.dart';
import '../session/session.dart';
import 'child_scope.dart';

/// One lesson: the big letter, its pictures, and the four activity tiles (the activities themselves arrive in Phase 3).
class LessonScreen extends ConsumerWidget {
  const LessonScreen({super.key, required this.lessonId});

  final String lessonId;

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
                if (lesson == null) return Center(child: Text(Strings.en('loadError')));
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        key: const Key('lesson-back'),
                        constraints: const BoxConstraints(minWidth: kMinTapTarget, minHeight: kMinTapTarget),
                        iconSize: 32,
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          color: Palette.nodeColors[(lesson.order - 1) % Palette.nodeColors.length],
                          shape: BoxShape.circle,
                          border: Border.all(color: Palette.ink, width: 6),
                        ),
                        alignment: Alignment.center,
                        child: Text(lesson.letter ?? '?',
                            key: const Key('lesson-letter'),
                            style: const TextStyle(fontSize: 110, fontWeight: FontWeight.w900, color: Palette.white)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final w in lesson.words)
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AssetPicture(w.image, size: 150, semanticLabel: w.word),
                              const SizedBox(height: 4),
                              Text(w.word, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final a in lesson.activities)
                          _ActivityTile(lessonId: lesson.id, activity: a, stars: _bestStars(ref, lesson.id, a)),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

const _activityIcons = {
  'trace': Icons.gesture_rounded,
  'listen-and-tap': Icons.hearing_rounded,
  'record-and-listen': Icons.mic_rounded,
  'match-picture': Icons.extension_rounded,
};

/// Icon-only (no reading needed). Tapping opens the activity; the stars show the child's best result.
class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.lessonId, required this.activity, required this.stars});
  final String lessonId;
  final String activity;
  final int stars; // best stars so far, 0-3

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key('activity-$activity'),
      onTap: () => context.push('/lesson/$lessonId/$activity'),
      child: Container(
        width: 120,
        height: 130,
        decoration: BoxDecoration(
          color: Palette.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Palette.ink, width: 3),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_activityIcons[activity] ?? Icons.help_outline_rounded, size: 56, color: Palette.ink),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++) Icon(Icons.star_rounded, size: 24, color: i < stars ? Palette.yellow : Palette.tan),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Best stars the active child earned in one activity of a lesson.
int _bestStars(WidgetRef ref, String lessonId, String activity) {
  final childId = ref.watch(activeChildIdProvider);
  final records = ref.watch(progressProvider);
  var best = 0;
  for (final r in records) {
    if (r.childId == childId && r.lessonId == lessonId && r.activity == activity && r.stars > best) best = r.stars;
  }
  return best;
}
