import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/palette.dart';
import '../../core/sky.dart';
import '../../core/strings.dart';
import '../../core/type.dart';
import '../../core/widgets.dart';
import '../audio/audio_service.dart';
import '../child/child_scope.dart';
import '../content/content_models.dart';
import '../content/content_repository.dart';
import '../content/packs.dart';
import '../gate/parental_gate.dart';
import '../profiles/child_profile.dart';
import '../progress/active_days.dart';
import '../progress/progress.dart';
import '../rewards/accessories.dart';
import '../router_state.dart';
import '../session/session.dart';
import '../settings/settings.dart';
import 'map_art.dart';
import 'map_path.dart';
import 'unit_logic.dart';
import 'unit_meta.dart';
import 'practice_screen.dart';
import 'word_misses.dart';
import 'unit_providers.dart';
import 'unit_style.dart';

/// The short sparkle played when the star counter goes up.
const starSound = 'audio/ui/star.wav';

/// Height of the top bar below the safe area; the map starts under it and scrolls beneath it.
const double mapBarHeight = 84;

// Vertical room each stop takes on the path, and where its center (the line of the path) sits inside that room.
const double _islandSlot = 236, _islandCenter = 52;
const double _currentSlot = 318, _currentCenter = 66;
const double _stationSlot = 112, _stationCenter = 52;
const double _castleSlot = 300, _castleCenter = 70;
const _islandXs = [0.28, 0.72];

/// Where each stop sits on the map (its center, which the path runs through) and how tall the whole path is.
class MapLayout {
  const MapLayout(this.centers, this.height);
  final List<Offset> centers;
  final double height;
}

/// Islands alternate left and right; the stations between two islands are spread along the line between them; the castle
/// is in the middle at the end. Pure so it can be tested.
MapLayout layoutStops(List<MapStop> stops, double width, {double top = 0}) {
  final ys = <double>[];
  var y = top;
  for (final s in stops) {
    final (slot, center) = switch (s.kind) {
      StopKind.unit => s.state == StopState.current ? (_currentSlot, _currentCenter) : (_islandSlot, _islandCenter),
      StopKind.castle => (_castleSlot, _castleCenter),
      _ => (_stationSlot, _stationCenter),
    };
    ys.add(y + center);
    y += slot;
  }
  final xs = List<double>.filled(stops.length, width / 2);
  final islands = <int>[
    for (var i = 0; i < stops.length; i++)
      if (stops[i].isIsland) i,
  ];
  for (var k = 0; k < islands.length; k++) {
    final i = islands[k];
    xs[i] = stops[i].kind == StopKind.castle ? width / 2 : width * _islandXs[k % _islandXs.length];
  }
  for (var k = 0; k + 1 < islands.length; k++) {
    final a = islands[k], b = islands[k + 1];
    for (var i = a + 1; i < b; i++) {
      final t = (i - a) / (b - a);
      xs[i] = xs[a] + (xs[b] - xs[a]) * t;
    }
  }
  return MapLayout([for (var i = 0; i < stops.length; i++) Offset(xs[i], ys[i])], y + 40);
}

/// Repeating movement (Dandoona's idle bounce, the current island's pulse) only when the phone allows motion; tests turn
/// it off through [SkyBackground.drift] like the clouds.
bool _ambientMotion(BuildContext context) => SkyBackground.drift && !MediaQuery.of(context).disableAnimations;

/// The star total last shown on the map, per child, so the counter bounces only when stars were added since.
class ShownStarsNotifier extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => const {};

  void set(String childId, int stars) => state = {...state, childId: stars};
}

final shownStarsProvider = NotifierProvider<ShownStarsNotifier, Map<String, int>>(ShownStarsNotifier.new);

/// The child's home screen: one path through Dandoona's sky with an island per unit, the smaller stations between them
/// (story, treasure chest, review) and the castle at the end. Dandoona stands on the island the child is on.
class UnitMapScreen extends ConsumerWidget {
  const UnitMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(activeContentProvider);
    return ChildScope(
      child: SessionGuard(
        child: Scaffold(
          body: content.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(Strings.en('loadError'), style: kidBody),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => ref
                        ..invalidate(contentProvider)
                        ..invalidate(explorersContentProvider),
                      child: Text(Strings.en('retry')),
                    ),
                  ],
                ),
              ),
            ),
            data: (track) => _UnitMap(track: track),
          ),
        ),
      ),
    );
  }
}

