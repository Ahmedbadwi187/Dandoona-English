import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/palette.dart';
import 'delete_account_dialog.dart';
import '../settings/settings.dart';
import 'sync_controller.dart';

/// Settings section: the optional parent account. Without one everything stays on the device; creating or logging in to one
/// happens on its own screen (the same one as in the first-launch flow) and uploads what is already here.
class SyncSection extends ConsumerStatefulWidget {
  const SyncSection({super.key});

  @override
  ConsumerState<SyncSection> createState() => _SyncSectionState();
}

class _SyncSectionState extends ConsumerState<SyncSection> {
  late final String _email = ref.read(syncStoreProvider).load().email;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(syncControllerProvider.notifier).refreshStatus());
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final ui = ref.watch(syncControllerProvider);
    final controller = ref.read(syncControllerProvider.notifier);
    final last = ref.read(syncStoreProvider).load().lastSyncUtc;

    return Card(
      key: const Key('sync-section'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s('syncTitle'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 4),
            Text(s('syncOptional'), style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            if (!ui.signedIn) ...[
              FilledButton.icon(
                key: const Key('sync-open-auth'),
                onPressed: () => context.push('/auth?from=settings'),
                icon: const Icon(Icons.cloud_sync_rounded),
                label: Text(s('obAccount')),
              ),
            ] else ...[
              Text('${s('signedInAs')} $_email', key: const Key('sync-signed-in')),
              if (last != null) Text('${s('lastSync')}: ${last.toLocal().toString().substring(0, 16)}', style: const TextStyle(fontSize: 12)),
              if (ref.read(syncServiceProvider).pendingDeleteCount > 0)
                Text('${s('pendingDeletes')} ${ref.read(syncServiceProvider).pendingDeleteCount}', key: const Key('pending-deletes'), style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('sync-now'),
                      onPressed: ui.busy ? null : controller.syncNow,
                      icon: const Icon(Icons.sync_rounded),
                      label: Text(s('syncNow')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(key: const Key('sync-signout'), onPressed: ui.busy ? null : controller.signOut, child: Text(s('signOut'))),
                ],
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                key: const Key('sync-delete'),
                style: TextButton.styleFrom(foregroundColor: Palette.red),
                onPressed: ui.busy ? null : () => confirmDeleteAccount(context, s, controller),
                icon: const Icon(Icons.delete_forever_rounded),
                label: Text(s('deleteAccount')),
              ),
            ],
            if (ui.busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
            if (ui.messageKey != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  s(ui.messageKey!),
                  key: const Key('sync-message'),
                  style: TextStyle(color: ui.messageIsError ? Palette.red : Palette.darkGreen, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
