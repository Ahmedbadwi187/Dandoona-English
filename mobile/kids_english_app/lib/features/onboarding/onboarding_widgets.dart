import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/palette.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/type.dart';

/// Dandoona's poses (her own art, exported by the asset tool). `base` is the locked reference picture.
enum DandoonaPose {
  base('assets/images/mascot/mascot.webp'),
  waving('assets/images/mascot/poses/waving.webp'),
  jumping('assets/images/mascot/poses/jumping.webp'),
  clapping('assets/images/mascot/poses/clapping.webp'),
  thinking('assets/images/mascot/poses/thinking.webp'),
  pointingUp('assets/images/mascot/poses/pointing-up.webp');

  const DandoonaPose(this.asset);
  final String asset;
}

/// Dandoona in a pose, optionally wearing one of her accessories (the same drawings as the wardrobe).
class DandoonaView extends StatelessWidget {
  const DandoonaView({super.key, required this.pose, this.size = 150, this.accessory});

  final DandoonaPose pose;
  final double size;

  /// An accessory id from the wardrobe (e.g. `glasses`, `party-hat`), or null.
  final String? accessory;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Image.asset(pose.asset, width: size, height: size, semanticLabel: 'Dandoona'),
          if (accessory != null) Positioned.fill(child: SvgPicture.asset('assets/images/accessories/$accessory.svg', fit: BoxFit.contain)),
        ],
      ),
    );
  }
}

/// One onboarding screen: back arrow and progress bar on top, Dandoona, the question, the answer area, and a Continue
/// button that stays disabled until [onContinue] is given (an answer was chosen).
class OnboardingFrame extends StatelessWidget {
  const OnboardingFrame({
    super.key,
    required this.s,
    required this.pose,
    required this.title,
    required this.child,
    this.subtitle,
    this.progress,
    this.onBack,
    this.onContinue,
    this.continueLabel,
    this.secondaryLabel,
    this.onSecondary,
    this.accessory,
    this.poseSize = 150,
  });

  final Strings s;
  final DandoonaPose pose;
  final String? accessory;
  final double poseSize;
  final String title;
  final String? subtitle;
  final Widget child;

  /// 0..1 across the question screens; null hides the bar (language, welcome...).
  final double? progress;
  final VoidCallback? onBack;
  final VoidCallback? onContinue;
  final String? continueLabel;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: s.direction,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                child: Row(
                  children: [
                    SizedBox(
                      width: kMinTapTarget,
                      height: kMinTapTarget,
                      child: onBack == null
                          ? null
                          : IconButton(
                              key: const Key('ob-back'),
                              tooltip: s('obBack'),
                              iconSize: 30,
                              onPressed: onBack,
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                    ),
                    if (progress != null)
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            key: const Key('ob-progress'),
                            value: progress,
                            minHeight: 14,
                            backgroundColor: Palette.tan,
                            color: Palette.plum,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 4, 22, 12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DandoonaView(pose: pose, size: poseSize, accessory: accessory),
                          const SizedBox(height: 6),
                          Text(title,
                              key: const Key('ob-title'),
                              textAlign: TextAlign.center,
                              style: parentStat.copyWith(fontWeight: FontWeight.w900, color: Palette.nightInk, height: 1.25)),
                          if (subtitle != null) ...[
                            const SizedBox(height: 6),
                            Text(subtitle!, textAlign: TextAlign.center, style: parentBody.copyWith(color: Palette.brown, height: 1.4)),
                          ],
                          const SizedBox(height: 18),
                          child,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          key: const Key('ob-continue'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Palette.plum,
                            disabledBackgroundColor: const Color(0xFFE0D8EC),
                            foregroundColor: Palette.white,
                            minimumSize: const Size.fromHeight(64),
                            textStyle: Theme.of(context).textTheme.labelLarge?.merge(parentTitle).copyWith(fontWeight: FontWeight.w800),
                          ),
                          onPressed: onContinue,
                          child: Text(continueLabel ?? s('obContinue')),
                        ),
                      ),
                      if (secondaryLabel != null)
                        TextButton(
                          key: const Key('ob-secondary'),
                          style: TextButton.styleFrom(minimumSize: const Size.fromHeight(kMinTapTarget), foregroundColor: Palette.plum),
                          onPressed: onSecondary,
                          child: Text(secondaryLabel!, style: parentBody.copyWith(fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A big answer card (radio style): used for language, account choice, level, daily goal and reminder time.
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({super.key, required this.title, required this.selected, required this.onTap, this.subtitle, this.leading, this.titleStyle = parentSubtitle});

  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool selected;
  final VoidCallback onTap;
  final TextStyle titleStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        button: true,
        selected: selected,
        label: title,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(26),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            constraints: const BoxConstraints(minHeight: 76),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFF1E8FB) : Palette.white,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: selected ? Palette.plum : Palette.tan, width: selected ? 5 : 3),
            ),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 14)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: titleStyle.copyWith(fontWeight: FontWeight.w800, color: Palette.nightInk)),
                      if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle!, style: parentCaption.copyWith(color: Palette.brown))),
                    ],
                  ),
                ),
                Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined, color: selected ? Palette.plum : const Color(0xFFBDB3CB), size: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
