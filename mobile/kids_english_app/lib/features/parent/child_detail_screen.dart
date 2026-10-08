import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/palette.dart';
import '../../core/strings.dart';
import '../../core/widgets.dart';
import '../audio/audio_service.dart';
import '../content/content_models.dart';
import '../content/packs.dart';
import '../content/content_repository.dart';
import '../profiles/child_profile.dart';
import '../progress/progress.dart';
import '../progress/weekly_summary.dart';
import '../settings/settings.dart';
import '../units/unit_logic.dart';
import '../units/unit_meta.dart';
import '../units/unit_style.dart';
import '../units/word_misses.dart';
import 'parent_data.dart';
import 'parent_ui.dart';
import 'weekly_view.dart';

/// One child in detail: the current unit (with its words to hear), what to practise at home, every unit with its stars,
/// the certificates, and the history of the weeks.
class ChildDetailScreen extends ConsumerStatefulWidget {
  const ChildDetailScreen({super.key, required this.childId});

  final String childId;

  @override
  ConsumerState<ChildDetailScreen> createState() => _ChildDetailScreenState();
}

class _ChildDetailScreenState extends ConsumerState<ChildDetailScreen> {
  bool _hearing = false;
  int _token = 0; // a new run (or a stop) invalidates the old run
  int _range = 0; // 0 this week, 1 last week, 2 this month
  late final AudioService _audio = ref.read(audioServiceProvider);

  @override
  void dispose() {
    _token++;
    unawaited(_audio.stop());
    super.dispose();
  }

  /// Plays the unit's words one after another, in Dandoona's voice; Stop ends it.
  Future<void> _hear(CourseUnit unit) async {
    final mine = ++_token;
    setState(() => _hearing = true);
    for (final lesson in unit.lessons) {
      for (final w in lesson.words) {
        if (mine != _token) return;
        await _audio.playAsset(w.audio);
      }
    }
    if (mounted && mine == _token) setState(() => _hearing = false);
  }

