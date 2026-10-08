import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/palette.dart';
import '../../core/storage.dart';
import 'progress.dart';

/// Active days: every day the child finished something counts, for good. There is no streak to break: a missed day is
/// never shown, nothing resets, and the number only ever grows. Some totals are celebrated once.

/// The days (in the phone's own calendar) on which [childId] finished at least one activity.
int activeDays(Iterable<ProgressRecord> records, String childId) =>
    {for (final r in records) if (r.childId == childId) _day(r.completedAt.toLocal())}.length;

String _day(DateTime d) => '${d.year}-${d.month}-${d.day}';

/// The totals that get a small celebration (once each).
const activeDayMilestones = [2, 3, 5, 7, 10, 15, 20, 30, 50, 75, 100];

/// The highest milestone reached by [days], or null before the first one.
int? milestoneFor(int days) => activeDayMilestones.where((m) => m <= days).lastOrNull;

/// The last milestone celebrated per child (on the phone only, `activeDays.v1`).
class CelebratedDaysNotifier extends Notifier<Map<String, int>> {
  static const key = 'activeDays.v1';

  @override
  Map<String, int> build() {
    final raw = ref.read(sharedPreferencesProvider).readJson(key);
    if (raw is! Map<String, dynamic>) return const {};
    return raw.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  Future<void> celebrated(String childId, int milestone) async {
    state = {...state, childId: milestone};
    await ref.read(sharedPreferencesProvider).writeJson(key, state);
  }
}

final celebratedDaysProvider = NotifierProvider<CelebratedDaysNotifier, Map<String, int>>(CelebratedDaysNotifier.new);

/// The sun badge with the number of active days. When a new milestone is reached it says so once ("5 days! Hooray!"),
/// with a little bounce; otherwise it just shows the count.
class ActiveDaysBadge extends ConsumerStatefulWidget {
  const ActiveDaysBadge({super.key, required this.childId});

  final String childId;

  @override
  ConsumerState<ActiveDaysBadge> createState() => _ActiveDaysBadgeState();
}

class _ActiveDaysBadgeState extends ConsumerState<ActiveDaysBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _bounce = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  int? _celebrating;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    if (!mounted) return;
    final days = activeDays(ref.read(progressProvider), widget.childId);
    final m = milestoneFor(days);
    final last = ref.read(celebratedDaysProvider)[widget.childId] ?? 0;
    if (m == null || m <= last) return;
    setState(() => _celebrating = m);
    await ref.read(celebratedDaysProvider.notifier).celebrated(widget.childId, m);
    await _bounce.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final days = activeDays(ref.watch(progressProvider), widget.childId);
    if (days == 0) return const SizedBox.shrink();
    return ScaleTransition(
      scale: TweenSequence<double>([
        TweenSequenceItem(tween: Tween<double>(begin: 1, end: 1.25).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
        TweenSequenceItem(tween: Tween<double>(begin: 1.25, end: 1).chain(CurveTween(curve: Curves.elasticOut)), weight: 60),
      ]).animate(_bounce),
      alignment: Alignment.centerLeft,
      child: Container(
        key: const Key('active-days'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Palette.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Palette.sunflower, width: 3),
          boxShadow: [BoxShadow(color: Palette.nightInk.withValues(alpha: 0.12), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wb_sunny_rounded, color: Palette.orange, size: 28),
            const SizedBox(width: 6),
            Text(
              _celebrating != null ? '$days days! Hooray!' : '$days ${days == 1 ? 'day' : 'days'}',
              key: const Key('active-days-text'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Palette.nightInk),
            ),
          ],
        ),
      ),
    );
  }
}
