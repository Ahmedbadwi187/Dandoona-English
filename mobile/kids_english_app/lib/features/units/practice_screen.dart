import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/palette.dart';
import '../../core/sky.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../activities/listen_and_tap_activity.dart';
import '../child/child_scope.dart';
import '../content/content_models.dart';
import '../content/content_repository.dart';
import '../onboarding/onboarding_widgets.dart';
import '../session/session.dart';
import '../profiles/child_profile.dart';
import 'word_misses.dart';

/// A word a child missed, found again in the course: the word and the lesson it comes from.
typedef PracticeItem = ({MissedWord miss, LessonWord word, Lesson lesson});

/// The words waiting in Practice, most missed first: only words whose lesson is on this phone (a unit whose pack is not installed
/// yet cannot be practised), at most [max].
List<PracticeItem> practiceItems(TrackContent track, Iterable<MissedWord> missed, {int max = 5}) {
  final items = <PracticeItem>[];
  for (final m in missed) {
    final lesson = track.lessonById(m.lessonId);
    final word = lesson?.words.where((w) => w.word == m.word).firstOrNull;
    if (lesson != null && word != null) items.add((miss: m, word: word, lesson: lesson));
    if (items.length == max) break;
  }
  return items;
}

/// "Practice": the words the child missed come back in a short game (hear the word, tap the picture). A word found without a
/// wrong tap is taken off the list; the others stay for next time. No stars, nothing is lost.
class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({super.key});

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final track = ref.watch(contentProvider).asData?.value;
    final childId = ref.watch(activeChildIdProvider);
    Widget body = const Center(child: CircularProgressIndicator());
    if (track != null && childId != null) {
      // read once: the list shrinks while the child plays, but the game keeps the words it started with
      final items = practiceItems(track, ref.read(wordMissesProvider.notifier).of(childId));
      if (_done || items.isEmpty) {
        body = _Finished(onDone: () => context.go('/map'));
      } else {
        final source = items.first.lesson;
        final lesson = Lesson(
          id: 'practice',
          order: 0,
          level: source.level,
          audio: LessonAudio(intro: source.audio.intro, praise: source.audio.praise, instructions: {'listen-and-tap': source.audio.instructions['listen-and-tap'] ?? ''}..removeWhere((k, v) => v.isEmpty)),
          words: [for (final i in items) i.word],
          activities: const ['listen-and-tap'],
        );
        final lessonOf = {for (final i in items) i.word.word: i.lesson.id};
        body = ListenAndTapActivity(
          key: const Key('practice-game'),
          lesson: lesson,
          track: track,
          onRight: (w) => unawaited(ref.read(wordMissesProvider.notifier).got(childId, lessonOf[w.word] ?? '', w.word)),
          onFinished: (_) => setState(() => _done = true),
        );
      }
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
                      child: IconButton(
                        key: const Key('practice-back'),
                        constraints: const BoxConstraints(minWidth: kMinTapTarget, minHeight: kMinTapTarget),
                        iconSize: 32,
                        onPressed: () => context.canPop() ? context.pop() : context.go('/map'),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
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

class _Finished extends StatelessWidget {
  const _Finished({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const DandoonaView(pose: DandoonaPose.clapping, size: 220),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('practice-done'),
                style: FilledButton.styleFrom(backgroundColor: Palette.green, minimumSize: const Size(kMinTapTarget * 2, kMinTapTarget * 1.2)),
                onPressed: onDone,
                child: Text(Strings.en('chestGotIt'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
      );
}
