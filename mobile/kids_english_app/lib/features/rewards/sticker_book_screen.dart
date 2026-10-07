import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/palette.dart';
import '../../core/sky.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../audio/audio_service.dart';
import '../child/child_scope.dart';
import '../content/content_models.dart';
import '../session/session.dart';
import 'chest_rewards.dart';
import 'chest_screen.dart' show StickerTile;

/// The Sticker Book: one page of stickers per unit, from the chests the child has opened. A sticker that is not earned yet is an
/// empty frame. Tap a sticker and Dandoona says the word.
class StickerBookScreen extends ConsumerWidget {
  const StickerBookScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventory = ref.watch(chestInventoryProvider);
    final audio = ref.read(audioServiceProvider);
    final lang = 'en'; // the child area is always English
    final withChest = [for (final u in inventory.units) if (u.chest != null) u];
    final total = inventory.allStickers.length;
    final got = inventory.stickers.length;

    return ChildScope(
      child: SessionGuard(
        child: Scaffold(
          body: SkyBackground(
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
                    child: Row(
                      children: [
                        IconButton(
                          key: const Key('stickers-back'),
                          constraints: const BoxConstraints(minWidth: kMinTapTarget, minHeight: kMinTapTarget),
                          iconSize: 32,
                          onPressed: () => context.pop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        Expanded(child: Text(Strings.en('stickerBook'), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Palette.nightInk))),
                        Container(
                          key: const Key('stickers-count'),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Palette.nightInk, width: 3)),
                          child: Text(Strings.en('stickerBookCount').replaceAll('{n}', '$got').replaceAll('{total}', '$total'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Palette.nightInk)),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: [
                        for (final u in withChest) _Page(unit: u, opened: inventory.isOpened(u.id), lang: lang, audio: audio),
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

class _Page extends StatelessWidget {
  const _Page({required this.unit, required this.opened, required this.lang, required this.audio});

  final CourseUnit unit;
  final bool opened;
  final String lang;
  final AudioService audio;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('sticker-page-${unit.id}'),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(26), border: Border.all(color: opened ? Palette.sunflower : Palette.gray.withValues(alpha: 0.6), width: 3)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(unit.titleFor(lang), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: opened ? Palette.nightInk : Palette.gray)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              for (final s in stickersOfUnit(unit))
                StickerTile(key: Key('sticker-${s.key}'), sticker: s, size: 76, earned: opened, onTap: s.audio == null ? null : () => unawaited(audio.playAsset(s.audio!))),
            ],
          ),
        ],
      ),
    );
  }
}
