import 'package:flutter/material.dart';

/// The two type scales of the app. Every text size comes from here; hierarchy inside a size comes from weight and color.
/// Use `.copyWith(fontWeight: ..., color: ...)` on a style, never a new fontSize. A size outside the scales needs a comment saying why.

// ---- Child area (map, lessons, games, chests, certificates) ----

/// Small labels, star counts.
const kidCaption = TextStyle(fontSize: 18);

/// Instruction text, words in lists.
const kidBody = TextStyle(fontSize: 24);

/// Screen and unit titles, buttons.
const kidTitle = TextStyle(fontSize: 32);

/// The word in Read & Pick and Sight Word Hunt.
const kidGameWord = TextStyle(fontSize: 44);

/// The big letter or number in a circle.
const kidHero = TextStyle(fontSize: 72);

// ---- Parent area ----

const parentCaption = TextStyle(fontSize: 13);
const parentBody = TextStyle(fontSize: 16);
const parentSubtitle = TextStyle(fontSize: 18);
const parentTitle = TextStyle(fontSize: 22);

/// Numbers on the dashboard tiles.
const parentStat = TextStyle(fontSize: 28);

/// How far the phone's text-size setting is respected. The child area stops at 1.3x, the parent area at 1.5x.
const double kidMaxTextScale = 1.3;
const double parentMaxTextScale = 1.5;

/// The routes of the child area; every other route is the parent area.
const _childPrefixes = ['/who', '/map', '/unit', '/certificate', '/wardrobe', '/story', '/review', '/stickers', '/practice', '/chest', '/lesson'];

bool isChildRoute(String path) => _childPrefixes.any((p) => path == p || path.startsWith('$p/'));

/// Clamps the phone's text size for the area [path] belongs to.
Widget clampedTextScale(BuildContext context, String path, Widget child) {
  final max = isChildRoute(path) ? kidMaxTextScale : parentMaxTextScale;
  final mq = MediaQuery.of(context);
  return MediaQuery(data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: max)), child: child);
}

/// Wraps the app and re-clamps the text size whenever the router changes area.
class TextScaleArea extends StatefulWidget {
  const TextScaleArea({super.key, required this.listenable, required this.path, required this.child});

  final Listenable listenable;
  final String Function() path;
  final Widget child;

  @override
  State<TextScaleArea> createState() => _TextScaleAreaState();
}

class _TextScaleAreaState extends State<TextScaleArea> {
  late String _path = widget.path();

  void _changed() {
    // the router notifies while the tree is building, so the rebuild waits for the end of the frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final p = widget.path();
      if (isChildRoute(p) != isChildRoute(_path)) setState(() => _path = p);
    });
  }

  @override
  void initState() {
    super.initState();
    widget.listenable.addListener(_changed);
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => clampedTextScale(context, _path, widget.child);
}