class _UnitMap extends ConsumerStatefulWidget {
  const _UnitMap({required this.track});

  final TrackContent track;

  @override
  ConsumerState<_UnitMap> createState() => _UnitMapState();
}

class _UnitMapState extends ConsumerState<_UnitMap> with TickerProviderStateMixin {
  final _scroll = ScrollController();
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final AnimationController _starBounce = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  bool _scrolledToCurrent = false;
  bool _greeting = true;
  Timer? _greetingTimer;
  String? _bubble;
  Timer? _bubbleTimer;
  List<Offset> _centers = const [];
  int _current = -1;
  double _viewport = 0;

  @override
  void initState() {
    super.initState();
    // "Hi, Omar!" shows for about three seconds, then the bar shrinks back to the avatar.
    _greetingTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _greeting = false);
    });
    Future.microtask(_sayWelcome);
  }

  @override
  void dispose() {
    _greetingTimer?.cancel();
    _bubbleTimer?.cancel();
    _scroll.dispose();
    _shake.dispose();
    _starBounce.dispose();
    super.dispose();
  }

  /// Dandoona's "Welcome back!" for a child who has played before (a new child has just heard her first greeting).
  Future<void> _sayWelcome() async {
    if (!mounted) return;
    final childId = ref.read(activeChildIdProvider);
    final path = widget.track.appAudio?.celebration;
    if (childId == null || path == null || ref.read(progressProvider.notifier).totalStars(childId) == 0) return;
    unawaited(ref.read(audioServiceProvider).playAsset(path));
  }

  void _showBubble(String text) {
    _bubbleTimer?.cancel();
    setState(() => _bubble = text);
    _bubbleTimer = Timer(const Duration(milliseconds: 2800), () {
      if (mounted) setState(() => _bubble = null);
    });
  }

  /// Brings Dandoona's island back into view when the child tapped somewhere far away from her.
  void _revealDandoona() {
    if (_current < 0 || !_scroll.hasClients) return;
    final y = _centers[_current].dy;
    // her speech bubble needs about 200 dp above the island's center, below the top bar
    final top = _scroll.offset + MediaQuery.paddingOf(context).top + mapBarHeight + 200, bottom = _scroll.offset + _viewport - 120;
    if (y > top && y < bottom) return;
    unawaited(_scroll.animateTo(_targetOffset(y), duration: const Duration(milliseconds: 600), curve: Curves.easeInOut));
  }

  double _targetOffset(double y) {
    final max = _scroll.hasClients ? _scroll.position.maxScrollExtent : double.infinity;
    return (y - _viewport / 2 + 40).clamp(0.0, max);
  }

  /// A closed stop: Dandoona shakes her head kindly and says what comes first.
  Future<void> _closed(MapStop tapped, List<MapStop> stops) async {
    final audio = ref.read(audioServiceProvider);
    final blocker = blockingStop(stops);
    final String text;
    String? line;
    final appLines = widget.track.appAudio?.lines ?? const <String, String>{};
    if (tapped.state == StopState.soon) {
      text = Strings.en('mapComingSoon');
      line = appLines['coming-soon'];
    } else if (blocker != null && blocker.kind == StopKind.unit) {
      text = Strings.en('mapFinishFirst').replaceAll('{unit}', blocker.unit!.unit.titleFor('en'));
      line = blocker.unit!.unit.audio?.locked;
    } else {
      text = Strings.en('mapPuzzleFirst');
      line = appLines['puzzle-first'];
    }
    _showBubble(text);
    _revealDandoona();
    unawaited(_shake.forward(from: 0));
    // her voice: the island's name first ("Colors!"), then what to do
    final name = tapped.unit?.unit.audio?.title;
    if (tapped.isIsland && name != null) await audio.playAsset(name);
    if (line != null && mounted) await audio.playAsset(line);
  }

  void _openUnit(MapStop stop, List<MapStop> stops) {
    if (stop.state == StopState.locked || stop.state == StopState.soon) {
      unawaited(_closed(stop, stops));
      return;
    }
    final unit = stop.unit!.unit;
    final audio = unit.audio?.title;
    if (audio != null) unawaited(ref.read(audioServiceProvider).playAsset(audio));
    if (unit.needsDownload) {
      // its pack is still on the way: a calm word for the child (the parent area says when it needs internet)
      _showBubble(Strings.en('mapAlmostReady'));
      _revealDandoona();
      final almost = widget.track.appAudio?.lines['almost-ready'];
      if (almost != null) unawaited(ref.read(audioServiceProvider).playAsset(almost));
      unawaited(ref.read(packDownloadsProvider.notifier).ensure(unit));
      return;
    }
    context.push('/unit/${unit.id}');
  }

  void _openStation(MapStop stop, List<MapStop> stops) {
    if (stop.state == StopState.locked || stop.state == StopState.soon) {
      unawaited(_closed(stop, stops));
      return;
    }
    if (stop.kind == StopKind.chest) {
      // ready: the opening; done: what was inside (the chest screen tells the two apart)
      unawaited(context.push('/chest/${stop.unit!.unit.id}'));
      return;
    }
    if (stop.kind == StopKind.review || stop.kind == StopKind.castle) {
      unawaited(context.push('/review/${stop.id}')); // ready: the game (passing it opens the next unit); done: play again
      return;
    }
    if (stop.kind == StopKind.story) {
      unawaited(context.push('/story/${stop.unit!.unit.id}')); // ready: the story (read to the end it is done); done: read it again
      return;
    }
  }

  Future<void> _openParentArea() async {
    if (await showParentalGate(context) && mounted) {
      ref.read(parentSessionProvider.notifier).unlock();
      context.go('/parent');
    }
  }

  /// Fetches the packs of the unit the child is on and the next one, in the background (each once at a time).
  void _prefetch(List<MapStop> stops) {
    final wanted = unitsToPrefetch(stops);
    final refresh = unitsToRefresh(stops); // packs already here: is there a newer version?
    if (wanted.isEmpty && refresh.isEmpty) return;
    final downloads = ref.read(packDownloadsProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final u in wanted) {
        if (downloads[u.id] != PackDownload.downloading) unawaited(ref.read(packDownloadsProvider.notifier).ensure(u));
      }
      for (final u in refresh) {
        unawaited(ref.read(packDownloadsProvider.notifier).refresh(u));
      }
    });
  }

  void _checkStars(String? childId, int stars) {
    if (childId == null) return;
    final shown = ref.read(shownStarsProvider)[childId];
    if (shown == stars) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(shownStarsProvider.notifier).set(childId, stars);
      if (shown != null && stars > shown) {
        unawaited(_starBounce.forward(from: 0));
        unawaited(ref.read(audioServiceProvider).playAsset(starSound));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final migration = ref.watch(unitMigrationProvider);
    if (migration.isLoading) return const Center(child: CircularProgressIndicator());

    final track = widget.track;
    final childId = ref.watch(activeChildIdProvider);
    final child = ref.watch(profilesProvider).where((p) => p.id == childId).firstOrNull;
    ref.watch(progressProvider);
    final progress = ref.read(progressProvider.notifier);
    final unlockAll = ref.watch(settingsProvider).unlockAll;
    final meta = childId == null ? const ChildUnitMeta() : ref.watch(unitMetaProvider).of(childId);
    final statuses = computeUnitStatuses(
      track.units,
      (lessonId) => childId != null && progress.hasProgress(childId, lessonId),
      unlockAll: unlockAll,
      placedUnits: meta.placed,
    );
    final stops = buildMapPath(units: statuses, reviews: track.reviews, meta: meta, unlockAll: unlockAll);
    _prefetch(stops);
    final stars = childId == null ? 0 : progress.totalStars(childId);
    _checkStars(childId, stars);

    var current = currentStopIndex(stops);
    if (current < 0 && stops.last.state == StopState.done) current = stops.length - 1; // the whole track is done: she waits at the castle
    _current = current;

    ref.watch(wordMissesProvider); // the Practice button appears when words are waiting
    final practiceWords = childId == null ? 0 : practiceItems(track, ref.read(wordMissesProvider.notifier).of(childId)).length;
    final safeTop = MediaQuery.paddingOf(context).top;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        _viewport = constraints.maxHeight;
        // Explorers shows the active-days badge under the top bar: the path starts below it, so it never covers the first island
        final layout = layoutStops(stops, width, top: safeTop + mapBarHeight + 24 + (track.track == explorersTrack ? 56 : 0));
        _centers = layout.centers;
        if (!_scrolledToCurrent && current >= 0) {
          _scrolledToCurrent = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _scroll.hasClients) _scroll.jumpTo(_targetOffset(layout.centers[current].dy));
          });
        }
        final motion = _ambientMotion(context);
        return MapLook(
          mature: track.track == explorersTrack,
          child: Stack(
            children: [
              Positioned.fill(
                child: SkyBackground(mature: track.track == explorersTrack, child: const SizedBox.expand()),
              ),
              Positioned.fill(
                child: SingleChildScrollView(
                  key: const Key('unit-map'),
                  controller: _scroll,
                  child: SizedBox(
                    width: width,
                    height: layout.height + safeBottom,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(child: CustomPaint(painter: SkyPathPainter(layout.centers))),
                        for (var i = 0; i < stops.length; i++)
                          _positioned(stops, i, layout.centers[i], current == i ? _dandoona(track.mascot, child, motion) : null, motion),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _TopBar(
                  avatarKey: child?.avatarKey ?? 'dandoona',
                  name: child?.name ?? '',
                  stars: stars,
                  greeting: _greeting,
                  newOutfit: stops.any((s) => s.kind == StopKind.chest && s.state == StopState.ready),
                  starBounce: _starBounce,
                  onAvatar: () => context.go('/who'),
                  onWardrobe: () => context.push('/wardrobe'),
                  onStickers: () => context.push('/stickers'),
                  onParent: _openParentArea,
                ),
              ),
              // Explorers: the active days, celebrated, never reset (the Little Learners map stays as it was)
              if (track.track == explorersTrack && childId != null)
                Positioned(
                  left: 12,
                  top: safeTop + mapBarHeight + 10,
                  child: ActiveDaysBadge(key: ValueKey('days-$childId'), childId: childId),
                ),
              if (practiceWords > 0)
                Positioned(
                  right: 16,
                  bottom: safeBottom + 16,
                  child: BigTap(
                    key: const Key('open-practice'),
                    onTap: () => context.push('/practice'),
                    semanticLabel: 'Practice',
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Palette.orange,
                        shape: BoxShape.circle,
                        border: Border.all(color: Palette.nightInk, width: 3),
                        boxShadow: [BoxShadow(color: Palette.nightInk.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))],
                      ),
                      child: const Icon(Icons.replay_rounded, size: 38, color: Palette.white),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _positioned(List<MapStop> stops, int i, Offset c, Widget? dandoona, bool motion) {
    final stop = stops[i];
    switch (stop.kind) {
      case StopKind.unit:
        final scale = stop.state == StopState.current ? 1.25 : 1.0;
        return Positioned(
          left: c.dx - 115,
          top: c.dy - 35 * scale - 6,
          width: 230,
          child: _IslandTile(stop: stop, scale: scale, dandoona: dandoona, motion: motion, onOpen: () => _openUnit(stop, stops)),
        );
      case StopKind.castle:
        return Positioned(
          left: c.dx - 115,
          top: c.dy - 35 * 1.35 - 6,
          width: 230,
          child: _CastleTile(stop: stop, dandoona: dandoona, motion: motion, onOpen: () => _openStation(stop, stops)),
        );
      case StopKind.story:
      case StopKind.chest:
      case StopKind.review:
        return Positioned(
          left: c.dx - _StationNode.size / 2,
          top: c.dy - _StationNode.size / 2,
          child: _StationNode(stop: stop, motion: motion, dandoona: dandoona, onTap: () => _openStation(stop, stops)),
        );
    }
  }

  /// Dandoona standing on the current island: a gentle idle bounce, a head shake when a closed stop is tapped, and her
  /// speech bubble above her.
  Widget _dandoona(String? mascot, ChildProfile? child, bool motion) {
    if (mascot == null) return const SizedBox.shrink();
    return _Dandoona(key: const Key('map-dandoona'), mascot: mascot, accessoryId: child?.equippedAccessory, bubble: _bubble, shake: _shake, bounce: motion);
  }
}

class _Dandoona extends StatefulWidget {
  const _Dandoona({super.key, required this.mascot, required this.accessoryId, required this.bubble, required this.shake, required this.bounce});

  final String mascot;
  final String? accessoryId;
  final String? bubble;
  final Animation<double> shake;
  final bool bounce;

  @override
  State<_Dandoona> createState() => _DandoonaState();
}

class _DandoonaState extends State<_Dandoona> with SingleTickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void initState() {
    super.initState();
    if (widget.bounce) _idle.repeat(reverse: true);
  }

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: Listenable.merge([_idle, widget.shake]),
            builder: (context, child) {
              final hop = Curves.easeInOut.transform(_idle.value) * -7;
              // a kind "no-no": three small turns that fade out
              final s = widget.shake.value;
              final turn = s == 0 || s == 1 ? 0.0 : math.sin(s * math.pi * 6) * 0.16 * (1 - s);
              return Transform.translate(
                offset: Offset(0, hop),
                child: Transform.rotate(angle: turn, child: child),
              );
            },
            child: _MascotWithAccessory(mascot: widget.mascot, accessoryId: widget.accessoryId),
          ),
          if (widget.bubble != null)
            Positioned(
              bottom: 86,
              right: 0,
              child: _SpeechBubble(key: const Key('dandoona-says'), text: widget.bubble!, tailRight: true),
            ),
        ],
      ),
    );
  }
}

