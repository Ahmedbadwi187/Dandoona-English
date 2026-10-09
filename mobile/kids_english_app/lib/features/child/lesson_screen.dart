import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/palette.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/type.dart';
import '../../core/widgets.dart';
import '../activities/color_the_object_activity.dart' show colorFromHex;
import '../audio/audio_service.dart';
import '../content/content_models.dart';
import '../content/content_repository.dart';
import '../profiles/child_profile.dart';
import '../progress/progress.dart';
import '../session/session.dart';
import 'child_scope.dart';

/// One lesson: the big letter, its pictures, and the four activity tiles (the activities themselves arrive in Phase 3).
class LessonScreen extends ConsumerStatefulWidget {
  const LessonScreen({super.key, required this.lessonId});

  final String lessonId;

  @override
  ConsumerState<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends ConsumerState<LessonScreen> {
  bool _introPlayed = false;
  bool _introPlaying = false;
  late final AudioService _audio = ref.read(audioServiceProvider);

  @override
  void initState() {
    super.initState();
    // The letter introduces itself as soon as the lesson opens (when the lesson data is there).
    ref.listenManual(activeContentProvider, (_, next) => _playIntro(next.value), fireImmediately: true);
  }

  void _playIntro(TrackContent? track) {
    final lesson = track?.lessonById(widget.lessonId);
    if (_introPlayed || lesson == null) return;
    _introPlayed = true;
    _introPlaying = true;
    unawaited(_audio.playAsset(lesson.audio.intro).whenComplete(() => _introPlaying = false));
  }

  @override
  void dispose() {
    // Only the lesson's own intro is cut when leaving; a praise line from the activity that just ended plays on.
    if (_introPlaying) unawaited(_audio.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lessonId = widget.lessonId;
    final content = ref.watch(activeContentProvider);
    return ChildScope(
      child: SessionGuard(
        child: Scaffold(
          body: SafeArea(
            child: content.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(Strings.en('loadError'))),
              data: (track) {
                final lesson = track.lessonById(lessonId);
                if (lesson == null) return Center(child: Text(Strings.en('loadError')));
                return ListView(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        key: const Key('lesson-back'),
                        constraints: const BoxConstraints(minWidth: kMinTapTarget, minHeight: kMinTapTarget),
                        iconSize: 32,
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    ),
                    if (lesson.letter != null)
                      _LetterPair(lesson: lesson) // a letter lesson shows the capital and the small letter, and says which is which
                    else
                      Center(
                      child: TapToHear(
                        badgeInset: 8,
                        key: const Key('lesson-letter-tap'),
                        semanticLabel: lesson.letter,
                        onTap: () => unawaited(ref.read(audioServiceProvider).playAsset(lesson.audio.colorName ?? lesson.audio.phoneme ?? lesson.audio.intro)),
                        child: Container(
                          width: 128,
                          height: 128,
                          decoration: BoxDecoration(
                            color: lesson.color != null ? colorFromHex(lesson.color!.hex) : Palette.nodeColors[(lesson.order - 1) % Palette.nodeColors.length],
                            shape: BoxShape.circle,
                            border: Border.all(color: Palette.ink, width: 6),
                          ),
                          alignment: Alignment.center,
                          child: lesson.color != null
                              ? const SizedBox(key: Key('lesson-letter')) // a Colors lesson shows the color itself
                              : lesson.counting
                                  ? Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 18),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(lesson.digits, key: const Key('lesson-letter'), style: kidHero.copyWith(fontWeight: FontWeight.w900, color: Palette.white)),
                                      ),
                                    ) // a Numbers lesson shows its numerals: 1 2 3
                                  : lesson.letter == null && lesson.words.isNotEmpty
                                      ? Padding(
                                          key: const Key('lesson-letter'),
                                          padding: const EdgeInsets.all(18),
                                          child: AssetPicture(lesson.words.first.image, semanticLabel: lesson.words.first.word),
                                        ) // any other unit (Shapes, Animals...) shows the lesson's first picture
                                      : Text(lesson.letter ?? '?',
                                          key: const Key('lesson-letter'),
                                          style: kidHero.copyWith(fontWeight: FontWeight.w900, color: Palette.white)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final w in lesson.words)
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TapToHear(
                                key: Key('word-${w.word}'),
                                semanticLabel: w.word,
                                onTap: () => unawaited(ref.read(audioServiceProvider).playAsset(w.audio)),
                                child: AssetPicture(w.image, size: 104, semanticLabel: w.word),
                              ),
                              const SizedBox(height: 2),
                              Text(w.word, style: kidBody.copyWith(fontWeight: FontWeight.w700)),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final a in lesson.activities)
                          _ActivityTile(lessonId: lesson.id, activity: a, stars: _bestStars(ref, lesson.id, a)),
                      ],
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

const _activityIcons = {
  'trace': Icons.gesture_rounded,
  'trace-small': Icons.draw_rounded,
  'listen-and-tap': Icons.hearing_rounded,
  'record-and-listen': Icons.mic_rounded,
  'match-picture': Icons.extension_rounded,
  'color-the-object': Icons.palette_rounded,
  'animal-sounds': Icons.music_note_rounded,
  'habitat': Icons.home_rounded,
  'dandoona-says': Icons.directions_run_rounded,
  'sort': Icons.category_rounded,
  'memory': Icons.grid_view_rounded,
  'odd-one-out': Icons.search_rounded,
  'sentence': Icons.short_text_rounded,
  'count-along': Icons.touch_app_rounded,
  'mix-colors': Icons.invert_colors_rounded,
  'build-picture': Icons.extension_outlined,
  'turns': Icons.swap_horiz_rounded,
  'story-feeling': Icons.mood_rounded,
  'sound-tap': Icons.graphic_eq_rounded,
  'word-builder': Icons.view_week_rounded,
  'spell-it': Icons.spellcheck_rounded,
  'true-or-false': Icons.rule_rounded,
  'sight-word-hunt': Icons.bubble_chart_rounded,
  'read-and-pick': Icons.chrome_reader_mode_rounded,
  'find-the-word': Icons.manage_search_rounded,
  'sentence-builder': Icons.wrap_text_rounded,
  'fill-the-gap': Icons.space_bar_rounded,
};

/// Icon-only (no reading needed). Tapping opens the activity; the stars show the child's best result.
class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.lessonId, required this.activity, required this.stars});
  final String lessonId;
  final String activity;
  final int stars; // best stars so far, 0-3

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key('activity-$activity'),
      onTap: () => context.push('/lesson/$lessonId/$activity'),
      child: Container(
        width: 84,
        height: 88,
        decoration: BoxDecoration(
          color: Palette.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Palette.ink, width: 3),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_activityIcons[activity] ?? Icons.help_outline_rounded, size: 36, color: Palette.ink),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++) Icon(Icons.star_rounded, size: 15, color: i < stars ? Palette.yellow : Palette.tan),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Best stars the active child earned in one activity of a lesson.
int _bestStars(WidgetRef ref, String lessonId, String activity) {
  final childId = ref.watch(activeChildIdProvider);
  final records = ref.watch(progressProvider);
  var best = 0;
  for (final r in records) {
    if (r.childId == childId && r.lessonId == lessonId && r.activity == activity && r.stars > best) best = r.stars;
  }
  return best;
}

/// The capital and the small letter side by side. Tapping one says "Capital letter A." or "Small letter A." and then the letter's sound.
class _LetterPair extends ConsumerWidget {
  const _LetterPair({required this.lesson});

  final Lesson lesson;

  void _say(WidgetRef ref, String key) {
    final audio = ref.read(audioServiceProvider);
    final line = lesson.audio.instructions[key];
    final sound = lesson.audio.phoneme ?? lesson.audio.intro;
    unawaited(() async {
      if (line != null) await audio.playAsset(line);
      await audio.playAsset(sound);
    }());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final letter = lesson.letter!;
    final color = Palette.nodeColors[(lesson.order - 1) % Palette.nodeColors.length];
    Widget bubble({required Key tapKey, required Key textKey, required String text, required double size, required String caption, required String key}) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TapToHear(
              badgeInset: -10,
              badgeBottom: 8,
              key: tapKey,
              semanticLabel: caption,
              onTap: () => _say(ref, key),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Palette.ink, width: 6)),
                alignment: Alignment.center,
                child: Text(text, key: textKey, style: kidHero.copyWith(fontWeight: FontWeight.w900, color: Palette.white)),
              ),
            ),
            const SizedBox(height: 4),
            Text(caption, style: kidCaption.copyWith(fontWeight: FontWeight.w800, color: Palette.ink)),
          ],
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        bubble(tapKey: const Key('lesson-letter-tap'), textKey: const Key('lesson-letter'), text: letter, size: 112, caption: Strings.en('letterCapital'), key: 'capital'),
        const SizedBox(width: 22),
        bubble(tapKey: const Key('lesson-letter-small-tap'), textKey: const Key('lesson-letter-small'), text: letter.toLowerCase(), size: 112, caption: Strings.en('letterSmall'), key: 'small'),
      ],
    );
  }
}
