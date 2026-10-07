import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/palette.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../child/child_scope.dart';
import '../content/content_repository.dart';
import '../profiles/child_profile.dart';
import '../progress/progress.dart';
import '../session/session.dart';
import '../units/map_art.dart';
import 'accessories.dart';
import 'chest_rewards.dart';

/// The mascot's wardrobe: accessories unlock with stars; tap an unlocked one to wear it (tap again to take it off).
class WardrobeScreen extends ConsumerWidget {
  const WardrobeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childId = ref.watch(activeChildIdProvider);
    final child = ref.watch(profilesProvider).where((p) => p.id == childId).firstOrNull;
    ref.watch(progressProvider);
    final stars = childId == null ? 0 : ref.read(progressProvider.notifier).totalStars(childId);
    final mascot = ref.watch(contentProvider).maybeWhen(data: (c) => c.mascot, orElse: () => null);
    final inventory = ref.watch(chestInventoryProvider);
    final owned = inventory.outfits;
    void wear(String id) {
      if (child != null) ref.read(profilesProvider.notifier).equip(child.id, child.equippedAccessory == id ? null : id);
    }

    return ChildScope(
      child: SessionGuard(
        child: Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    IconButton(
                      key: const Key('wardrobe-back'),
                      constraints: const BoxConstraints(minWidth: kMinTapTarget, minHeight: kMinTapTarget),
                      iconSize: 32,
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const Spacer(),
                    const Icon(Icons.star_rounded, color: Palette.yellow, size: 36),
                    const SizedBox(width: 4),
                    Text('$stars', key: const Key('wardrobe-stars'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 8),
                if (mascot != null)
                  Center(child: MascotStage(mascotAsset: mascot, size: 260, accessoryId: child?.equippedAccessory)),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final a in accessories)
                      _AccessoryCard(
                        accessory: a,
                        mascotAsset: mascot,
                        unlocked: isUnlocked(a, stars),
                        worn: child?.equippedAccessory == a.id,
                        onTap: child == null || !isUnlocked(a, stars)
                            ? null
                            : () => ref.read(profilesProvider.notifier).equip(child.id, child.equippedAccessory == a.id ? null : a.id),
                      ),
                    // the outfits from the treasure chests, one per unit: empty until that chest is opened
                    for (final u in inventory.units)
                      if (u.chest != null)
                        _AccessoryCard(
                          accessory: Accessory(u.chest!.accessory, 0),
                          mascotAsset: mascot,
                          unlocked: owned.contains(u.chest!.accessory),
                          worn: child?.equippedAccessory == u.chest!.accessory,
                          lockedBadge: Column(mainAxisSize: MainAxisSize.min, children: [
                            const CustomPaint(size: Size(48, 48), painter: ChestPainter(open: false, muted: true)),
                            Text(u.titleFor('en'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Palette.gray)),
                          ]),
                          onTap: !owned.contains(u.chest!.accessory) ? null : () => wear(u.chest!.accessory),
                        ),
                  ],
                ),
                const SizedBox(height: 16),
                Center(child: Text(Strings.en('wardrobeHint'), style: const TextStyle(color: Palette.ink))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccessoryCard extends StatelessWidget {
  const _AccessoryCard({required this.accessory, required this.mascotAsset, required this.unlocked, required this.worn, required this.onTap, this.lockedBadge});

  final Accessory accessory;
  final String? mascotAsset;
  final bool unlocked;
  final bool worn;
  final VoidCallback? onTap;

  /// What a locked card shows instead of the star price (the chest outfits show their chest and unit).
  final Widget? lockedBadge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key('accessory-${accessory.id}'),
      onTap: onTap,
      child: Container(
        width: 112,
        height: 128,
        decoration: BoxDecoration(
          color: Palette.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: worn ? Palette.green : Palette.ink, width: worn ? 7 : 3),
        ),
        child: unlocked
            ? Padding(
                padding: const EdgeInsets.all(6),
                child: mascotAsset == null
                    ? SvgPicture.asset(accessory.assetPath)
                    : MascotStage(mascotAsset: mascotAsset!, size: 96, accessoryId: accessory.id, markWorn: false),
              )
            : lockedBadge != null
                ? Center(child: lockedBadge)
                : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_rounded, size: 44, color: Palette.gray),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, size: 24, color: Palette.yellow),
                      Text('${accessory.unlockStars}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
