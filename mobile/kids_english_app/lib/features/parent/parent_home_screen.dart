import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/palette.dart';
import '../../core/widgets.dart';
import '../content/content_repository.dart';
import '../profiles/child_profile.dart';
import '../progress/progress.dart';
import '../settings/settings.dart';

/// Parent dashboard (Arabic, RTL by default). Reached only through the parental gate.
class ParentHomeScreen extends ConsumerWidget {
  const ParentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final profiles = ref.watch(profilesProvider);
    final progress = ref.watch(progressProvider);
    final lessonIds = ref.watch(contentProvider).maybeWhen(
          data: (c) => c.lessons.map((l) => l.id).toList(),
          orElse: () => <String>[],
        );
    final notifier = ref.read(progressProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(s('parentArea')),
        actions: [
          IconButton(
            key: const Key('parent-settings'),
            tooltip: s('settings'),
            iconSize: 32,
            onPressed: () => context.push('/parent/settings'),
            icon: const Icon(Icons.settings_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(s('dashboard'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (profiles.isEmpty) Text(s('noChildren')),
          for (final child in profiles)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    AvatarCircle(child.avatarKey, size: 64),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(child.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(
                            '${s('stars')}: ${lessonIds.fold<int>(0, (sum, id) => sum + notifier.starsFor(child.id, id))}'
                            '   ·   ${s('lettersDone')}: '
                            '${lessonIds.where((id) => progress.any((r) => r.childId == child.id && r.lessonId == id)).length}'
                            '/${lessonIds.length}',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('open-child-mode'),
            onPressed: profiles.isEmpty ? null : () => context.go('/who'),
            icon: const Icon(Icons.child_care_rounded),
            label: Text(s('openChildMode')),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('manage-children'),
            onPressed: () => context.push('/parent/children'),
            icon: const Icon(Icons.groups_rounded),
            label: Text(s('childProfiles')),
          ),
          const SizedBox(height: 24),
          const Divider(color: Palette.tan),
        ],
      ),
    );
  }
}
