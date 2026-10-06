import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/palette.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../content/content_models.dart';
import '../content/content_repository.dart';
import '../profiles/child_profile.dart';
import '../progress/progress.dart';
import '../session/session.dart';
import '../settings/settings.dart';
import 'child_scope.dart';

const double _rowHeight = 168;
const double _nodeSize = 92;
/// Node + gap + the row of 3 stars (22 dp each), centred vertically in the row.
const double _columnHeight = _nodeSize + 2 + 22;

/// The learning path: all lessons (A-Z) as a winding trail. A lesson opens when the previous one has progress.
class LetterMapScreen extends ConsumerWidget {
  const LetterMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(contentProvider);
    return ChildScope(
      child: SessionGuard(
        child: Scaffold(
          body: SafeArea(
            child: content.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(Strings.en('loadError'), style: const TextStyle(fontSize: 22)),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: () => ref.invalidate(contentProvider), child: Text(Strings.en('retry'))),
                  ],
                ),
              ),
              data: (track) => _Map(track: track),
            ),
          ),
        ),
      ),
    );
  }
}

class _Map extends ConsumerWidget {
  const _Map({required this.track});
  final TrackContent track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childId = ref.watch(activeChildIdProvider);
    final child = ref.watch(profilesProvider).where((p) => p.id == childId).firstOrNull;
    ref.watch(progressProvider); // rebuild when progress changes
    final progress = ref.read(progressProvider.notifier);
    final unlockAll = ref.watch(settingsProvider).unlockAll;
    final totalStars =
        childId == null ? 0 : track.lessons.fold<int>(0, (sum, l) => sum + progress.starsFor(childId, l.id));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
          child: Row(
            children: [
              IconButton(
                key: const Key('map-back'),
                constraints: const BoxConstraints(minWidth: kMinTapTarget, minHeight: kMinTapTarget),
                iconSize: 32,
                onPressed: () => context.go('/who'),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              if (child != null) AvatarCircle(child.avatarKey, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Text(child?.name ?? '',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              ),
              const Icon(Icons.star_rounded, color: Palette.yellow, size: 36),
              const SizedBox(width: 4),
              Text('$totalStars', key: const Key('total-stars'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            key: const Key('letter-map'),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemExtent: _rowHeight,
            itemCount: track.lessons.length,
            itemBuilder: (context, i) {
              final lesson = track.lessons[i];
              final unlocked = isLessonUnlocked(
                index: i,
                unlockAll: unlockAll,
                previousHasProgress:
                    i > 0 && childId != null && progress.hasProgress(childId, track.lessons[i - 1].id),
              );
              final stars = childId == null ? 0 : progress.starsFor(childId, lesson.id);
              return _MapRow(
                index: i,
                total: track.lessons.length,
                lesson: lesson,
                unlocked: unlocked,
                stars: stars,
                onTap: unlocked ? () => context.push('/lesson/${lesson.id}') : null,
              );
            },
          ),
        ),
      ],
    );
  }
}

double _alignmentFor(int i) => math.sin(i * 0.95) * 0.62;

class _MapRow extends StatelessWidget {
  const _MapRow({
    required this.index,
    required this.total,
    required this.lesson,
    required this.unlocked,
    required this.stars,
    required this.onTap,
  });

  final int index;
  final int total;
  final Lesson lesson;
  final bool unlocked;
  final int stars;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = unlocked ? Palette.nodeColors[index % Palette.nodeColors.length] : Palette.gray;
    final filledStars = (stars / 4).ceil().clamp(0, 3); // 0-12 stars summarised as 0-3
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _TrailPainter(
              current: _alignmentFor(index),
              previous: index > 0 ? _alignmentFor(index - 1) : null,
              next: index < total - 1 ? _alignmentFor(index + 1) : null,
            ),
          ),
        ),
        Align(
          alignment: Alignment(_alignmentFor(index), 0),
          child: BigTap(
            onTap: onTap,
            semanticLabel: lesson.letter == null ? lesson.id : 'Letter ${lesson.letter}',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  key: Key('node-${lesson.id}'),
                  width: _nodeSize,
                  height: _nodeSize,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Palette.ink, width: 4),
                  ),
                  alignment: Alignment.center,
                  child: unlocked
                      ? Text(lesson.letter ?? '?',
                          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Palette.white))
                      : const Icon(Icons.lock_rounded, color: Palette.white, size: 40),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var s = 0; s < 3; s++)
                      Icon(Icons.star_rounded, size: 22, color: s < filledStars ? Palette.yellow : Palette.tan),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A soft dotted curve. Each row draws only its own half (down to the row's bottom edge and up from its top edge),
/// meeting its neighbours at the shared midpoint, so nothing is painted outside the row.
class _TrailPainter extends CustomPainter {
  _TrailPainter({required this.current, this.previous, this.next});
  final double current;
  final double? previous;
  final double? next;

  @override
  void paint(Canvas canvas, Size size) {
    double x(double align) => size.width / 2 + align * (size.width / 2 - _nodeSize / 2);
    final cx = x(current);
    final columnTop = (size.height - _columnHeight) / 2;
    final paint = Paint()
      ..color = Palette.tan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    if (next != null) {
      final meet = (cx + x(next!)) / 2;
      _dotted(canvas, paint, Offset(cx, columnTop + _columnHeight + 4), Offset(meet, size.height));
    }
    if (previous != null) {
      final meet = (cx + x(previous!)) / 2;
      _dotted(canvas, paint, Offset(meet, 0), Offset(cx, columnTop - 4));
    }
  }

  void _dotted(Canvas canvas, Paint paint, Offset a, Offset b) {
    final mid = (a.dy + b.dy) / 2;
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..cubicTo(a.dx, mid, b.dx, mid, b.dx, b.dy);
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, math.min(d + 8, m.length)), paint);
        d += 20;
      }
    }
  }

  @override
  bool shouldRepaint(_TrailPainter old) =>
      old.current != current || old.previous != previous || old.next != next;
}
