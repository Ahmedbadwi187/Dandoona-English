import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/palette.dart';
import '../../core/sky.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../audio/audio_service.dart';
import '../content/content_repository.dart';
import '../gate/parental_gate.dart';
import '../onboarding/onboarding_widgets.dart';
import '../profiles/child_profile.dart';
import '../progress/progress.dart';
import '../router_state.dart';
import 'child_scope.dart';

/// The cheerful sound of choosing a child (a short rising chime, made by tools/sounds/make-cheer.ps1).
const cheerSound = 'audio/ui/cheer.wav';

/// "Who is playing?" in Dandoona's sky: she waves and says it (tap the bubble to hear it again), the children are big cards
/// to tap, and the small lock button leads to the parent area through the gate.
class ProfilePickerScreen extends ConsumerStatefulWidget {
  const ProfilePickerScreen({super.key});

  @override
  ConsumerState<ProfilePickerScreen> createState() => _ProfilePickerScreenState();
}

class _ProfilePickerScreenState extends ConsumerState<ProfilePickerScreen> {
  late final AudioService _audio;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _audio = ref.read(audioServiceProvider);
    // Arriving here always closes any open parent session and the active child.
    Future.microtask(() {
      if (!mounted) return;
      ref.read(parentSessionProvider.notifier).lock();
      ref.read(activeChildIdProvider.notifier).select(null);
      unawaited(_say());
    });
  }

  @override
  void dispose() {
    unawaited(_audio.stop());
    super.dispose();
  }

  /// Dandoona says "Who is playing?" (silent when the line is not in the content).
  Future<void> _say() async {
    try {
      final path = (await ref.read(contentProvider.future)).appAudio?.title;
      if (path != null && mounted && !_leaving) await _audio.playAsset(path);
    } on Object {
      // no voice: the bubble still shows the words
    }
  }

  Future<void> _openParentArea() async {
    if (await showParentalGate(context) && mounted) {
      ref.read(parentSessionProvider.notifier).unlock();
      context.go('/parent');
    }
  }

  Future<void> _pick(ChildProfile p) async {
    if (_leaving) return;
    setState(() => _leaving = true);
    unawaited(_audio.playAsset(cheerSound)); // replaces Dandoona's question
    await Future<void>.delayed(const Duration(milliseconds: 650)); // the avatar bounces first
    if (!mounted) return;
    ref.read(activeChildIdProvider.notifier).select(p.id);
    context.go('/map');
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(profilesProvider);
    ref.watch(progressProvider);
    final progress = ref.read(progressProvider.notifier);

    return ChildScope(
      child: Scaffold(
        body: SkyBackground(
          child: SafeArea(
            child: Stack(
              children: [
                LayoutBuilder(
                  builder: (context, box) {
                    const gap = 16.0, pad = 20.0;
                    final cardWidth = ((box.maxWidth - pad * 2 - gap) / 2).clamp(140.0, 260.0);
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: box.maxHeight),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(pad, 56, pad, 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _Speech(text: Strings.en('whoIsPlaying'), onTap: () => unawaited(_say())),
                              const DandoonaView(pose: DandoonaPose.waving, size: 190),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: gap,
                                runSpacing: gap,
                                alignment: WrapAlignment.center,
                                children: [
                                  for (final p in profiles)
                                    SizedBox(width: cardWidth, child: _ChildCard(child: p, stars: progress.totalStars(p.id), onPick: () => _pick(p))),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: IconButton(
                      key: const Key('open-parent-area'),
                      constraints: const BoxConstraints(minWidth: kMinTapTarget, minHeight: kMinTapTarget),
                      iconSize: 30,
                      color: Palette.gray,
                      tooltip: 'Parents',
                      onPressed: _openParentArea,
                      icon: const Icon(Icons.lock_rounded),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dandoona's speech bubble: the question with a small speaker; tapping it plays the line again.
class _Speech extends StatelessWidget {
  const _Speech({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: text,
      child: GestureDetector(
        key: const Key('who-bubble'),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kMinTapTarget),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(40), border: Border.all(color: const Color(0xFF3C3478), width: 3)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(text, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Palette.nightInk)))),
                const SizedBox(width: 10),
                const Icon(Icons.volume_up_rounded, color: Palette.plum, size: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A child: a white card with a border in the avatar's color, the avatar (it bounces when chosen), the name in the avatar's
/// dark shade and the stars earned so far.
class _ChildCard extends StatefulWidget {
  const _ChildCard({required this.child, required this.stars, required this.onPick});

  final ChildProfile child;
  final int stars;
  final VoidCallback onPick;

  @override
  State<_ChildCard> createState() => _ChildCardState();
}

class _ChildCardState extends State<_ChildCard> with SingleTickerProviderStateMixin {
  late final AnimationController _bounce = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.88).chain(CurveTween(curve: Curves.easeOut)), weight: 15),
    TweenSequenceItem(tween: Tween(begin: 0.88, end: 1.3).chain(CurveTween(curve: Curves.easeOut)), weight: 35),
    TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0).chain(CurveTween(curve: Curves.bounceOut)), weight: 50),
  ]).animate(_bounce);

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avatar = AvatarOption.byKey(widget.child.avatarKey);
    final color = avatar.color;
    return GestureDetector(
      key: Key('pick-${widget.child.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _bounce.forward(from: 0);
        widget.onPick();
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: color.border, width: 4),
          boxShadow: [BoxShadow(color: color.border.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 5))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(scale: _scale, child: AvatarCircle(widget.child.avatarKey, size: 104)),
            const SizedBox(height: 10),
            Text(widget.child.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color.dark)),
            const SizedBox(height: 6),
            Container(
              key: Key('stars-${widget.child.id}'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: color.tint, borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded, size: 22, color: color.dark),
                  const SizedBox(width: 4),
                  Text('${widget.stars}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color.dark)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