class _MascotWithAccessory extends StatelessWidget {
  const _MascotWithAccessory({required this.mascot, required this.accessoryId});

  final String mascot;
  final String? accessoryId;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Dandoona',
    child: MascotStage(mascotAsset: mascot, size: 84, accessoryId: accessoryId, markWorn: false),
  );
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({super.key, required this.text, this.tailRight = false});

  final String text;
  final bool tailRight;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Palette.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Palette.nightInk, width: 3),
          boxShadow: [BoxShadow(color: Palette.nightInk.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: kidBody.copyWith(fontWeight: FontWeight.w900, color: Palette.nightInk, height: 1.15),
        ),
      ),
    );
  }
}

/// The unit's name under its island: dark text on a white pill so it reads on the light sky.
class _Label extends StatelessWidget {
  const _Label({super.key, required this.text, required this.big});

  final String text;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: Palette.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.nightInk.withValues(alpha: 0.25), width: 2),
      ),
      child: Text(
        text,
        style: (big ? kidBody : kidCaption).copyWith(fontWeight: FontWeight.w900, color: Palette.nightInk),
      ),
    );
  }
}

class _IslandTile extends StatefulWidget {
  const _IslandTile({required this.stop, required this.scale, required this.dandoona, required this.motion, required this.onOpen});

