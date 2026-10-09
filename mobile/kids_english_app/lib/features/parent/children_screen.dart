import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/palette.dart';
import '../../core/widgets.dart';
import '../content/content_models.dart';
import '../onboarding/onboarding_widgets.dart';
import '../onboarding/setup_flow.dart';
import '../profiles/child_profile.dart';
import '../settings/settings.dart';
import 'parent_data.dart';
import 'parent_ui.dart';

/// Manage children: one row per child (tap to edit or delete) and an "Add child" button that starts the child setup.
class ChildrenScreen extends ConsumerWidget {
  const ChildrenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final profiles = ref.watch(profilesProvider);
    final lang = ref.watch(settingsProvider).languageCode;
    final now = ref.read(clockProvider)();

    final addButton = OutlinedButton.icon(
      key: const Key('add-child'),
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56), side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5), foregroundColor: Theme.of(context).colorScheme.primary),
      onPressed: () => startChildSetup(context, ref, returnTo: '/parent/children'),
      icon: const Icon(Icons.add_rounded),
      label: Text(s('addChild')),
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
              child: Row(
                children: [
                  ParentBack(onPressed: () => context.canPop() ? context.pop() : context.go('/parent')),
                  const SizedBox(width: 4),
                  Expanded(child: Text(s('pManageChildren'), key: const Key('manage-title'), style: ParentText.screenTitle)),
                ],
              ),
            ),
            Expanded(
              child: profiles.isEmpty
                  ? ListView(
                      key: const Key('manage-empty'),
                      padding: const EdgeInsets.all(24),
                      children: [
                        const SizedBox(height: 24),
                        const Center(child: DandoonaView(pose: DandoonaPose.waving, size: 170)),
                        const SizedBox(height: 12),
                        Text(s('pAddFirstChild'), textAlign: TextAlign.center, style: ParentText.section),
                        const SizedBox(height: 20),
                        addButton,
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: [
                        for (final p in profiles)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ParentCard(
                              key: Key('child-row-${p.id}'),
                              onTap: () => context.push('/parent/children/${p.id}'),
                              child: Row(
                                children: [
                                  AvatarCircle(p.avatarKey, size: 56),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(p.name, style: ParentText.section),
                                        const SizedBox(height: 2),
                                        _Subtitle(child: p, now: now, lang: lang),
                                      ],
                                    ),
                                  ),
                                  const ParentChevron(),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 4),
                        addButton,
                        const SizedBox(height: 12),
                        Text(s('pManageHint'), key: const Key('manage-hint'), textAlign: TextAlign.center, style: ParentText.caption),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "4 years · Colors": the age and the unit the child is on.
class _Subtitle extends ConsumerWidget {
  const _Subtitle({required this.child, required this.now, required this.lang});

  final ChildProfile child;
  final DateTime now;
  final String lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final CourseUnit? unit = ref.watch(childOverviewProvider(child.id))?.current?.unit;
    final age = s.age(child.ageYears(now));
    return Text(unit == null ? age : '$age · ${unit.titleFor(lang)}', style: ParentText.caption.copyWith(color: Palette.ink.withValues(alpha: 0.75)));
  }
}
