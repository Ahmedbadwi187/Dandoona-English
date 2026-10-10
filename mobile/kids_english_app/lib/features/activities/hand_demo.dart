import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/loading_action.dart';
import '../../core/palette.dart';
import '../../core/storage.dart';

/// One move of the demo hand: a tap on [target], or a drag from [target] to [to].
class DemoStep {
  const DemoStep.tap(GlobalKey this.target, {this.holdMs = 0})
      : to = null,
        prefix = null,
        toPrefix = null,
        exact = false;
  const DemoStep.drag(GlobalKey this.target, GlobalKey this.to, {this.holdMs = 0})
      : prefix = null,
        toPrefix = null,
        exact = false;

  /// The first piece whose key is a string key starting with [prefix] (the games already key their pieces: 'option-cat', 'card-0'...).
  const DemoStep.tapFirst(String this.prefix, {this.holdMs = 0, this.exact = false})
      : target = null,
        to = null,
        toPrefix = null;

  /// A drag from the first piece with key [from] to the first piece with key [toKey].
  const DemoStep.dragFirst(String from, String toKey, {this.holdMs = 0})
      : prefix = from,
        toPrefix = toKey,
        target = null,
        to = null,
        exact = false;

  final GlobalKey? target;
  final GlobalKey? to;
  final String? prefix;
  final String? toPrefix;

  /// How long the hand stays on the piece after pressing it (a slow demo that says the name of what it touches waits here).
  final int holdMs;

  /// With [exact] the key must be the whole [prefix] (a lesson with "car" and "card").
  final bool exact;

  bool get isDrag => to != null || toPrefix != null;
}

/// Shows how a game is played before the child plays it: a hand moves over the game's own pieces and does each move once
/// (tap, or drag), while the activity has Dandoona explain it in her voice. A tap anywhere skips it. The pieces underneath
/// do not react to the demo, so nothing is answered for the child.
class HandDemo extends StatefulWidget {
  const HandDemo({super.key, required this.child, required this.steps, required this.running, required this.onDone, this.slow = false, this.onPress});

  final Widget child;
  final List<DemoStep> steps;

  /// While true the hand plays; the parent sets it false (or the hand finishes and calls [onDone]).
  final bool running;
  final VoidCallback onDone;

  /// A slower hand, for a demo that names what it touches.
  final bool slow;

  /// Called with the step number at the moment the hand presses it (the lesson screen says the name of the picture then).
  final ValueChanged<int>? onPress;

  static const _move = 550, _press = 350, _drag = 750, _rest = 250; // milliseconds per part of a step

  @override
  State<HandDemo> createState() => _HandDemoState();
}

class _HandDemoState extends State<HandDemo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  final _stack = GlobalKey();
  List<(Offset, Offset?)> _points = const [];
  List<int> _holds = const [];
  int _pressed = -1;

  double get _move => (widget.slow ? 1100 : HandDemo._move).toDouble();
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
    return _localCenter(box);
  }

  Offset? _localCenter(RenderBox? box) {
    final stack = _stack.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || stack == null || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(box.size.center(Offset.zero), ancestor: stack);
  }

  /// The first piece under the demo whose key is a string key starting with [prefix].
  Offset? _centerOfPrefix(String prefix, {bool exact = false}) {
    RenderBox? found;
    void visit(Element e) {
      if (found != null) return;
      final k = e.widget.key;
      if (k is ValueKey<String> && (exact ? k.value == prefix : k.value.startsWith(prefix)) && e.renderObject is RenderBox) {
        found = e.renderObject as RenderBox;
        return;
      }
      e.visitChildren(visit);
    }

    (_stack.currentContext as Element?)?.visitChildren(visit);
    return _localCenter(found);
  }

  /// A drag that starts and ends on the same piece (tracing) sweeps across it instead.
  Offset? _start0(DemoStep s) {
    final c = s.prefix != null ? _centerOfPrefix(s.prefix!, exact: s.exact) : _centerOf(s.target!);
    return c != null && s.prefix != null && s.prefix == s.toPrefix ? c + const Offset(-60, -80) : c;
  }
  Offset? _end0(DemoStep s) {
    final c = s.toPrefix != null ? _centerOfPrefix(s.toPrefix!) : null;
    if (c != null && s.prefix == s.toPrefix) return c + const Offset(60, 80);
    return s.toPrefix != null ? c
        : (s.to == null ? null : _centerOf(s.to!));
  }

  int _stepMs(DemoStep s) => _move.round() + HandDemo._press + (s.isDrag ? HandDemo._drag : 0) + HandDemo._rest + s.holdMs;

  Future<void> _play() async {
    if (!mounted || !widget.running) return;
    final stack = _stack.currentContext?.findRenderObject() as RenderBox?;
    final points = <(Offset, Offset?)>[];
    final holds = <int>[];
    for (final s in widget.steps) {
      final a = _start0(s);
      if (a == null) continue;
      points.add((a, s.isDrag ? (_end0(s) ?? a) : null));
      holds.add(s.holdMs);
    }
    if (points.isEmpty || stack == null) {
      widget.onDone();
      return;
    }
    setState(() {
      _points = points;
      _holds = holds;
      _pressed = -1;
      _start = Offset(stack.size.width * 0.8, stack.size.height * 0.95); // comes in from the bottom corner
    });
    final total = widget.steps.where((s) => _start0(s) != null).fold<int>(0, (t, s) => t + _stepMs(s));
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
    for (final (k, (a, b)) in _points.indexed) {
      final len = _move + HandDemo._press + (b != null ? HandDemo._drag : 0) + HandDemo._rest + _holds[k];
      if (msTotal <= elapsed + len) {
        final local = msTotal - elapsed;
        if (local < _move) return (Offset.lerp(from, a, Curves.easeInOut.transform(local / _move))!, 0);
        final press = local - _move;
        if (k > _pressed) {
          _pressed = k;
          Future.microtask(() => widget.onPress?.call(k)); // the hand has just arrived and presses
        }
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
            child: LoadingTap(
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

/// The demo plays every time a game opens (the child never has to press the "?" first; the "?" plays it again). Off only in tests that
/// are about something else, where the first-time rule (demos.v1) decides.
final autoDemoEveryTimeProvider = Provider<bool>((_) => true);

final demoSeenProvider = NotifierProvider<DemoSeenNotifier, Map<String, Set<String>>>(DemoSeenNotifier.new);

/// The round "?" button that plays the demo again.
class DemoHelpButton extends StatelessWidget {
  const DemoHelpButton({super.key, required this.onTap});

  final LoadingCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Show me',
        child: InkResponse(
          key: const Key('demo-help'),
          onTap: () => runNow(onTap),
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
