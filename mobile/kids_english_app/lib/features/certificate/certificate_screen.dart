import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/palette.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../child/child_scope.dart';
import '../content/content_repository.dart';
import '../gate/parental_gate.dart';
import '../profiles/child_profile.dart';
import '../progress/progress.dart';
import '../session/session.dart';
import '../units/unit_logic.dart';
import '../units/unit_meta.dart';
import '../units/unit_style.dart';
import 'certificate_card.dart';
import 'certificate_sharer.dart';

/// A unit's certificate. The child sees it and can go back; saving or sharing it (a picture made on the device, handed
/// to the system share sheet) sits behind the parental gate.
class CertificateScreen extends ConsumerStatefulWidget {
  const CertificateScreen({super.key, required this.unitId});

  final String unitId;

  @override
  ConsumerState<CertificateScreen> createState() => _CertificateScreenState();
}

class _CertificateScreenState extends ConsumerState<CertificateScreen> {
  final _boundary = GlobalKey();
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    // A finished unit always has its certificate on record (it is dated today if nothing was recorded yet).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final track = await ref.read(activeContentProvider.future);
      final childId = ref.read(activeChildIdProvider);
      final unit = track.unitById(widget.unitId);
      if (!mounted || childId == null || unit == null) return;
      final progress = ref.read(progressProvider.notifier);
      if (isUnitFinished(unit, (id) => progress.hasProgress(childId, id))) {
        await ref.read(unitMetaProvider.notifier).awardCertificate(childId, unit.id, DateTime.now());
      }
    });
  }

  Future<void> _share(String fileName) async {
    if (_sharing) return;
    if (!await showParentalGate(context) || !mounted) return;
    setState(() => _sharing = true);
    try {
      final boundary = _boundary.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) return;
      await ref.read(certificateSharerProvider).share(data.buffer.asUint8List(), fileName);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(activeContentProvider);
    final childId = ref.watch(activeChildIdProvider);
    final child = ref.watch(profilesProvider).where((p) => p.id == childId).firstOrNull;
    final meta = ref.watch(unitMetaProvider);
    return ChildScope(
      child: SessionGuard(
        child: Scaffold(
          body: SafeArea(
            child: content.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(Strings.en('loadError'))),
              data: (track) {
                final unit = track.unitById(widget.unitId);
                if (unit == null || child == null) return Center(child: Text(Strings.en('loadError')));
                final earned = meta.of(child.id).certificates[unit.id];
                return Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        key: const Key('certificate-back'),
                        constraints: const BoxConstraints(minWidth: kMinTapTarget, minHeight: kMinTapTarget),
                        iconSize: 32,
                        onPressed: () => context.canPop() ? context.pop() : context.go('/map'),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: FittedBox(
                          child: RepaintBoundary(
                            key: _boundary,
                            child: CertificateCard(
                              childName: child.name,
                              unitTitle: unit.titleFor('en'),
                              date: prettyDate(earned ?? dateOnly(DateTime.now())),
                              mascot: track.mascot,
                              unitColor: unitColor(unit.color),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // For the parent: behind the gate.
                          Semantics(
                            button: true,
                            label: 'Save or share the certificate (parents only)',
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                IconButton.filled(
                                  key: const Key('certificate-share'),
                                  style: IconButton.styleFrom(backgroundColor: Palette.blue, minimumSize: const Size(kMinTapTarget, kMinTapTarget)),
                                  iconSize: 34,
                                  onPressed: _sharing ? null : () => unawaited(_share('certificate-${unit.id}.png')),
                                  icon: const Icon(Icons.ios_share_rounded, color: Palette.white),
                                ),
                                const Positioned(right: -2, top: -2, child: Icon(Icons.lock_rounded, size: 20, color: Palette.nightInk)),
                              ],
                            ),
                          ),
                          IconButton.filled(
                            key: const Key('certificate-done'),
                            style: IconButton.styleFrom(backgroundColor: Palette.green, minimumSize: const Size(kMinTapTarget * 1.3, kMinTapTarget * 1.3)),
                            iconSize: 44,
                            onPressed: () => context.go('/map'),
                            icon: const Icon(Icons.check_rounded, color: Palette.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
