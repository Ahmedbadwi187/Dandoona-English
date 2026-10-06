import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/palette.dart';
import '../../core/widgets.dart';
import '../profiles/child_profile.dart';
import '../settings/settings.dart';
import '../sync/sync_controller.dart';

/// Manage child profiles: add, edit, delete (with confirmation).
class ChildrenScreen extends ConsumerWidget {
  const ChildrenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final profiles = ref.watch(profilesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s('childProfiles'))),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-child'),
        onPressed: () => context.push('/parent/children/new'),
        icon: const Icon(Icons.add_rounded),
        label: Text(s('addChild')),
      ),
      body: profiles.isEmpty
          ? Center(child: Text(s('noChildren')))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                for (final p in profiles)
                  Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: AvatarCircle(p.avatarKey, size: 56),
                      title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                      subtitle: Text('${p.birthYear}'),
                      onTap: () => context.push('/parent/children/${p.id}'),
                      trailing: IconButton(
                        key: Key('delete-${p.id}'),
                        iconSize: 28,
                        color: Palette.red,
                        tooltip: s('delete'),
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => _confirmDelete(context, ref, p),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, ChildProfile p) async {
    final s = ref.read(stringsProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: s.direction,
        child: AlertDialog(
          title: Text(s('deleteChildTitle')),
          content: Text('${p.name}\n${s('deleteChildBody')}'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s('cancel'))),
            TextButton(
              key: const Key('confirm-delete'),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(s('delete'), style: const TextStyle(color: Palette.red)),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      await ref.read(profilesProvider.notifier).remove(p.id);
      // Also hard-delete the child on the server (profile + all progress); queued if offline.
      await ref.read(syncControllerProvider.notifier).childDeleted(p.id);
    }
  }
}
