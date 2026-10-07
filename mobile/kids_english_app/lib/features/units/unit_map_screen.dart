import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/palette.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../audio/audio_service.dart';
import '../content/content_models.dart';
import '../content/content_repository.dart';
import '../child/child_scope.dart';
import '../profiles/child_profile.dart';
import '../progress/progress.dart';
import '../session/session.dart';
import '../settings/settings.dart';
import 'unit_logic.dart';
import 'unit_meta.dart';
import 'unit_providers.dart';
import 'unit_style.dart';

const double _pitch = 262; // vertical distance between two islands
const double _firstCenter = 150;
const _xFractions = [0.30, 0.70, 0.34, 0.68];

/// The child's home screen: one island per unit on a path through the sky, in the order the units open.
/// Done islands carry a check and a certificate link, the current one is bigger with a progress bar and a play button,
/// locked ones (and units that are still "coming soon") are grey.
class UnitMapScreen extends ConsumerWidget {
  const UnitMapScreen({super.key});

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
              data: (track) => _UnitMap(track: track),
            ),
          ),
        ),
      ),
    );
  }
}

class _UnitMap extends ConsumerWidget {
  const _UnitMap({required this.track});

  final TrackContent track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final migration = ref.watch(unitMigrationProvider);
    if (migration.isLoading) return const Center(child: CircularProgressIndicator());

    final childId = ref.watch(activeChildIdProvider);
    final child = ref.watch(profilesProvider).where((p) => p.id == childId).firstOrNull;
    ref.watch(progressProvider);
    final progress = ref.read(progressProvider.notifier);
    final unlockAll = ref.watch(settingsProvider).unlockAll;
    final meta = ref.watch(unitMetaProvider);
    final statuses = computeUnitStatuses(
      track.units,
      (lessonId) => childId != null && progress.hasProgress(childId, lessonId),
      unlockAll: unlockAll,
      placedUnits: childId == null ? const {} : meta.of(childId).placed,
    );
    final stars = childId == null ? 0 : progress.totalStars(childId);

    void open(UnitStatus s) {
      if (s.state == UnitState.locked || s.state == UnitState.soon) return;
      final audio = s.unit.audio?.title;
      if (audio != null) unawaited(ref.read(audioServiceProvider).playAsset(audio));
      context.push('/unit/${s.unit.id}');
    }

