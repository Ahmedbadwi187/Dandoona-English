import 'package:flutter/material.dart';
import '../parent/parent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/palette.dart';
import '../../core/loading_action.dart';
import 'delete_account_dialog.dart';
import '../settings/settings.dart';
import 'sync_controller.dart';
import '../../core/type.dart';

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
            Text(s('syncTitle'), style: parentSubtitle.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(s('syncOptional'), style: parentCaption),
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
              if (last != null) Text('${s('lastSync')}: ${last.toLocal().toString().substring(0, 16)}', style: parentCaption),
              if (ref.read(syncServiceProvider).pendingDeleteCount > 0)
                Text('${s('pendingDeletes')} ${ref.read(syncServiceProvider).pendingDeleteCount}', key: const Key('pending-deletes'), style: parentCaption),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: LoadingAction(
                      onPressed: ui.busy ? null : controller.syncNow,
                      builder: (onPressed, loading) => FilledButton.icon(
                        key: const Key('sync-now'),
                        style: parentFilledStyle(),
                        onPressed: onPressed,
                        icon: LoadingContent(loading: loading, size: 18, child: const Icon(Icons.sync_rounded, size: 18)),
                        label: Text(s('syncNow')),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  LoadingAction(
                    onPressed: ui.busy ? null : controller.signOut,
                    builder: (onPressed, loading) => OutlinedButton(
                      key: const Key('sync-signout'),
                      style: parentOutlinedStyle(context),
                      onPressed: onPressed,
                      child: LoadingContent(loading: loading, child: Text(s('signOut'))),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LoadingAction(
                onPressed: ui.busy ? null : () => confirmDeleteAccount(context, s, controller),
                builder: (onPressed, loading) => TextButton.icon(
                  key: const Key('sync-delete'),
                  style: TextButton.styleFrom(foregroundColor: Palette.red),
                  onPressed: onPressed,
                  icon: LoadingContent(loading: loading, child: const Icon(Icons.delete_forever_rounded)),
                  label: Text(s('deleteAccount')),
                ),
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