  final MapStop stop;
  final double scale;
  final Widget? dandoona;
  final bool motion;
  final VoidCallback onOpen;

  @override
  State<_IslandTile> createState() => _IslandTileState();
}

class _IslandTileState extends State<_IslandTile> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  bool get _current => widget.stop.state == StopState.current;

  @override
  void initState() {
    super.initState();
    if (_current && widget.motion) _pulse.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.stop.unit!;
    final unit = status.unit;
    final state = widget.stop.state;
    final title = unit.titleFor('en');
    Widget island(double? glow) => _Island(
      waiting: unit.needsDownload && (state == StopState.current || state == StopState.done),
      glow: glow,
      color: unitColor(unit.color),
      icon: unitIcon(unit.icon),
      id: unit.id,
      state: state,
      scale: widget.scale,
      progress: _current ? (status.total == 0 ? 0 : status.done / status.total) : null,
      progressText: '${status.done}/${status.total}',
      dandoona: widget.dandoona,
    );
    return Semantics(
      container: true,
      label:
          '$title, ${switch (state) {
            StopState.done => 'finished',
            StopState.current => 'open, ${status.done} of ${status.total}',
            StopState.locked => 'locked',
            StopState.soon => 'coming soon',
            StopState.ready => 'open',
          }}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            key: Key('unit-${unit.id}'),
            behavior: HitTestBehavior.opaque,
            onTap: widget.onOpen,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_current)
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, _) =>
                        Transform.scale(scale: 1 + 0.03 * Curves.easeInOut.transform(_pulse.value), child: island(Curves.easeInOut.transform(_pulse.value))),
                  )
                else
                  island(null),
                const SizedBox(height: 2),
                _Label(key: Key('unit-title-${unit.id}'), text: title, big: _current),
              ],
            ),
          ),
          if (state == StopState.done && !status.placed)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: BigTap(
                key: Key('unit-certificate-${unit.id}'),
                semanticLabel: Strings.en('certificate'),
                onTap: () => context.push('/certificate/${unit.id}'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Palette.sunflower,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Palette.nightInk, width: 2.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.workspace_premium_rounded, size: 28, color: Palette.nightInk),
                      const SizedBox(width: 4),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            Strings.en('certificate'),
                            style: kidCaption.copyWith(fontWeight: FontWeight.w900, color: Palette.nightInk),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_current)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: BigTap(
                key: Key('unit-play-${unit.id}'),
                semanticLabel: 'Play $title',
                onTap: widget.onOpen,
                child: Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: Palette.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Palette.nightInk, width: 4),
                    boxShadow: [BoxShadow(color: Palette.nightInk.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 4))],
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Palette.white, size: 54),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A floating island in the unit's own soft color, with the unit's picture on a round badge. Not reached yet: muted, the
/// picture faded, and a lock badge (or a "Soon" ribbon when the unit is not built yet). The current island has a progress
/// ring around the badge, and Dandoona stands on it.
class _Island extends StatelessWidget {
  const _Island({
    required this.color,
    required this.icon,
    required this.id,
    required this.state,
    required this.scale,
    this.progress,
    this.progressText,
    this.dandoona,
    this.glow,
    this.waiting = false,
  });

