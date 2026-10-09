import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show TickerCanceled;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/loading_action.dart';
import '../../core/palette.dart';
import '../../core/sky.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../audio/audio_service.dart';
import '../child/child_scope.dart';
import '../content/content_models.dart';
import '../content/packs.dart';
import '../onboarding/onboarding_widgets.dart';
import '../profiles/child_profile.dart';
import '../session/session.dart';
import '../units/map_art.dart';
import '../units/unit_meta.dart';
import 'chest_rewards.dart';
import '../../core/type.dart';

const chestOpenSound = 'audio/ui/chest-open.wav';
const _cheerSound = 'audio/ui/cheer.wav';

/// Opening a treasure chest: tap it, it shakes, opens with a sound, the outfit flies to Dandoona, she celebrates wearing it,
/// then "Got it!" with the stickers. A chest that was opened before shows what was inside, without the show.
class ChestScreen extends ConsumerStatefulWidget {
  const ChestScreen({super.key, required this.unitId});

  final String unitId;

  @override
  ConsumerState<ChestScreen> createState() => _ChestScreenState();
}

class _ChestScreenState extends ConsumerState<ChestScreen> with TickerProviderStateMixin {
  static const _show = Duration(milliseconds: 4200);

  late final AnimationController _c = AnimationController(vsync: this, duration: _show);
  late final AnimationController _idle = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  late final AudioService _audio;
  late final bool _wasOpened;
  bool _started = false;
  bool _opened = false; // the lid has gone up: the chest is recorded as opened and the outfit is worn
  bool _cheered = false;

