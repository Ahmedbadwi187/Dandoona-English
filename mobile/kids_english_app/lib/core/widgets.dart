import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'palette.dart';
import 'theme.dart';

/// Shows a bundled lesson image: self-drawn `.svg` or generated `.webp`. Both look like one set (shared palette).
class AssetPicture extends StatelessWidget {
  const AssetPicture(this.assetPath, {super.key, this.size, this.semanticLabel});

  /// Path relative to `assets/`, exactly as written in little_learners.json.
  final String assetPath;
  final double? size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final path = 'assets/$assetPath';
    final child = assetPath.endsWith('.svg')
        ? SvgPicture.asset(path, width: size, height: size, semanticsLabel: semanticLabel)
        : Image.asset(path, width: size, height: size, semanticLabel: semanticLabel, fit: BoxFit.contain);
    return ClipRRect(borderRadius: BorderRadius.circular(20), child: child);
  }
}

/// Avatars are plain colored icons: no photos, no personal data.
class AvatarOption {
  const AvatarOption(this.key, this.icon, this.color);
  final String key;
  final IconData icon;
  final Color color;

  static const all = [
    AvatarOption('star', Icons.star_rounded, Palette.yellow),
    AvatarOption('rocket', Icons.rocket_launch_rounded, Palette.red),
    AvatarOption('flower', Icons.local_florist_rounded, Palette.pink),
    AvatarOption('sun', Icons.wb_sunny_rounded, Palette.orange),
    AvatarOption('leaf', Icons.eco_rounded, Palette.green),
    AvatarOption('fish', Icons.set_meal_rounded, Palette.teal),
    AvatarOption('cloud', Icons.cloud_rounded, Palette.blue),
    AvatarOption('moon', Icons.nightlight_round, Palette.purple),
  ];

  static AvatarOption byKey(String key) => all.firstWhere((a) => a.key == key, orElse: () => all.first);
}

class AvatarCircle extends StatelessWidget {
  const AvatarCircle(this.avatarKey, {super.key, this.size = 72});
  final String avatarKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    final a = AvatarOption.byKey(avatarKey);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: a.color,
        shape: BoxShape.circle,
        border: Border.all(color: Palette.ink, width: 3),
      ),
      child: Icon(a.icon, color: Palette.white, size: size * 0.55),
    );
  }
}

/// A large, forgiving tap target for the child area (never smaller than [kMinTapTarget]).
class BigTap extends StatelessWidget {
  const BigTap({super.key, required this.onTap, required this.child, this.semanticLabel});
  final VoidCallback? onTap;
  final Widget child;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: semanticLabel,
      child: InkResponse(
        onTap: onTap,
        radius: kMinTapTarget,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: kMinTapTarget, minHeight: kMinTapTarget),
          // Shrink-wrap (factor 1) so callers can position the tap target; the min constraints still guarantee 64 dp.
          child: Center(widthFactor: 1, heightFactor: 1, child: child),
        ),
      ),
    );
  }
}
