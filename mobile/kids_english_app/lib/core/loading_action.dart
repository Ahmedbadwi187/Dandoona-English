import 'dart:async';

import 'package:flutter/material.dart';

/// Keep the returned future so feedback lasts for the actual operation.
typedef LoadingCallback = FutureOr<void> Function();

/// Runs a press once at a time and releases it on success, failure, or disposal.
/// Immediate selections and navigation do not introduce a loading delay.
class LoadingAction extends StatefulWidget {
  const LoadingAction({
    super.key,
    required this.onPressed,
    required this.builder,
    this.loading = false,
  });

  final LoadingCallback? onPressed;
  final bool loading;
  final Widget Function(VoidCallback? onPressed, bool loading) builder;

  @override
  State<LoadingAction> createState() => _LoadingActionState();
}

class _LoadingActionState extends State<LoadingAction> {
  bool _invoking = false;
  bool _pending = false;

  Future<void> _press() async {
    if (_invoking || widget.loading || widget.onPressed == null) return;
    _invoking = true;
    try {
      final operation = widget.onPressed!();
      if (operation is Future) {
        if (mounted) setState(() => _pending = true);
        await operation;
      }
    } finally {
      _invoking = false;
      if (_pending && mounted) {
        setState(() => _pending = false);
      } else {
        _pending = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = _pending || widget.loading;
    return widget.builder(
      loading || widget.onPressed == null ? null : _press,
      loading,
    );
  }
}

/// Keeps the original label, semantics, and footprint while showing progress.
class LoadingContent extends StatelessWidget {
  const LoadingContent({
    super.key,
    required this.loading,
    required this.child,
    this.size = 20,
    this.color,
  });

  final bool loading;
  final Widget child;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (!loading) return child;
    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(opacity: 0, alwaysIncludeSemantics: true, child: child),
        Positioned.fill(
          child: Center(
            child: SizedBox.square(
              dimension: size,
              child: TickerMode(
                enabled: ModalRoute.isCurrentOf(context) ?? true,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: color ?? Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Pictures and game feedback stay visible underneath the small progress badge.
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({super.key, required this.loading, required this.child});

  final bool loading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!loading) return child;
    return Stack(
      children: [
        child,
        PositionedDirectional(
          top: 4,
          end: 4,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: TickerMode(
                  enabled: ModalRoute.isCurrentOf(context) ?? true,
                  child: const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Runs a tap handler at once and lets it finish in the background (a sound, a short wait). Nothing is held back or blocked.
void runNow(LoadingCallback callback) {
  final result = callback();
  if (result is Future) unawaited(result);
}

/// A tap on a picture, icon or tile in the app: it opens at once, with no spinner, and is never blocked while a sound plays.
/// (The name is old: the loader now belongs to real buttons only, see [LoadingAction].)
class LoadingTap extends StatelessWidget {
  const LoadingTap({
    super.key,
    required this.onTap,
    required this.child,
    this.behavior,
  });

  final LoadingCallback? onTap;
  final Widget child;
  final HitTestBehavior? behavior;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: behavior,
    onTap: onTap == null ? null : () => runNow(onTap!),
    child: child,
  );
}

class LoadingInkWell extends StatelessWidget {
  const LoadingInkWell({
    super.key,
    required this.onTap,
    required this.child,
    this.borderRadius,
    this.customBorder,
  });

  final LoadingCallback? onTap;
  final Widget child;
  final BorderRadius? borderRadius;
  final ShapeBorder? customBorder;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: borderRadius,
    customBorder: customBorder,
    onTap: onTap == null ? null : () => runNow(onTap!),
    child: child,
  );
}
