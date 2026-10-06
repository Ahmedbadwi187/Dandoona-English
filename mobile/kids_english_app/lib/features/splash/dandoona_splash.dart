import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/palette.dart';
import '../settings/settings.dart';

/// Plays Dandoona's own short greeting ("I'm Dandoona!", from her channel's audio) in the parent's language.
/// Behind a provider so tests use a fake. It uses the system's "ambient" audio category on iOS, so the silent
/// switch mutes it, and Android plays it on the media stream, so a muted phone stays silent. Failures are ignored.
typedef GreetingPlayer = Future<void> Function(String assetPath);

final greetingPlayerProvider = Provider<GreetingPlayer>((ref) {
  AudioPlayer? player;
  ref.onDispose(() => unawaited(player?.dispose()));
  return (assetPath) async {
    try {
      player ??= AudioPlayer();
      await player!.setAudioContext(AudioContextConfig(respectSilence: true).build());
      await player!.play(AssetSource(assetPath));
    } on Object {
      // no audio device, codec problem...: the splash simply stays silent
    }
  };
});

String greetingAsset(String languageCode) =>
    languageCode == 'ar' ? 'audio/brand/dandoona_hello_ar.mp3' : 'audio/brand/dandoona_hello_en.mp3';

/// The first Flutter frame is identical to the native splash (cream background, Dandoona centered), then she
/// bounces, waves and fades away over about 2.3 seconds. The app is built underneath from the start, so it loads
/// in parallel; a tap skips the animation. [enabled] is off in tests.
class DandoonaSplash extends ConsumerStatefulWidget {
  const DandoonaSplash({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  /// Same logical size as the native splash image (512 px / 4 = 128 dp).
  static const double pictureSize = 128;
  static const Duration total = Duration(milliseconds: 2300);

  @override
  ConsumerState<DandoonaSplash> createState() => _DandoonaSplashState();
}

class _DandoonaSplashState extends ConsumerState<DandoonaSplash> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: DandoonaSplash.total);
  bool _done = false;
  bool _greeted = false;

  @override
  void initState() {
    super.initState();
    _done = !widget.enabled;
    if (_done) return;
    _controller.addStatusListener((s) {
      if (s == AnimationStatus.completed) _finish();
    });
    _controller.forward();
  }

  void _finish() {
    if (_done || !mounted) return;
    _controller.stop();
    setState(() => _done = true);
  }

  void _greet() {
    if (_greeted) return;
    _greeted = true;
    unawaited(ref.read(greetingPlayerProvider)(greetingAsset(ref.read(settingsProvider).languageCode)));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Timeline (fractions of 2300 ms): hold 0-0.10, bounce 0.10-0.38, wave 0.38-0.72, fade 0.72-1.0.
  static const _bounceFrom = 0.10, _bounceTo = 0.38, _waveTo = 0.72;

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.child;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        Positioned.fill(child: widget.child),
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              if (t > _bounceFrom) _greet();
              final fade = 1 - Curves.easeIn.transform(((t - _waveTo) / (1 - _waveTo)).clamp(0.0, 1.0));
              return IgnorePointer(
                ignoring: fade <= 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _finish,
                  child: Opacity(
                    opacity: fade,
                    child: ColoredBox(
                      color: Palette.cream,
                      child: Center(child: _Dandoona(t: reduceMotion ? 0 : t)),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Dandoona extends StatelessWidget {
  const _Dandoona({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    var lift = 0.0, squash = 0.0, grow = 0.0, tilt = 0.0;
    if (t > _DandoonaSplashState._bounceFrom) {
      final b = ((t - _DandoonaSplashState._bounceFrom) / (_DandoonaSplashState._bounceTo - _DandoonaSplashState._bounceFrom)).clamp(0.0, 1.0);
      lift = math.sin(b * math.pi) * 46; // one jump
      squash = b >= 1 ? 0 : (b < 0.15 || b > 0.85 ? 0.07 : 0); // squash on take-off and landing
      grow = Curves.easeOut.transform(b) * 0.5; // she gets bigger as she arrives
    }
    if (t > _DandoonaSplashState._bounceTo) {
      grow = 0.5;
      final w = ((t - _DandoonaSplashState._bounceTo) / (_DandoonaSplashState._waveTo - _DandoonaSplashState._bounceTo)).clamp(0.0, 1.0);
      tilt = math.sin(w * math.pi * 6) * 0.11 * (1 - w * 0.4); // wave: a few happy tilts
    }
    return Transform.translate(
      offset: Offset(0, -lift),
      child: Transform(
        alignment: Alignment.bottomCenter,
        transform: Matrix4.identity()
          ..rotateZ(tilt)
          ..scaleByDouble(1 + grow + squash, 1 + grow - squash, 1, 1),
        child: Image.asset(
          'assets/images/mascot/mascot.webp',
          width: DandoonaSplash.pictureSize,
          height: DandoonaSplash.pictureSize,
          semanticLabel: 'Dandoona',
        ),
      ),
    );
  }
}