  Future<void> _stop() async {
    _token++;
    await _audio.stop();
    if (mounted) setState(() => _hearing = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final settings = ref.watch(settingsProvider);
    final lang = settings.languageCode;
    final child = ref.watch(profilesProvider).where((p) => p.id == widget.childId).firstOrNull;
    if (child == null) return const Scaffold(); // deleted while open
    final now = ref.read(clockProvider)();
    final track = ref.watch(trackContentProvider(child.track)).asData?.value;
    final overview = ref.watch(childOverviewProvider(child.id));
    final records = ref.watch(progressProvider);
    final progress = ref.read(progressProvider.notifier);
    final meta = ref.watch(unitMetaProvider).of(child.id);
    final primary = Theme.of(context).colorScheme.primary;
    final current = overview?.current;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
              child: Row(
                children: [
                  ParentBack(onPressed: () => context.canPop() ? context.pop() : context.go('/parent')),
                  AvatarCircle(child.avatarKey, size: 48),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(child.name, key: const Key('detail-name'), style: ParentText.screenTitle.copyWith(fontSize: 22)),
                        Text(s.age(child.ageYears(now)), style: ParentText.caption.copyWith(fontSize: 14)),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('detail-edit'),
                    tooltip: s('pEditChild'),
                    constraints: const BoxConstraints(minWidth: kParentTap, minHeight: kParentTap),
                    onPressed: () => context.push('/parent/children/${child.id}'),
                    icon: const Icon(Icons.edit_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  if (current != null) ...[
                    ParentCard(
                      key: const Key('detail-current'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(unitIcon(current.unit.icon), color: unitColor(current.unit.color), size: 30),
                              const SizedBox(width: 10),
                              Expanded(child: Text(current.unit.titleFor(lang), style: ParentText.section)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(s.format('dLessonsOf', {'done': current.done, 'total': current.total}), style: ParentText.body),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(minHeight: 10, value: current.total == 0 ? 0 : current.done / current.total, backgroundColor: parentBorder.withValues(alpha: 0.6)),
                          ),
                          const SizedBox(height: 12),
                          _hearing
                              ? OutlinedButton.icon(
                                  key: const Key('hear-stop'),
                                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(kParentTap), foregroundColor: Palette.red, side: const BorderSide(color: Palette.red, width: 1.5)),
                                  onPressed: _stop,
                                  icon: const Icon(Icons.stop_rounded),
                                  label: Text(s('dStop')),
                                )
                              : FilledButton.tonalIcon(
                                  key: const Key('hear-words'),
                                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(kParentTap)),
                                  onPressed: () => _hear(current.unit),
                                  icon: const Icon(Icons.volume_up_rounded),
                                  label: Text(s('dHearWords')),
                                ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(s('dPractice'), style: ParentText.section),
                  const SizedBox(height: 8),
                  _Practice(words: track == null ? const [] : wordsToPractice(track, records, child.id, progress, missed: ref.watch(wordMissesProvider.select((m) => m[child.id] == null)) ? const [] : ref.read(wordMissesProvider.notifier).of(child.id)), s: s, audio: _audio),
                  const SizedBox(height: 16),
                  Text(s('dAllUnits'), style: ParentText.section),
                  const SizedBox(height: 8),
                  if (overview != null)
                    for (final st in overview.statuses)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _UnitRow(status: st, child: child, s: s, lang: lang, stars: _unitStars(st.unit, child.id, progress)),
                      ),
                  const SizedBox(height: 8),
                  Text(s('dCertificates'), style: ParentText.section),
                  const SizedBox(height: 8),
                  if (meta.certificates.isEmpty)
                    Text(s('dNoCerts'), key: const Key('no-certificates'), style: ParentText.body.copyWith(color: ParentText.caption.color))
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final e in meta.certificates.entries)
                          if (track?.unitById(e.key) != null)
                            _CertThumb(
                              key: Key('cert-${e.key}'),
                              title: track!.unitById(e.key)!.titleFor(lang),
                              date: e.value,
                              onTap: () {
                                ref.read(activeChildIdProvider.notifier).select(child.id);
                                context.push('/certificate/${e.key}');
                              },
                            ),
                      ],
                    ),
                  const SizedBox(height: 20),
                  Text(s('dHistory'), style: ParentText.section),
                  const SizedBox(height: 8),
                  _History(
                    child: child,
                    records: records,
                    range: _range,
                    now: now,
                    firstWeekday: firstWeekdayFor(lang),
                    goal: child.goalMinutes ?? settings.sessionMinutes,
                    s: s,
                    onRange: (v) => setState(() => _range = v),
                    primary: primary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static int _unitStars(CourseUnit unit, String childId, ProgressNotifier progress) => unit.lessons.fold(0, (sum, l) => sum + progress.starsFor(childId, l.id));
}

/// The words of the lessons that took the child the most tries or earned the fewest stars (up to [limit]), most difficult
/// lesson first. Progress is recorded per lesson, so a lesson is represented by its first word.
List<LessonWord> wordsToPractice(TrackContent track, List<ProgressRecord> records, String childId, ProgressNotifier progress, {int limit = 6, Iterable<MissedWord> missed = const []}) {
  final words = <LessonWord>[];
  // the words the child really missed in the games come first (exactly those words), most missed first
  for (final m in missed) {
    final w = track.lessonById(m.lessonId)?.words.where((x) => x.word == m.word).firstOrNull;
    if (w != null && !words.any((x) => x.word == w.word)) words.add(w);
    if (words.length == limit) return words;
  }
  final scores = <String, int>{};
  for (final r in records.where((r) => r.childId == childId)) {
    scores[r.lessonId] = (scores[r.lessonId] ?? 0) + (r.attempts > 1 ? r.attempts - 1 : 0) + (r.stars < 3 ? 3 - r.stars : 0);
  }
  final ranked = scores.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
  for (final e in ranked) {
    final lesson = track.lessonById(e.key);
    if (lesson == null || lesson.words.isEmpty || words.any((x) => x.word == lesson.words.first.word)) continue;
    words.add(lesson.words.first);
    if (words.length == limit) break;
  }
  return words;
}

class _Practice extends StatelessWidget {
  const _Practice({required this.words, required this.s, required this.audio});

  final List<LessonWord> words;
  final Strings s;
  final AudioService audio;

  @override
  Widget build(BuildContext context) {
    if (words.isEmpty) {
      return ParentCard(
        key: const Key('nothing-to-practice'),
        child: Row(
          children: [
            const Icon(Icons.emoji_events_rounded, color: Palette.sunflower, size: 28),
            const SizedBox(width: 10),
            Expanded(child: Text(s('dNothingToPractice'), style: ParentText.body)),
          ],
        ),
      );
    }
    return Column(
      children: [
        for (final w in words)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ParentCard(
              key: Key('practice-${w.word}'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  AssetPicture(w.image, size: 44, semanticLabel: w.word),
                  const SizedBox(width: 12),
                  Expanded(child: Text(w.word, style: ParentText.section)),
                  IconButton(
                    key: Key('practice-play-${w.word}'),
                    tooltip: s('dPlay'),
                    constraints: const BoxConstraints(minWidth: kParentTap, minHeight: kParentTap),
                    onPressed: () => unawaited(audio.playAsset(w.audio)),
                    icon: Icon(Icons.volume_up_rounded, color: Theme.of(context).colorScheme.primary),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _UnitRow extends ConsumerWidget {
  const _UnitRow({required this.status, required this.child, required this.s, required this.lang, required this.stars});

  final UnitStatus status;
  final ChildProfile child;
  final Strings s;
  final String lang;
  final int stars;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = status.unit;
    final open = status.state == UnitState.done || status.state == UnitState.current;
    final label = switch (status.state) {
      UnitState.done => s('dDone'),
      UnitState.current => s('dCurrent'),
      UnitState.locked => s('dLocked'),
      UnitState.soon => s('pSoon'),
    };
    return Opacity(
      opacity: open ? 1 : 0.55,
      child: ParentCard(
        key: Key('unit-row-${unit.id}'),
        onTap: open ? () => _showLessons(context, ref) : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(unitIcon(unit.icon), color: unitColor(unit.color), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(unit.titleFor(lang), style: ParentText.body.copyWith(fontWeight: FontWeight.w700)),
                  Text(label, style: ParentText.caption),
                  // a downloadable unit the child has reached whose pack is not on this phone yet
                  if (unit.needsDownload && open)
                    switch (ref.watch(packDownloadsProvider)[unit.id]) {
                      PackDownload.downloading => Text(s('pPackDownloading'), key: Key('unit-pack-${unit.id}'), style: ParentText.caption),
                      PackDownload.offline || PackDownload.failed => Text(s('pPackNeedsInternet'),
                          key: Key('unit-pack-${unit.id}'), style: ParentText.caption.copyWith(color: Palette.blue, fontWeight: FontWeight.w700)),
                      null => const SizedBox.shrink(),
                    },
                ],
              ),
            ),
            if (open) ...[
              const Icon(Icons.star_rounded, color: Palette.sunflower, size: 22),
              const SizedBox(width: 2),
              Text(s.number(stars), style: ParentText.body.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              const ParentChevron(),
            ] else
              Icon(status.state == UnitState.soon ? Icons.hourglass_empty_rounded : Icons.lock_rounded, size: 22, color: Palette.ink),
          ],
        ),
      ),
    );
  }

  /// The unit's lessons with the stars the child got in each.
  void _showLessons(BuildContext context, WidgetRef ref) {
    final progress = ref.read(progressProvider.notifier);
    final unit = status.unit;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Directionality(
        textDirection: s.direction,
        child: SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
            child: ListView(
              key: Key('lessons-${unit.id}'),
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Text(unit.titleFor(lang), style: ParentText.screenTitle.copyWith(fontSize: 22)),
                const SizedBox(height: 8),
                for (final l in unit.lessons)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      key: Key('lesson-${l.id}'),
                      children: [
                        Expanded(child: Text(l.letter ?? (l.words.isEmpty ? l.id : l.words.first.word), style: ParentText.body)),
                        for (var i = 1; i <= 3; i++)
                          Icon(
                            Icons.star_rounded,
                            size: 24,
                            color: _lessonStars(progress, l) >= i ? Palette.sunflower : parentBorder,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 0-3: the best result across the lesson's activities, averaged and rounded.
  int _lessonStars(ProgressNotifier progress, Lesson l) {
    final total = progress.starsFor(child.id, l.id);
    final activities = l.activities.isEmpty ? 1 : l.activities.length;
    return (total / activities).round().clamp(0, 3);
  }
}

class _CertThumb extends StatelessWidget {
  const _CertThumb({super.key, required this.title, required this.date, required this.onTap});

  final String title;
  final String date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 140,
        child: ParentCard(
          onTap: onTap,
          padding: const EdgeInsets.all(12),
          color: const Color(0xFFFFF7DC),
          child: Column(
            children: [
              const Icon(Icons.workspace_premium_rounded, color: Palette.sunflower, size: 44),
              const SizedBox(height: 4),
              Text(title, textAlign: TextAlign.center, style: ParentText.body.copyWith(fontWeight: FontWeight.w700)),
              Text(date, style: ParentText.caption),
            ],
          ),
        ),
      );
}

class _History extends StatelessWidget {
  const _History({required this.child, required this.records, required this.range, required this.now, required this.firstWeekday, required this.goal, required this.s, required this.onRange, required this.primary});

  final ChildProfile child;
  final List<ProgressRecord> records;
  final int range;
  final DateTime now;
  final int firstWeekday;
  final int goal;
  final Strings s;
  final ValueChanged<int> onRange;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final thisWeek = weekStartOf(now, firstWeekday);
    final summary = switch (range) {
      0 => summarizeRange(records, child.id, thisWeek, 7),
      1 => summarizeRange(records, child.id, thisWeek.subtract(const Duration(days: 7)), 7),
      _ => summarizeRange(records, child.id, DateTime(now.year, now.month, 1), DateTime(now.year, now.month + 1, 0).day),
    };
    return ParentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              key: const Key('history-range'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 0, label: Text(s('thisWeek'), key: const Key('history-0'))),
                ButtonSegment(value: 1, label: Text(s('dLastWeek'), key: const Key('history-1'))),
                ButtonSegment(value: 2, label: Text(s('dThisMonth'), key: const Key('history-2'))),
              ],
              selected: {range},
              onSelectionChanged: (v) => onRange(v.first),
            ),
          ),
          const SizedBox(height: 14),
          WeekChart(summary: summary, s: s, goalMinutes: goal, today: now),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Text(s.format('dTotalMinutes', {'n': summary.minutes}), key: const Key('history-minutes'), style: ParentText.body.copyWith(fontWeight: FontWeight.w700))),
              Text(s.format('dActiveDays', {'n': summary.activeDays}), key: const Key('history-days'), style: ParentText.body),
            ],
          ),
        ],
      ),
    );
  }
}
