import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/palette.dart';
import '../../core/widgets.dart';
import '../onboarding/onboarding_widgets.dart';
import '../profiles/child_profile.dart';
import '../progress/progress.dart';
import '../progress/weekly_summary.dart';
import '../router_state.dart';
import '../settings/settings.dart';
import '../units/unit_style.dart';
import 'parent_data.dart';
import 'parent_prompts.dart';
import 'parent_ui.dart';
import 'weekly_view.dart';
import '../../core/type.dart';

/// Parent dashboard (the parent's language, RTL in Arabic). Reached only through the parental gate. One compact card per
/// child (tap for the details), "Child mode" and "Manage children" fixed at the bottom.
class ParentHomeScreen extends ConsumerWidget {
  const ParentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final profiles = ref.watch(profilesProvider);
    final settings = ref.watch(settingsProvider);
    final primary = Theme.of(context).colorScheme.primary;

    void childMode() {
      // With one child there is nothing to choose: go straight to that child's unit map.
      if (profiles.length == 1) {
        ref.read(parentSessionProvider.notifier).lock();
        ref.read(activeChildIdProvider.notifier).select(profiles.first.id);
        context.go('/map');
      } else {
        context.go('/who');
      }
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s('parentArea'), key: const Key('parent-title'), style: ParentText.screenTitle),
                        if (settings.parentName.isNotEmpty) Text(s.format('pGreeting', {'name': settings.parentName}), key: const Key('parent-greeting'), style: ParentText.body.copyWith(color: ParentText.caption.color)),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('parent-settings'),
                    tooltip: s('settings'),
                    constraints: const BoxConstraints(minWidth: kParentTap, minHeight: kParentTap),
                    iconSize: 28,
                    onPressed: () => context.push('/parent/settings'),
                    icon: const Icon(Icons.settings_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: profiles.isEmpty
                  ? Center(child: Text(s('noChildren'), style: ParentText.body))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      children: [
                        for (final child in profiles) ...[
                          ParentPrompts(child: child), // asked once: the birth month, the Explorers offer
                          Padding(padding: const EdgeInsets.only(bottom: 12), child: _ChildCard(child: child)),
                        ],
                      ],
                    ),
            ),
            Container(
              decoration: const BoxDecoration(color: Palette.cream, border: Border(top: BorderSide(color: parentBorder))),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('open-child-mode'),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                      onPressed: profiles.isEmpty ? null : childMode,
                      icon: const Icon(Icons.child_care_rounded),
                      label: Text(s('openChildMode')),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      key: const Key('manage-children'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(kParentTap), side: BorderSide(color: primary, width: 1.5), foregroundColor: primary, textStyle: parentBody.copyWith(fontWeight: FontWeight.w600)),
                      onPressed: () => context.push('/parent/children'),
                      child: Text(s('pManageChildren')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChildCard extends ConsumerWidget {
  const _ChildCard({required this.child});

  final ChildProfile child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final settings = ref.watch(settingsProvider);
    final lang = settings.languageCode;
    final now = ref.read(clockProvider)();
    final overview = ref.watch(childOverviewProvider(child.id));
    final current = overview?.current;
    final week = summarizeWeek(ref.watch(progressProvider), child.id, now, firstWeekday: firstWeekdayFor(lang));
    final primary = Theme.of(context).colorScheme.primary;

    return ParentCard(
      key: Key('parent-child-${child.id}'),
      onTap: () => context.push('/parent/child/${child.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarCircle(child.avatarKey, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(TextSpan(children: [
                      TextSpan(text: child.name, style: ParentText.section),
                      TextSpan(text: '  ·  ${s.age(child.ageYears(now))}', style: ParentText.caption),
                    ])),
                    if (current != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(unitIcon(current.unit.icon), size: 18, color: primary),
                            const SizedBox(width: 6),
                            Expanded(child: Text(s.format('pNowLearning', {'unit': current.unit.titleFor(lang)}), style: ParentText.body.copyWith(color: primary))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const ParentChevron(),
            ],
          ),
          if (current != null) ...[
            const SizedBox(height: 12),
            Text(s.format('pUnitLessons', {'unit': current.unit.titleFor(lang), 'done': current.done, 'total': current.total}), style: ParentText.body),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(key: Key('unit-progress-${child.id}'), minHeight: 10, value: current.total == 0 ? 0 : current.done / current.total, backgroundColor: parentBorder.withValues(alpha: 0.6)),
            ),
          ],
          if (overview != null) ...[
            const SizedBox(height: 8),
            Text(s.format('pUnitsDone', {'done': overview.unitsDone, 'total': overview.unitsTotal}), key: Key('units-done-${child.id}'), style: ParentText.caption),
            // the other track, when the child has played in it (progress is kept per track)
            for (final t in ref.watch(childTracksProvider(child.id)).where((t) => !t.active && (t.unitsDone > 0 || t.activitiesThisWeek > 0)))
              Text('${s(t.track == 'explorers' ? 'pTrackExplorers' : 'pTrackLL')}: ${s.format('pUnitsOfN', {'done': t.unitsDone, 'total': t.unitsTotal})}', key: Key('units-done-${t.track}-${child.id}'), style: ParentText.caption),
          ],
          const SizedBox(height: 12),
          if (week.isEmpty)
            Container(
              key: Key('empty-week-${child.id}'),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Palette.cream, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  const DandoonaView(pose: DandoonaPose.waving, size: 56),
                  const SizedBox(width: 10),
                  Expanded(child: Text(s('pNoActivity'), style: ParentText.body)),
                ],
              ),
            )
          else ...[
            Text(s('thisWeek'), style: ParentText.section),
            const SizedBox(height: 8),
            WeekTiles(summary: week, s: s),
            const SizedBox(height: 12),
            WeekChart(summary: week, s: s, goalMinutes: child.goalMinutes ?? settings.sessionMinutes, today: now),
          ],
        ],
      ),
    );
  }
}
