import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/palette.dart';
import '../../core/storage.dart';

/// One move of the demo hand: a tap on [target], or a drag from [target] to [to].
class DemoStep {
  const DemoStep.tap(this.target) : to = null;
  const DemoStep.drag(this.target, GlobalKey this.to);

  final GlobalKey target;
  final GlobalKey? to;
}

/// Shows how a game is played before the child plays it: a hand moves over the game's own pieces and does each move once
/// (tap, or drag), while the activity has Dandoona explain it in her voice. A tap anywhere skips it. The pieces underneath
/// do not react to the demo, so nothing is answered for the child.
class HandDemo extends StatefulWidget {
  const HandDemo({super.key, required this.child, required this.steps, required this.running, required this.onDone});

  final Widget child;
  final List<DemoStep> steps;

  /// While true the hand plays; the parent sets it false (or the hand finishes and calls [onDone]).
  final bool running;
  final VoidCallback onDone;

  static const _move = 550, _press = 350, _drag = 750, _rest = 250; // milliseconds per part of a step

  @override
  State<HandDemo> createState() => _HandDemoState();
}

class _HandDemoState extends State<HandDemo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  final _stack = GlobalKey();
  List<(Offset, Offset?)> _points = const [];
  Offset _start = Offset.zero;

  @override
  void initState() {
    super.initState();
    if (widget.running) WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  @override
  void didUpdateWidget(HandDemo old) {
    super.didUpdateWidget(old);
    if (widget.running && !old.running) WidgetsBinding.instance.addPostFrameCallback((_) => _play());
    if (!widget.running && old.running) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Offset? _centerOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    final stack = _stack.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || stack == null || !box.attached) return null;
    return box.localToGlobal(box.size.center(Offset.zero), ancestor: stack);
  }

  int _stepMs(DemoStep s) => HandDemo._move + HandDemo._press + (s.to != null ? HandDemo._drag : 0) + HandDemo._rest;

  Future<void> _play() async {
    if (!mounted || !widget.running) return;
    final stack = _stack.currentContext?.findRenderObject() as RenderBox?;
    final points = <(Offset, Offset?)>[];
    for (final s in widget.steps) {
      final a = _centerOf(s.target);
      if (a == null) continue;
      points.add((a, s.to == null ? null : _centerOf(s.to!)));
    }
    if (points.isEmpty || stack == null) {
      widget.onDone();
      return;
    }
    setState(() {
      _points = points;
      _start = Offset(stack.size.width * 0.8, stack.size.height * 0.95); // comes in from the bottom corner
    });
    final total = widget.steps.where((s) => _centerOf(s.target) != null).fold<int>(0, (t, s) => t + _stepMs(s));
    _c.duration = Duration(milliseconds: total);
    try {
      await _c.forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    }
    if (mounted) widget.onDone();
  }

  /// Where the hand is and how pressed it is (0 up, 1 down) at time [t] (0..1).
  (Offset, double) _at(double t) {
    final msTotal = _c.duration!.inMilliseconds * t;
    var from = _start, elapsed = 0.0;
    for (final (a, b) in _points) {
      final len = (HandDemo._move + HandDemo._press + (b != null ? HandDemo._drag : 0) + HandDemo._rest).toDouble();
      if (msTotal <= elapsed + len) {
        final local = msTotal - elapsed;
        if (local < HandDemo._move) return (Offset.lerp(from, a, Curves.easeInOut.transform(local / HandDemo._move))!, 0);
        final press = local - HandDemo._move;
        if (b == null) {
          if (press < HandDemo._press) return (a, math.sin(press / HandDemo._press * math.pi));
          return (a, 0);
        }
        // drag: press down, travel holding, then lift
        if (press < HandDemo._press / 2) return (a, press / (HandDemo._press / 2));
        final travel = press - HandDemo._press / 2;
        if (travel < HandDemo._drag) return (Offset.lerp(a, b, Curves.easeInOut.transform(travel / HandDemo._drag))!, 1);
        final lift = travel - HandDemo._drag;
        return (b, (1 - lift / (HandDemo._press / 2)).clamp(0.0, 1.0));
      }
      elapsed += len;
      from = b ?? a;
    }
    return (from, 0);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: _stack,
      children: [
        widget.child,
        if (widget.running)
          Positioned.fill(
            child: GestureDetector(
              key: const Key('hand-demo'),
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _c.stop();
                widget.onDone(); // a tap skips the demo
              },
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  if (_points.isEmpty) return const SizedBox.expand();
                  final (pos, pressed) = _at(_c.value);
                  return Stack(
                    children: [
                      if (pressed > 0)
                        Positioned(
                          left: pos.dx - 26,
                          top: pos.dy - 26,
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: Palette.sunflower.withValues(alpha: 0.45 * pressed)),
                          ),
                        ),
                      // the fingertip of the icon sits on the point
                      Positioned(
                        left: pos.dx - 22,
                        top: pos.dy - 6,
                        child: Transform.scale(
                          scale: 1 - 0.15 * pressed,
                          alignment: Alignment.topLeft,
                          child: const _Hand(key: Key('demo-hand')),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _Hand extends StatelessWidget {
  const _Hand({super.key});

  @override
  Widget build(BuildContext context) => const Stack(
        children: [
          Icon(Icons.touch_app_rounded, size: 76, color: Palette.nightInk), // outline
          Positioned(left: 4, top: 4, child: Icon(Icons.touch_app_rounded, size: 68, color: Palette.white)),
        ],
      );
}

/// Which games each child has already seen the demo of (on the phone only, `demos.v1`). The first time a game opens the
/// demo plays by itself; after that the "?" button plays it again.
class DemoSeenNotifier extends Notifier<Map<String, Set<String>>> {
  static const key = 'demos.v1';

  @override
  Map<String, Set<String>> build() {
    final raw = ref.read(sharedPreferencesProvider).readJson(key);
    if (raw is! Map<String, dynamic>) return const {};
    return raw.map((k, v) => MapEntry(k, ((v as List<dynamic>?) ?? const []).cast<String>().toSet()));
  }

  bool seen(String childId, String activity) => state[childId]?.contains(activity) ?? false;

  Future<void> markSeen(String childId, String activity) async {
    if (seen(childId, activity)) return;
    state = {...state, childId: {...?state[childId], activity}};
    await ref.read(sharedPreferencesProvider).writeJson(key, state.map((k, v) => MapEntry(k, v.toList()..sort())));
  }
}

final demoSeenProvider = NotifierProvider<DemoSeenNotifier, Map<String, Set<String>>>(DemoSeenNotifier.new);

/// The round "?" button that plays the demo again.
class DemoHelpButton extends StatelessWidget {
  const DemoHelpButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Show me',
        child: InkResponse(
          key: const Key('demo-help'),
          onTap: onTap,
          radius: 36,
          child: Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: Palette.white, shape: BoxShape.circle, border: Border.all(color: Palette.nightInk, width: 3)),
              child: const Icon(Icons.question_mark_rounded, size: 30, color: Palette.nightInk),
            ),
          ),
        ),
      );
}
