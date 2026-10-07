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
import '../child/child_scope.dart';
import '../content/content_repository.dart';
import '../profiles/child_profile.dart';
import '../session/session.dart';
import '../units/unit_meta.dart';

/// Shown once, right after the last lesson of a unit: Dandoona jumps for joy, stars fall, her voice says the unit is
/// finished. It records the certificate and that the celebration was seen, then leads on to the certificate.
class UnitCelebrationScreen extends ConsumerStatefulWidget {
  const UnitCelebrationScreen({super.key, required this.unitId});

  final String unitId;

  @override
  ConsumerState<UnitCelebrationScreen> createState() => _UnitCelebrationScreenState();
}

class _UnitCelebrationScreenState extends ConsumerState<UnitCelebrationScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..forward();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final track = await ref.read(contentProvider.future);
      final childId = ref.read(activeChildIdProvider);
      final unit = track.unitById(widget.unitId);
      if (!mounted || unit == null) return;
      final celebration = unit.audio?.celebration;
      if (celebration != null) unawaited(ref.read(audioServiceProvider).playAsset(celebration));
      if (childId != null) {
        final meta = ref.read(unitMetaProvider.notifier);
        await meta.awardCertificate(childId, unit.id, DateTime.now());
        await meta.markCelebrated(childId, unit.id);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(contentProvider);
    return ChildScope(
      child: SessionGuard(
        child: Scaffold(
          backgroundColor: const Color(0xFFBDE6FA),
          body: SafeArea(
            child: content.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(Strings.en('loadError'))),
              data: (track) {
                final unit = track.unitById(widget.unitId);
                if (unit == null) return Center(child: Text(Strings.en('loadError')));
                return Stack(
                  children: [
                    Positioned.fill(child: AnimatedBuilder(animation: _controller, builder: (_, _) => CustomPaint(painter: _FallingStars(_controller.value)))),
                    Column(
                      children: [
                        const Spacer(flex: 2),
                        AnimatedBuilder(
                          animation: _controller,
                          builder: (_, child) {
                            final t = _controller.value;
                            final jump = t < 0.9 ? math.sin(t * math.pi * 6).abs() * 60 : 0.0;
                            return Transform.translate(offset: Offset(0, -jump), child: child);
                          },
                          child: track.mascot == null ? const SizedBox(height: 220) : AssetPicture(track.mascot!, size: 240, semanticLabel: 'Dandoona'),
                        ),
                        const SizedBox(height: 16),
                        Text(Strings.en('hooray'), key: const Key('celebration-hooray'), style: const TextStyle(fontSize: 46, fontWeight: FontWeight.w900, color: Palette.nightInk)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          decoration: BoxDecoration(color: Palette.sunflower, borderRadius: BorderRadius.circular(26), border: Border.all(color: Palette.nightInk, width: 4)),
                          child: Text(unit.titleFor('en'), key: const Key('celebration-unit'), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Palette.nightInk)),
                        ),
                        const Spacer(flex: 2),
                        IconButton.filled(
                          key: const Key('celebration-continue'),
                          style: IconButton.styleFrom(backgroundColor: Palette.green, minimumSize: const Size(kMinTapTarget * 1.6, kMinTapTarget * 1.3)),
                          iconSize: 48,
                          onPressed: () => context.go('/certificate/${unit.id}'),
                          icon: const Icon(Icons.workspace_premium_rounded, color: Palette.white),
                        ),
                        const SizedBox(height: 28),
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

/// Stars that fall once from the top while the celebration plays.
class _FallingStars extends CustomPainter {
  _FallingStars(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(7);
    for (var i = 0; i < 18; i++) {
      final x = rng.nextDouble() * size.width;
      final delay = rng.nextDouble() * 0.5;
      final speed = 0.7 + rng.nextDouble() * 0.5;
      final progress = ((t - delay) * speed / 0.7).clamp(0.0, 1.0);
      if (progress <= 0 || progress >= 1) continue;
      final y = -30 + progress * (size.height + 60);
      final color = [Palette.sunflower, Palette.pink, Palette.plum, Palette.white][i % 4];
      final r = 10 + rng.nextDouble() * 10;
      final path = Path();
      for (var k = 0; k < 10; k++) {
        final radius = k.isEven ? r : r * 0.45;
        final angle = -math.pi / 2 + k * math.pi / 5 + progress * 2;
        final p = Offset(x + math.cos(angle) * radius, y + math.sin(angle) * radius);
        k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path..close(), Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_FallingStars old) => old.t != t;
}