  @override
  void initState() {
    super.initState();
    _audio = ref.read(audioServiceProvider);
    if (SkyBackground.drift) _idle.repeat(reverse: true); // the waiting chest bobs (still in tests and for people who ask for less motion)
    final childId = ref.read(activeChildIdProvider);
    _wasOpened = childId != null && ref.read(unitMetaProvider).of(childId).chests.contains(widget.unitId);
    if (_wasOpened) {
      _c.value = 1;
      _started = true;
      _opened = true;
    }
    _c.addListener(_onTick);
    // the stickers need this unit's pack (for their pictures and voices): make sure it is on the phone
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final unit = _unit;
      if (unit != null && unit.needsDownload) unawaited(ref.read(packDownloadsProvider.notifier).ensure(unit));
    });
  }

  @override
  void dispose() {
    _c.dispose();
    _idle.dispose();
    unawaited(_audio.stop());
    super.dispose();
  }

  void _onTick() {
    if (!_opened && _c.value >= 0.22) {
      _opened = true;
      unawaited(_audio.playAsset(chestOpenSound));
      final childId = ref.read(activeChildIdProvider);
      final outfit = _unit?.chest?.accessory;
      if (childId != null) {
        unawaited(ref.read(unitMetaProvider.notifier).openChest(childId, widget.unitId));
        if (outfit != null) unawaited(ref.read(profilesProvider.notifier).equip(childId, outfit)); // she wears it right away
      }
    }
    if (!_cheered && _c.value >= 0.62) {
      _cheered = true;
      unawaited(_audio.playAsset(_cheerSound));
    }
    setState(() {});
  }

  Future<void> _start() async {
    if (_started) return;
    _started = true;
    _idle.stop();
    try {
      await _c.forward().orCancel;
    } on TickerCanceled {
      // Leaving the chest cancels its animation.
    }
  }

  CourseUnit? get _unit {
    for (final u in ref.read(chestInventoryProvider).units) {
      if (u.id == widget.unitId) return u;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final inventory = ref.watch(chestInventoryProvider);
    final unit = inventory.units.where((u) => u.id == widget.unitId).firstOrNull;
    final outfit = unit?.chest?.accessory;
    final stickers = unit == null ? const <Sticker>[] : stickersOfUnit(unit);
    final childId = ref.watch(activeChildIdProvider);
    final worn = ref.watch(profilesProvider).where((p) => p.id == childId).firstOrNull?.equippedAccessory;
    final t = _c.value;
    final done = t >= 0.7;

    return ChildScope(
      child: SessionGuard(
        child: Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, box) {
                final w = box.maxWidth, h = box.maxHeight;
                final dandoonaSize = math.min(200.0, h * 0.26);
                final dandoona = Rect.fromLTWH(w / 2 - dandoonaSize / 2, 10, dandoonaSize, dandoonaSize);
                final chestSize = math.min(200.0, w * 0.5);
                final chestCenter = Offset(w / 2, h * 0.50);
                final chestRect = Rect.fromCenter(center: chestCenter, width: chestSize, height: chestSize);

                // 0.00-0.22 the chest shakes; the lid opens at 0.22
                final shaking = _started && t < 0.22;
                final angle = shaking ? math.sin(t * 90) * 0.09 * (0.4 + t / 0.22) : 0.0;
                final idleLift = _started ? 0.0 : -8 * Curves.easeInOut.transform(_idle.value);
                // 0.28-0.62 the outfit rises out of the chest and flies to Dandoona
                final fly = Curves.easeInOutCubic.transform(((t - 0.28) / 0.34).clamp(0.0, 1.0));
                final flying = outfit != null && t >= 0.28 && t < 0.62;
                final from = Rect.fromCenter(center: chestCenter.translate(0, -chestSize * 0.25), width: chestSize * 0.5, height: chestSize * 0.5);
                final flyRect = Rect.lerp(from, dandoona, fly)!;
                final wearing = outfit != null && (t >= 0.62 || _wasOpened);
                final celebrating = t >= 0.62;

                return Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 8,
                      child: LoadingAction(onPressed: () => context.pop(), builder: (onPressed, loading) => IconButton(
                        key: const Key('chest-back'),
                        constraints: const BoxConstraints(minWidth: kMinTapTarget, minHeight: kMinTapTarget),
                        iconSize: 32,
                        onPressed: onPressed,
                        icon: LoadingContent(loading: loading, child: const Icon(Icons.arrow_back_rounded)),
                      )),
                    ),
                    Positioned.fromRect(
                      rect: dandoona,
                      child: DandoonaView(key: const Key('chest-dandoona'), pose: celebrating ? DandoonaPose.jumping : DandoonaPose.waving, size: dandoonaSize, accessory: wearing ? outfit : (_opened ? null : worn)),
                    ),
                    // the chest
                    Positioned.fromRect(
                      rect: chestRect.translate(0, idleLift),
                      child: LoadingTap(
                        key: const Key('chest-tap'),
                        behavior: HitTestBehavior.opaque,
                        onTap: _start,
                        child: Transform.rotate(angle: angle, child: CustomPaint(key: Key(_opened ? 'chest-open' : 'chest-closed'), painter: ChestPainter(open: _opened))),
                      ),
                    ),
                    if (_started && t >= 0.22 && t < 0.62) Positioned.fromRect(rect: chestRect.inflate(60), child: IgnorePointer(child: CustomPaint(painter: _SparklePainter(((t - 0.22) / 0.4).clamp(0.0, 1.0))))),
                    if (flying) Positioned.fromRect(rect: flyRect, child: SvgPicture.asset('assets/images/accessories/$outfit.svg', key: const Key('chest-flying'), fit: BoxFit.contain)),
                    if (!_started)
                      Positioned(
                        left: 24,
                        right: 24,
                        top: chestRect.bottom + 24,
                        child: Text(Strings.en('chestTapOpen'), key: const Key('chest-hint'), textAlign: TextAlign.center, style: kidBody.copyWith(fontWeight: FontWeight.w800, color: Palette.nightInk)),
                      ),
                    if (done)
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 16,
                        child: Opacity(
                          opacity: ((t - 0.7) / 0.2).clamp(0.0, 1.0),
                          child: _RewardCard(stickers: stickers, hasOutfit: outfit != null, wasOpened: _wasOpened, audio: _audio, onDone: () => context.pop()),
                        ),
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

class _RewardCard extends StatelessWidget {
  const _RewardCard({required this.stickers, required this.hasOutfit, required this.wasOpened, required this.audio, required this.onDone});

  final List<Sticker> stickers;
  final bool hasOutfit;
  final bool wasOpened;
  final AudioService audio;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('chest-reward'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), border: Border.all(color: Palette.nightInk, width: 3)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(Strings.en(wasOpened ? 'chestInside' : (hasOutfit ? 'chestNewOutfit' : 'chestNewStickers')), textAlign: TextAlign.center, style: kidBody.copyWith(fontWeight: FontWeight.w900, color: Palette.nightInk)),
          if (stickers.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [for (final s in stickers) StickerTile(key: Key('chest-sticker-${s.word}'), sticker: s, size: 72, onTap: s.audio == null ? null : () => audio.playAsset(s.audio!))],
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: LoadingAction(onPressed: onDone, builder: (onPressed, loading) => FilledButton(
              key: const Key('chest-done'),
              style: FilledButton.styleFrom(backgroundColor: Palette.green, minimumSize: const Size.fromHeight(kMinTapTarget)),
              onPressed: onPressed,
              child: LoadingContent(loading: loading, child: Text(Strings.en('chestGotIt'), style: kidBody.copyWith(fontWeight: FontWeight.w900))),
            )),
          ),
        ],
      ),
    );
  }
}