  /// Open, but its content pack is not on this device yet: a small cloud badge instead of a lock.
  final bool waiting;

  /// The current island's soft pulsing glow around its badge (0..1), null for no glow.
  final double? glow;

  final Color color;
  final IconData icon;
  final String id;
  final StopState state;
  final double scale;
  final double? progress;
  final String? progressText;
  final Widget? dandoona;

  @override
  Widget build(BuildContext context) {
    final closed = state == StopState.locked || state == StopState.soon;
    final grass = closed ? mutedTint(color, amount: 0.6) : MapLook.grass(context, color);
    final soil = closed ? mutedTint(Palette.brown, amount: 0.5) : MapLook.soil(context);
    final badge = closed ? mutedTint(color, amount: 0.35) : color;
    final s = scale;
    final ring = progress != null;
    final badgeSize = 70 * s;
    return SizedBox(
      width: 150 * s,
      height: 118 * s,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            bottom: 0,
            child: Container(
              width: 118 * s,
              height: 44 * s,
              decoration: BoxDecoration(
                color: soil,
                borderRadius: BorderRadius.vertical(top: Radius.circular(8 * s), bottom: Radius.circular(60 * s)),
              ),
            ),
          ),
          Positioned(
            bottom: 30 * s,
            child: Container(
              width: 140 * s,
              height: 46 * s,
              decoration: BoxDecoration(
                color: grass,
                borderRadius: BorderRadius.circular(40 * s),
                border: Border.all(color: closed ? Palette.nightInk.withValues(alpha: 0.45) : Palette.nightInk, width: 3),
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                color: badge,
                shape: BoxShape.circle,
                border: Border.all(color: closed ? Palette.nightInk.withValues(alpha: 0.45) : Palette.nightInk, width: 4),
                boxShadow: glow == null
                    ? null
                    : [
                        BoxShadow(
                          color: Palette.sunflower.withValues(alpha: 0.7 + 0.3 * glow!),
                          blurRadius: 26 + 14 * glow!,
                          spreadRadius: 10 + 8 * glow!,
                        ),
                      ],
              ),
              child: Icon(
                icon,
                size: 42 * s,
                color: Palette.white.withValues(alpha: closed ? 0.75 : 1),
                key: Key('unit-icon-$id'),
              ),
            ),
          ),
          if (ring)
            Positioned(
              top: -9,
              child: Semantics(
                key: Key('unit-progress-$id'),
                value: progressText,
                child: CustomPaint(
                  size: Size.square(badgeSize + 18),
                  painter: ProgressRingPainter(value: progress!),
                ),
              ),
            ),
          if (state == StopState.locked)
            Positioned(
              top: 44 * s,
              left: 75 * s + 14 * s,
              child: _Badge(
                key: Key('unit-lock-$id'),
                color: Palette.white,
                child: const Icon(Icons.lock_rounded, size: 18, color: Palette.nightInk),
              ),
            ),
          if (waiting)
            Positioned(
              top: 44 * s,
              left: 75 * s + 14 * s,
              child: _Badge(
                key: Key('unit-waiting-$id'),
                color: Palette.white,
                child: const Icon(Icons.cloud_download_rounded, size: 18, color: Palette.blue),
              ),
            ),
          if (state == StopState.soon)
            Positioned(
              top: 52 * s,
              child: Transform.rotate(
                angle: -0.08,
                child: Container(
                  key: Key('unit-soon-$id'),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: Palette.plum,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Palette.white, width: 2.5),
                  ),
                  child: Text(
                    Strings.en('mapSoon'),
                    style: kidCaption.copyWith(fontWeight: FontWeight.w900, color: Palette.white),
                  ),
                ),
              ),
            ),
          if (state == StopState.done)
            Positioned(
              top: -4,
              right: 22 * s,
              child: Container(
                key: Key('unit-done-$id'),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Palette.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Palette.white, width: 3),
                ),
                child: const Icon(Icons.check_rounded, color: Palette.white, size: 24),
              ),
            ),
          if (dandoona != null) Positioned(top: 52 * s - 84, left: 75 * s + 22 * s, child: dandoona!),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({super.key, required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: 30,
    height: 30,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Palette.nightInk, width: 2.5),
    ),
    child: Center(child: child),
  );
}