    return Column(
      children: [
        _TopBar(name: child?.name ?? '', stars: stars, mascot: track.mascot),
        Expanded(
          child: SingleChildScrollView(
            key: const Key('unit-map'),
            child: _IslandPath(
              statuses: statuses,
              mascot: track.mascot,
              certificates: childId == null ? const {} : meta.of(childId).certificates,
              onOpen: open,
            ),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.name, required this.stars, required this.mascot});

  final String name;
  final int stars;
  final String? mascot;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFBDE6FA),
      padding: const EdgeInsets.fromLTRB(4, 6, 12, 4),
      child: Row(
        children: [
          IconButton(
            key: const Key('map-back'),
            constraints: const BoxConstraints(minWidth: kMinTapTarget, minHeight: kMinTapTarget),
            iconSize: 30,
            onPressed: () => context.go('/who'),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          if (mascot != null) AssetPicture(mascot!, size: 68, semanticLabel: 'Dandoona'),
          const SizedBox(width: 4),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Palette.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Palette.nightInk, width: 3),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('${Strings.en('hi')}, $name!',
                      key: const Key('greeting'),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Palette.nightInk)),
                ),
              ),
            ),
          ),
          BigTap(
            onTap: () => context.push('/wardrobe'),
            semanticLabel: 'Mascot wardrobe',
            child: Container(
              key: const Key('open-wardrobe'),
              width: 48,
              height: 48,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(color: Palette.white, shape: BoxShape.circle, border: Border.all(color: Palette.ink, width: 3)),
              child: const Icon(Icons.checkroom_rounded, color: Palette.ink, size: 26),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Palette.white, borderRadius: BorderRadius.circular(30), border: Border.all(color: Palette.ink, width: 3)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, color: Palette.yellow, size: 28),
                const SizedBox(width: 2),
                Text('$stars', key: const Key('total-stars'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Palette.ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IslandPath extends StatelessWidget {
  const _IslandPath({required this.statuses, required this.mascot, required this.certificates, required this.onOpen});

  final List<UnitStatus> statuses;
  final String? mascot;
  final Map<String, String> certificates;
  final ValueChanged<UnitStatus> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = _firstCenter + statuses.length * _pitch;
        final centers = [
          for (var i = 0; i < statuses.length; i++) Offset(width * _xFractions[i % _xFractions.length], _firstCenter + i * _pitch - 60),
        ];
        final current = statuses.indexWhere((s) => s.state == UnitState.current);
        return SizedBox(
          width: width,
          height: height,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFBDE6FA), Color(0xFFE9F6FB), Palette.cream]),
            ),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                for (var i = 0; i < statuses.length; i += 2)
                  Positioned(
                    left: i.isEven ? width * 0.62 : width * 0.04,
                    top: _firstCenter + i * _pitch - 150,
                    child: Container(width: 92, height: 32, decoration: BoxDecoration(color: Palette.white.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(30))),
                  ),
                Positioned.fill(child: CustomPaint(painter: _SkyPathPainter(centers))),
                for (var i = 0; i < statuses.length; i++)
                  Positioned(
                    left: centers[i].dx - 105,
                    top: centers[i].dy - 78,
                    width: 210,
                    child: _IslandTile(
                      status: statuses[i],
                      certificateDate: certificates[statuses[i].unit.id],
                      onOpen: () => onOpen(statuses[i]),
                    ),
                  ),
                if (mascot != null && current >= 0)
                  Positioned(
                    left: centers[current].dx < width / 2 ? centers[current].dx + 112 : centers[current].dx - 202,
                    top: centers[current].dy - 20,
                    child: IgnorePointer(child: AssetPicture(mascot!, size: 92, semanticLabel: 'Dandoona')),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SkyPathPainter extends CustomPainter {
  _SkyPathPainter(this.centers);

  final List<Offset> centers;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Palette.white.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < centers.length - 1; i++) {
      final a = centers[i].translate(0, 56), b = centers[i + 1].translate(0, -62);
      final mid = (a.dy + b.dy) / 2;
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..cubicTo(a.dx, mid, b.dx, mid, b.dx, b.dy);
      for (final m in path.computeMetrics()) {
        for (double d = 0; d < m.length; d += 22) {
          canvas.drawPath(m.extractPath(d, math.min(d + 10, m.length)), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_SkyPathPainter old) => old.centers != centers;
}

class _IslandTile extends StatelessWidget {
  const _IslandTile({required this.status, required this.certificateDate, required this.onOpen});

  final UnitStatus status;
  final String? certificateDate;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final unit = status.unit;
    final state = status.state;
    final locked = state == UnitState.locked || state == UnitState.soon;
    final current = state == UnitState.current;
    final title = unit.titleFor('en');
    return Semantics(
      container: true,
      label: '$title, ${switch (state) {
        UnitState.done => 'finished',
        UnitState.current => 'open',
        UnitState.locked => 'locked',
        UnitState.soon => 'coming soon',
      }}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            key: Key('unit-${unit.id}'),
            behavior: HitTestBehavior.opaque,
            onTap: onOpen,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: current
                      ? BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: Palette.sunflower.withValues(alpha: 0.9), blurRadius: 34, spreadRadius: 8)])
                      : null,
                  child: _Island(unit: unit, state: state, scale: current ? 1.25 : 1),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  key: Key('unit-title-${unit.id}'),
                  style: TextStyle(fontSize: current ? 24 : 19, fontWeight: FontWeight.w900, color: locked ? const Color(0xFF8A8A8A) : Palette.nightInk),
                ),
              ],
            ),
          ),
          if (state == UnitState.done && !(status.placed && certificateDate == null))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: BigTap(
                key: Key('unit-certificate-${unit.id}'),
                semanticLabel: Strings.en('certificate'),
                onTap: () => context.push('/certificate/${unit.id}'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Palette.sunflower, borderRadius: BorderRadius.circular(16), border: Border.all(color: Palette.ink, width: 2.5)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.workspace_premium_rounded, size: 20, color: Palette.nightInk),
                    const SizedBox(width: 4),
                    Text(Strings.en('certificate'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Palette.nightInk)),
                  ]),
                ),
              ),
            ),
          if (current)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ProgressPill(key: Key('unit-progress-${unit.id}'), done: status.done, total: status.total),
                  const SizedBox(width: 8),
                  BigTap(
                    key: Key('unit-play-${unit.id}'),
                    semanticLabel: 'Play $title',
                    onTap: onOpen,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(color: Palette.green, shape: BoxShape.circle, border: Border.all(color: Palette.ink, width: 4)),
                      child: const Icon(Icons.play_arrow_rounded, color: Palette.white, size: 36),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ProgressPill extends StatelessWidget {
  const _ProgressPill({super.key, required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Palette.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Palette.ink, width: 2.5)),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: total == 0 ? 0 : done / total, minHeight: 12, backgroundColor: Palette.tan, color: Palette.green),
            ),
          ),
          const SizedBox(width: 6),
          Text('$done/$total', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Palette.ink)),
        ],
      ),
    );
  }
}

/// A floating island: grass on soil, with the unit's icon on a round badge above it.
class _Island extends StatelessWidget {
  const _Island({required this.unit, required this.state, required this.scale});

  final CourseUnit unit;
  final UnitState state;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final grayed = state == UnitState.locked || state == UnitState.soon;
    final grass = grayed ? const Color(0xFFCFCFCF) : Palette.green;
    final soil = grayed ? const Color(0xFFA9A9A9) : Palette.brown;
    final badge = grayed ? Palette.gray : unitColor(unit.color);
    return SizedBox(
      width: 150 * scale,
      height: 118 * scale,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            bottom: 0,
            child: Container(
              width: 118 * scale,
              height: 44 * scale,
              decoration: BoxDecoration(color: soil, borderRadius: BorderRadius.vertical(top: Radius.circular(8 * scale), bottom: Radius.circular(60 * scale))),
            ),
          ),
          Positioned(
            bottom: 30 * scale,
            child: Container(
              width: 140 * scale,
              height: 46 * scale,
              decoration: BoxDecoration(color: grass, borderRadius: BorderRadius.circular(40 * scale), border: Border.all(color: Palette.nightInk, width: 3)),
            ),
          ),
          Positioned(
            top: 0,
            child: Container(
              width: 70 * scale,
              height: 70 * scale,
              decoration: BoxDecoration(color: badge, shape: BoxShape.circle, border: Border.all(color: Palette.nightInk, width: 4)),
              child: Icon(
                state == UnitState.locked ? Icons.lock_rounded : (state == UnitState.soon ? Icons.hourglass_top_rounded : unitIcon(unit.icon)),
                size: 42 * scale,
                color: Palette.white,
                key: Key('unit-icon-${unit.id}'),
              ),
            ),
          ),
          if (state == UnitState.done)
            Positioned(
              top: -4,
              right: 22 * scale,
              child: Container(
                key: Key('unit-done-${unit.id}'),
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: Palette.green, shape: BoxShape.circle, border: Border.all(color: Palette.white, width: 3)),
                child: const Icon(Icons.check_rounded, color: Palette.white, size: 24),
              ),
            ),
        ],
      ),
    );
  }
}