/// A sticker: the word's picture in a round frame, with the word under it. An earned one is in color; one that is not earned
/// yet is an empty grey frame (see the Sticker Book).
class StickerTile extends StatelessWidget {
  const StickerTile({super.key, required this.sticker, this.size = 88, this.earned = true, this.onTap});

  final Sticker sticker;
  final double size;
  final bool earned;
  final LoadingCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final picture = sticker.image == null
        ? Center(child: Text(earned ? sticker.word : '?', textAlign: TextAlign.center, style: TextStyle(fontSize: size * 0.2, /* outside the scale on purpose: a sticker caption shrinks with the sticker */ fontWeight: FontWeight.w800, color: Palette.nightInk)))
        : AssetPicture(sticker.image!, size: size * 0.78, semanticLabel: sticker.word);
    return LoadingTap(
      onTap: earned ? onTap : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: earned ? Palette.cream : const Color(0xFFE6EDF1),
              shape: BoxShape.circle,
              border: Border.all(color: earned ? Palette.sunflower : Palette.gray, width: 4),
            ),
            child: earned ? Padding(padding: EdgeInsets.all(size * 0.07), child: picture) : Icon(Icons.help_outline_rounded, size: size * 0.5, color: Palette.gray),
          ),
          const SizedBox(height: 2),
          Text(earned ? sticker.word : '', style: kidCaption.copyWith(fontWeight: FontWeight.w800, color: Palette.nightInk)),
        ],
      ),
    );
  }
}

/// A burst of little stars when the lid goes up.
class _SparklePainter extends CustomPainter {
  _SparklePainter(this.p);

  final double p;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final colors = [Palette.sunflower, Palette.pink, Palette.teal, Palette.orange, Palette.white];
    for (var i = 0; i < 14; i++) {
      final a = i * 2 * math.pi / 14 + 0.3;
      final r = size.width * 0.18 + size.width * 0.30 * Curves.easeOut.transform(p);
      final o = c + Offset(math.cos(a) * r, math.sin(a) * r * 0.8 - size.height * 0.1);
      final paint = Paint()..color = colors[i % colors.length].withValues(alpha: (1 - p).clamp(0.0, 1.0));
      final s = 7 + (i % 3) * 3.0;
      final path = Path();
      for (var k = 0; k < 8; k++) {
        final rad = k.isEven ? s : s * 0.4;
        final ang = -math.pi / 2 + k * math.pi / 4;
        k == 0 ? path.moveTo(o.dx + math.cos(ang) * rad, o.dy + math.sin(ang) * rad) : path.lineTo(o.dx + math.cos(ang) * rad, o.dy + math.sin(ang) * rad);
      }
      canvas.drawPath(path..close(), paint);
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.p != p;
}
