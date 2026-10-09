import 'package:flutter/material.dart';

import '../../core/palette.dart';
import '../../core/loading_action.dart';
import '../../core/type.dart';

/// The parent screens stay calm: cream page, white cards with a soft border, one accent (the theme's purple).
/// Every card uses the same radius, padding and border; every text uses one of these four sizes.
const parentBorder = Color(0xFFEBDDBA);
const parentRadius = 20.0;
const parentPad = 16.0;
const kParentTap = 48.0;

/// Buttons inside parent cards: a little smaller than the child-facing ones (44 high, softer corners, 15 pt text).
ButtonStyle parentFilledStyle() => FilledButton.styleFrom(
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: parentBody.copyWith(fontWeight: FontWeight.w700),
    );

ButtonStyle parentOutlinedStyle(BuildContext context) {
  final primary = Theme.of(context).colorScheme.primary;
  return OutlinedButton.styleFrom(
    minimumSize: const Size(0, 44),
    padding: const EdgeInsets.symmetric(horizontal: 18),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    side: BorderSide(color: primary, width: 1.5),
    foregroundColor: primary,
    textStyle: parentBody.copyWith(fontWeight: FontWeight.w700),
  );
}

abstract final class ParentText {
  static final screenTitle = parentTitle.copyWith(fontWeight: FontWeight.w800, color: Palette.ink, height: 1.2);
  static final section = parentSubtitle.copyWith(fontWeight: FontWeight.w700, color: Palette.ink);
  static final body = parentBody.copyWith(color: Palette.ink);
  static final caption = parentCaption.copyWith(color: const Color(0xFF7B6556));
}

/// A white card with the shared border. Tappable when [onTap] is given.
class ParentCard extends StatelessWidget {
  const ParentCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(parentPad), this.color = Palette.white});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(parentRadius), side: const BorderSide(color: parentBorder, width: 1.5));
    return Material(
      color: color,
      shape: shape,
      child: InkWell(customBorder: shape, onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

/// A back arrow; the icon mirrors by itself in right-to-left.
class ParentBack extends StatelessWidget {
  const ParentBack({super.key, required this.onPressed, this.loading = false});
  final LoadingCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) => LoadingAction(
        onPressed: onPressed,
        loading: loading,
        builder: (onPressed, loading) => IconButton(
          key: const Key('parent-back'),
          constraints: const BoxConstraints(minWidth: kParentTap, minHeight: kParentTap),
          onPressed: onPressed,
          icon: LoadingContent(loading: loading, child: const Icon(Icons.arrow_back_rounded)),
        ),
      );
}

/// The chevron of a tappable card (mirrors by itself in right-to-left).
class ParentChevron extends StatelessWidget {
  const ParentChevron({super.key});

  @override
  Widget build(BuildContext context) => const Icon(Icons.chevron_right_rounded, color: Palette.ink, size: 28);
}