/// The end of the path: the castle with the final review and the track certificate.
class _CastleTile extends StatelessWidget {
  const _CastleTile({required this.stop, required this.dandoona, required this.motion, required this.onOpen});

  final MapStop stop;
  final Widget? dandoona;
  final bool motion;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final ready = stop.state == StopState.ready;
    final island = _Island(
      color: Palette.sunflower,
      icon: Icons.castle_rounded,
      id: castleId,
      state: stop.state,
      scale: 1.35,
      dandoona: dandoona,
      glow: ready ? 1 : null,
    );
    return Semantics(
      container: true,
      label: '${Strings.en('mapCastle')}, ${stop.state == StopState.locked ? 'locked' : 'open'}',
      child: GestureDetector(
        key: const Key('stop-castle'),
        behavior: HitTestBehavior.opaque,
        onTap: onOpen,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                island,
                // little flags on the castle island
                Positioned(
                  top: 60,
                  left: 4,
                  child: Icon(Icons.flag_rounded, size: 30, color: stop.state == StopState.locked ? mutedTint(Palette.red) : Palette.red),
                ),
                Positioned(
                  top: 60,
                  right: 4,
                  child: Icon(Icons.flag_rounded, size: 30, color: stop.state == StopState.locked ? mutedTint(Palette.blue) : Palette.blue),
                ),
              ],
            ),
            const SizedBox(height: 2),
            _Label(text: Strings.en('mapCastle'), big: true),
          ],
        ),
      ),
    );
  }
}

