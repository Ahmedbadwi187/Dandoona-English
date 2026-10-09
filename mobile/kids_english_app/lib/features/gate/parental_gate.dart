import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/palette.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../settings/settings.dart';
import '../../core/type.dart';

/// A multiplication a young child cannot do yet, with 4 answer choices.
class GateChallenge {
  GateChallenge._(this.a, this.b, this.options);

  final int a;
  final int b;
  final List<int> options;

  int get answer => a * b;
  bool isCorrect(int value) => value == answer;
  String get question => '$a × $b = ?';

  factory GateChallenge.random(Random random) {
    final a = 6 + random.nextInt(6); // 6..11
    final b = 3 + random.nextInt(5); // 3..7
    final answer = a * b;
    final options = <int>{answer};
    while (options.length < 4) {
      final delta = (random.nextInt(9) + 1) * (random.nextBool() ? 1 : -1);
      final wrong = answer + delta;
      if (wrong > 0) options.add(wrong);
    }
    return GateChallenge._(a, b, options.toList()..shuffle(random));
  }
}

/// Shows the gate and resolves true only when an adult passes both steps.
/// Used before the parent area, settings, purchases and any external link.
Future<bool> showParentalGate(BuildContext context, {Random? random}) async {
  final passed = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => ParentalGateDialog(random: random),
  );
  return passed ?? false;
}

class ParentalGateDialog extends ConsumerStatefulWidget {
  const ParentalGateDialog({super.key, this.random, this.holdDuration = const Duration(seconds: 2)});

  final Random? random;
  final Duration holdDuration;

  @override
  ConsumerState<ParentalGateDialog> createState() => _ParentalGateDialogState();
}

class _ParentalGateDialogState extends ConsumerState<ParentalGateDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(vsync: this, duration: widget.holdDuration)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) setState(() => _solving = true);
    });
  late final GateChallenge _challenge = GateChallenge.random(widget.random ?? Random());
  bool _solving = false;
  bool _wrong = false;

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  void _answer(int value) {
    if (_challenge.isCorrect(value)) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _wrong = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return Directionality(
      textDirection: s.direction,
      child: AlertDialog(
        title: Text(s('gateTitle'), textAlign: TextAlign.center),
        content: SizedBox(
          width: 320,
          child: _solving ? _buildSolve(s) : _buildHold(s),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(kMinTapTarget, kMinTapTarget)),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(s('cancel')),
          ),
        ],
      ),
    );
  }

  Widget _buildHold(Strings s) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(s('gateHold'), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        GestureDetector(
          key: const Key('gate-hold'),
          onTapDown: (_) => _hold.forward(),
          onTapUp: (_) => _hold.reset(),
          onTapCancel: () => _hold.reset(),
          child: AnimatedBuilder(
            animation: _hold,
            builder: (context, _) => SizedBox(
              width: 96,
              height: 96,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: CircularProgressIndicator(value: _hold.value, strokeWidth: 8, color: Palette.green),
                  ),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(color: Palette.orange, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: const Icon(Icons.touch_app_rounded, color: Palette.white, size: 36),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(s('gateHoldButton')),
      ],
    );
  }

  Widget _buildSolve(Strings s) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(s('gateSolve')),
        const SizedBox(height: 12),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(_challenge.question, key: const Key('gate-question'), style: parentStat.copyWith(fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            for (final option in _challenge.options)
              FilledButton(
                key: Key('gate-option-$option'),
                onPressed: () => _answer(option),
                child: Text('$option'),
              ),
          ],
        ),
        if (_wrong) ...[
          const SizedBox(height: 12),
          Text(s('gateWrong'), style: const TextStyle(color: Palette.red, fontWeight: FontWeight.w700)),
        ],
      ],
    );
  }
}
