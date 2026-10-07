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
  const AvatarOption(this.key, this.icon, this.color, {this.asset});
  final String key;
  final IconData icon;
  final Color color;

  /// A drawn picture (Dandoona or one of her friends) shown instead of the icon. The older icon avatars have none.
  final String? asset;

  /// The avatars a parent can pick now: Dandoona and six friends. No photos.
  static const pickable = [
    AvatarOption('dandoona', Icons.face_rounded, Palette.plum, asset: 'assets/images/mascot/mascot.webp'),
    AvatarOption('bunny', Icons.pets_rounded, Palette.pink, asset: 'assets/images/avatars/bunny.svg'),
    AvatarOption('cat', Icons.pets_rounded, Palette.yellow, asset: 'assets/images/avatars/cat.svg'),
    AvatarOption('bear', Icons.pets_rounded, Palette.tan, asset: 'assets/images/avatars/bear.svg'),
    AvatarOption('owl', Icons.pets_rounded, Palette.teal, asset: 'assets/images/avatars/owl.svg'),
    AvatarOption('goldfish', Icons.pets_rounded, Palette.blue, asset: 'assets/images/avatars/fish.svg'),
    AvatarOption('puppy', Icons.pets_rounded, Palette.green, asset: 'assets/images/avatars/puppy.svg'),
    AvatarOption('penguin', Icons.pets_rounded, Color(0xFFBDE6FA), asset: 'assets/images/avatars/penguin.svg'),
  ];

  /// The icon avatars children created before the drawn ones keep: each keeps its color and now shows a matching drawn
  /// character (star: cat, rocket: puppy, flower: bunny, sun: bear, leaf: frog, fish: goldfish, cloud: penguin, moon: owl).
  static const legacy = [
    AvatarOption('star', Icons.star_rounded, Palette.yellow, asset: 'assets/images/avatars/cat.svg'),
    AvatarOption('rocket', Icons.rocket_launch_rounded, Palette.red, asset: 'assets/images/avatars/puppy.svg'),
    AvatarOption('flower', Icons.local_florist_rounded, Palette.pink, asset: 'assets/images/avatars/bunny.svg'),
    AvatarOption('sun', Icons.wb_sunny_rounded, Palette.orange, asset: 'assets/images/avatars/bear.svg'),
    AvatarOption('leaf', Icons.eco_rounded, Palette.green, asset: 'assets/images/avatars/frog.svg'),
    AvatarOption('fish', Icons.set_meal_rounded, Palette.teal, asset: 'assets/images/avatars/fish.svg'),
    AvatarOption('cloud', Icons.cloud_rounded, Palette.blue, asset: 'assets/images/avatars/penguin.svg'),
    AvatarOption('moon', Icons.nightlight_round, Palette.purple, asset: 'assets/images/avatars/owl.svg'),
  ];

  /// Every avatar a profile can have (so children made earlier still show theirs).
  static const all = [...pickable, ...legacy];

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
      clipBehavior: Clip.antiAlias,
      child: a.asset == null
          ? Icon(a.icon, color: Palette.white, size: size * 0.55)
          : Padding(
              padding: EdgeInsets.all(size * 0.06),
              child: a.asset!.endsWith('.svg')
                  ? SvgPicture.asset(a.asset!, fit: BoxFit.contain)
                  : Image.asset(a.asset!, fit: BoxFit.contain),
            ),
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

/// A picture (or letter) that speaks when tapped. A small speaker badge tells a child who cannot read that it is
/// pressable, the badge pulses twice when the screen opens, and the picture bounces when tapped.
class TapToHear extends StatefulWidget {
  const TapToHear({super.key, required this.onTap, required this.child, this.semanticLabel, this.badgeInset = 0});

  final VoidCallback onTap;
  final Widget child;
  final String? semanticLabel;

  /// Moves the badge towards the middle (for round children, whose corners are empty).
  final double badgeInset;

  @override
  State<TapToHear> createState() => _TapToHearState();
}

class _TapToHearState extends State<TapToHear> with TickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
  late final AnimationController _hint = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  static final _popScale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.12).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 60),
  ]);
  static final _hintScale = TweenSequence<double>([
    for (var i = 0; i < 2; i++) ...[
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3).chain(CurveTween(curve: Curves.easeOut)), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 20),
    ],
  ]);

  @override
  void initState() {
    super.initState();
    _hint.forward();
  }

  @override
  void dispose() {
    _pop.dispose();
    _hint.dispose();
    super.dispose();
  }

  void _tapped() {
    _pop.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return BigTap(
      semanticLabel: widget.semanticLabel,
      onTap: _tapped,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ScaleTransition(scale: _pop.drive(_popScale), child: widget.child),
          Positioned(
            right: widget.badgeInset,
            bottom: widget.badgeInset,
            child: ScaleTransition(
              scale: _hint.drive(_hintScale),
              child: Container(
                key: const Key('speaker-badge'),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Palette.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Palette.ink, width: 3),
                ),
                child: const Icon(Icons.volume_up_rounded, size: 26, color: Palette.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