/// A station between islands: a story (book), a treasure chest, or a review (puzzle). Smaller than an island, still at
/// least 72 dp to tap.
class _StationNode extends StatefulWidget {
  const _StationNode({required this.stop, required this.motion, required this.onTap, this.dandoona});

  static const double size = 72;

  final MapStop stop;
  final bool motion;
  final VoidCallback onTap;

  /// Dandoona waits beside a review that is ready to play.
  final Widget? dandoona;

  @override
  State<_StationNode> createState() => _StationNodeState();
}

class _StationNodeState extends State<_StationNode> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));

  @override
  void initState() {
    super.initState();
    if (widget.stop.state == StopState.ready && widget.motion) _pulse.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stop = widget.stop;
    final closed = stop.state == StopState.locked || stop.state == StopState.soon;
    final base = switch (stop.kind) {
      StopKind.story => Palette.teal,
      StopKind.review => Palette.purple,
      _ => Palette.sunflower,
    };
    final fill = closed ? mutedTint(base, amount: 0.45) : base;
    final Widget picture = switch (stop.kind) {
      StopKind.story => Icon(Icons.auto_stories_rounded, size: 38, color: Palette.white.withValues(alpha: closed ? 0.8 : 1)),
      StopKind.review => Icon(Icons.extension_rounded, size: 38, color: Palette.white.withValues(alpha: closed ? 0.8 : 1)),
      _ => CustomPaint(
        size: const Size(46, 46),
        painter: ChestPainter(open: stop.state == StopState.done, muted: closed),
      ),
    };
    final name = Strings.en(switch (stop.kind) {
      StopKind.story => 'mapStory',
      StopKind.review => 'mapReview',
      _ => 'mapChest',
    });
    final node = Container(
      width: _StationNode.size,
      height: _StationNode.size,
      decoration: BoxDecoration(
        color: stop.kind == StopKind.chest ? (closed ? mutedTint(Palette.tan, amount: 0.3) : Palette.cream) : fill,
        shape: BoxShape.circle,
        border: Border.all(color: closed ? Palette.nightInk.withValues(alpha: 0.45) : Palette.nightInk, width: 3.5),
      ),
      child: Center(child: picture),
    );
    return Semantics(
      button: true,
      label:
          '$name, ${switch (stop.state) {
            StopState.done => 'done',
            StopState.ready => 'open',
            _ => 'locked',
          }}',
      child: GestureDetector(
        key: Key('stop-${stop.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: SizedBox(
          width: _StationNode.size,
          height: _StationNode.size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) {
                  if (stop.state != StopState.ready) return child!;
                  final t = Curves.easeInOut.transform(_pulse.value);
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Palette.sunflower.withValues(alpha: 0.8), blurRadius: 18 + 10 * t, spreadRadius: 3 + 4 * t)],
                    ),
                    child: Transform.scale(scale: 1 + 0.05 * t, child: child),
                  );
                },
                child: node,
              ),
              if (stop.state == StopState.locked)
                const Positioned(
                  right: -6,
                  bottom: -4,
                  child: _Badge(
                    color: Palette.white,
                    child: Icon(Icons.lock_rounded, size: 18, color: Palette.nightInk),
                  ),
                ),
              if (widget.dandoona != null) Positioned(left: _StationNode.size - 4, top: -30, child: widget.dandoona!),
              if (stop.state == StopState.done && stop.kind != StopKind.chest)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Palette.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Palette.white, width: 3),
                    ),
                    child: const Icon(Icons.check_rounded, color: Palette.white, size: 20),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The bar over the map: the child's avatar (back to "Who is playing?"), Dandoona's greeting for a few seconds, the
