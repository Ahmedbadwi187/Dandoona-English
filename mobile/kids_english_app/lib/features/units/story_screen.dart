import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/loading_action.dart';
import '../../core/palette.dart';
import '../../core/sky.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../audio/audio_service.dart';
import '../child/child_scope.dart';
import '../content/content_models.dart';
import '../content/content_repository.dart';
import '../content/packs.dart';
import '../onboarding/onboarding_widgets.dart';
import '../profiles/child_profile.dart';
import '../session/session.dart';
import 'unit_meta.dart';
import '../../core/type.dart';

/// A unit's picture story: one page at a time with a few pictures of the unit's words, Dandoona's pose and the sentence she reads
/// out loud (tap the sentence to hear it again, tap a picture to hear its word). The last page ends with "The end!"; reading to the
/// end is remembered and gives the story stop its check mark.
class StoryScreen extends ConsumerStatefulWidget {
  const StoryScreen({super.key, required this.unitId});

  final String unitId;

  @override
  ConsumerState<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends ConsumerState<StoryScreen> {
  int _page = 0;
  late final AudioService _audio;
  bool _spoken = false;

  @override
  void initState() {
    super.initState();
    _audio = ref.read(audioServiceProvider);
  }

  @override
  void dispose() {
    unawaited(_audio.stop());
    super.dispose();
  }

  Future<void> _say(StoryPage page) => _audio.playAsset(page.audio);

  DandoonaPose _pose(String? name) => switch (name) {
        'jumping' => DandoonaPose.jumping,
        'clapping' => DandoonaPose.clapping,
        'thinking' => DandoonaPose.thinking,
        'pointing-up' => DandoonaPose.pointingUp,
        'base' => DandoonaPose.base,
        _ => DandoonaPose.waving,
      };

  Future<void> _finish() async {
    final childId = ref.read(activeChildIdProvider);
    if (childId != null) await ref.read(unitMetaProvider.notifier).readStory(childId, widget.unitId);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final track = ref.watch(activeContentProvider).asData?.value;
    final unit = track?.unitById(widget.unitId);
    final story = unit?.story;

    // The pictures are the unit's own, so a unit whose pack is not on the phone yet waits for it.
    if (unit != null && unit.needsDownload && ref.watch(packDownloadsProvider)[unit.id] == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(ref.read(packDownloadsProvider.notifier).ensure(unit)));
    }

    Widget body;
    if (track == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (story == null || story.pages.isEmpty || unit == null || unit.lessons.isEmpty) {
      body = _Waiting(onBack: () => context.pop());
    } else {
      final page = story.pages[_page.clamp(0, story.pages.length - 1)];
      final last = _page >= story.pages.length - 1;
      if (!_spoken) {
        _spoken = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _say(page));
      }
      body = _Page(
        key: ValueKey('story-page-$_page'),
        unit: unit,
        page: page,
        pose: _pose(page.pose),
        index: _page,
        total: story.pages.length,
        last: last,
        audio: _audio,
        onSay: () => _say(page),
        onNext: () {
          setState(() => _page++);
          _spoken = false;
        },
        onDone: _finish,
      );
    }

    return ChildScope(
      child: SessionGuard(
        child: Scaffold(
          body: SkyBackground(
            child: SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                      child: LoadingAction(onPressed: () => context.pop(), builder: (onPressed, loading) => IconButton(
                        key: const Key('story-back'),
                        constraints: const BoxConstraints(minWidth: kMinTapTarget, minHeight: kMinTapTarget),
                        iconSize: 32,
                        onPressed: onPressed,
                        icon: LoadingContent(loading: loading, child: const Icon(Icons.arrow_back_rounded)),
                      )),
                    ),
                  ),
                  Expanded(child: body),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({super.key, required this.unit, required this.page, required this.pose, required this.index, required this.total, required this.last, required this.audio, required this.onSay, required this.onNext, required this.onDone});

  final CourseUnit unit;
  final StoryPage page;
  final DandoonaPose pose;
  final int index;
  final int total;
  final bool last;
  final AudioService audio;
  final LoadingCallback onSay;
  final VoidCallback onNext;
  final Future<void> Function() onDone;

  LessonWord? _word(String w) {
    for (final l in unit.lessons) {
      for (final x in l.words) {
        if (x.word.toLowerCase() == w.toLowerCase()) return x;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final words = [for (final w in page.words) ?_word(w)];
    final pictureSize = switch (words.length) { 0 => 0.0, 1 => 240.0, 2 => 170.0, _ => 118.0 };
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < total; i++)
              Container(
                key: Key('story-dot-$i'),
                width: i == index ? 26 : 12,
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                decoration: BoxDecoration(color: i <= index ? Palette.plum : Palette.gray.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(8)),
              ),
          ],
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (words.isNotEmpty)
                    Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final w in words)
                          LoadingTap(
                            key: Key('story-picture-${w.word}'),
                            onTap: () => audio.playAsset(w.audio),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(28), border: Border.all(color: Palette.sunflower, width: 4)),
                              child: AssetPicture(w.image, size: pictureSize, semanticLabel: w.word),
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  DandoonaView(key: const Key('story-dandoona'), pose: pose, size: words.isEmpty ? 230 : 130),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            children: [
              LoadingTap(
                key: const Key('story-text'),
                onTap: onSay,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), border: Border.all(color: Palette.nightInk, width: 3)),
                  child: Row(
                    children: [
                      Expanded(child: Text(page.text, style: kidBody.copyWith(fontWeight: FontWeight.w800, color: Palette.nightInk, height: 1.25))),
                      const SizedBox(width: 8),
                      const Icon(Icons.volume_up_rounded, color: Palette.plum, size: 32),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: last
                    ? LoadingAction(onPressed: () => onDone(), builder: (onPressed, loading) => FilledButton(
                        key: const Key('story-done'),
                        style: FilledButton.styleFrom(backgroundColor: Palette.green, minimumSize: const Size.fromHeight(kMinTapTarget * 1.1)),
                        onPressed: onPressed,
                        child: LoadingContent(loading: loading, child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(Strings.en('storyTheEnd'), key: const Key('story-end'), style: kidBody.copyWith(fontWeight: FontWeight.w900)),
                        ])),
                      ))
                    : LoadingAction(onPressed: onNext, builder: (onPressed, loading) => FilledButton(
                        key: const Key('story-next'),
                        style: FilledButton.styleFrom(backgroundColor: Palette.plum, minimumSize: const Size.fromHeight(kMinTapTarget * 1.1)),
                        onPressed: onPressed,
                        child: LoadingContent(loading: loading, child: const Icon(Icons.arrow_forward_rounded, size: 40)),
                      )),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const DandoonaView(pose: DandoonaPose.thinking, size: 200),
              Text(Strings.en('mapAlmostReady'), key: const Key('story-waiting'), textAlign: TextAlign.center, style: kidBody.copyWith(fontWeight: FontWeight.w800, color: Palette.nightInk)),
              const SizedBox(height: 16),
              LoadingAction(onPressed: onBack, builder: (onPressed, loading) => FilledButton(onPressed: onPressed, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(kMinTapTarget)), child: LoadingContent(loading: loading, child: Text(Strings.en('chestGotIt'), style: kidBody.copyWith(fontWeight: FontWeight.w900))))),
            ],
          ),
        ),
      );
}