/// stars, the wardrobe and the small parent button (behind the parental gate). It stays put while the map scrolls.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.avatarKey,
    required this.name,
    required this.stars,
    required this.greeting,
    required this.newOutfit,
    required this.starBounce,
    required this.onAvatar,
    required this.onWardrobe,
    required this.onStickers,
    required this.onParent,
  });

  final String avatarKey;
  final String name;
  final int stars;
  final bool greeting;
  final bool newOutfit;
  final Animation<double> starBounce;
  final VoidCallback onAvatar;
  final VoidCallback onWardrobe;
  final VoidCallback onStickers;
  final VoidCallback onParent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFD).withValues(alpha: 0.97),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Palette.nightInk.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: mapBarHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                BigTap(key: const Key('map-avatar'), semanticLabel: Strings.en('mapWhoIsPlaying'), onTap: onAvatar, child: AvatarCircle(avatarKey, size: 60)),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeInOut,
                      alignment: Alignment.centerLeft,
                      child: greeting
                          ? Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: _SpeechBubble(key: const Key('greeting'), text: '${Strings.en('hi')}, $name!'),
                              ),
                            )
                          : const SizedBox(width: 0, height: 0),
                    ),
                  ),
                ),
                ScaleTransition(
                  scale: TweenSequence<double>([
                    TweenSequenceItem(tween: Tween<double>(begin: 1, end: 1.3).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
                    TweenSequenceItem(tween: Tween<double>(begin: 1.3, end: 1).chain(CurveTween(curve: Curves.elasticOut)), weight: 60),
                  ]).animate(starBounce),
                  child: Container(
                    key: const Key('map-stars'),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Palette.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Palette.nightInk, width: 3),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, color: Palette.sunflower, size: 30),
                        const SizedBox(width: 2),
                        Text(
                          '$stars',
                          key: const Key('total-stars'),
                          style: kidBody.copyWith(fontWeight: FontWeight.w900, color: Palette.nightInk),
                        ),
                      ],
                    ),
                  ),
                ),
                BigTap(
                  key: const Key('open-wardrobe'),
                  onTap: onWardrobe,
                  semanticLabel: 'Wardrobe',
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Palette.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Palette.nightInk, width: 3),
                        ),
                        child: const Center(
                          child: CustomPaint(size: Size(32, 32), painter: WardrobePainter()),
                        ),
                      ),
                      if (newOutfit)
                        Positioned(
                          right: -1,
                          top: -1,
                          child: Container(
                            key: const Key('wardrobe-new'),
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: Palette.red,
                              shape: BoxShape.circle,
                              border: Border.all(color: Palette.white, width: 3),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                BigTap(
                  key: const Key('open-stickers'),
                  onTap: onStickers,
                  semanticLabel: Strings.en('mapStickers'),
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Palette.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Palette.nightInk, width: 3),
                    ),
                    child: const Icon(Icons.collections_bookmark_rounded, size: 28, color: Palette.plum),
                  ),
                ),
                BigTap(
                  key: const Key('map-parent'),
                  onTap: onParent,
                  semanticLabel: Strings.en('mapParent'),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Palette.cream,
                      shape: BoxShape.circle,
                      border: Border.all(color: Palette.nightInk.withValues(alpha: 0.5), width: 2),
                    ),
                    child: Icon(Icons.lock_rounded, size: 28, color: Palette.nightInk.withValues(alpha: 0.75)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
