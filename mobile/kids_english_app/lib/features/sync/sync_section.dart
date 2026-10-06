import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/palette.dart';
import 'delete_account_dialog.dart';
import '../settings/settings.dart';
import 'sync_controller.dart';

/// Settings section: optional parent account + sync. The app works fully offline without it.
class SyncSection extends ConsumerStatefulWidget {
  const SyncSection({super.key});

  @override
  ConsumerState<SyncSection> createState() => _SyncSectionState();
}

class _SyncSectionState extends ConsumerState<SyncSection> {
  late final TextEditingController _url;
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void initState() {
    super.initState();
    final saved = ref.read(syncStoreProvider).load();
    _url = TextEditingController(text: saved.baseUrl.isNotEmpty ? saved.baseUrl : defaultApiBaseUrl);
    _email.text = saved.email;
    Future.microtask(() => ref.read(syncControllerProvider.notifier).refreshStatus());
  }

  @override
  void dispose() {
    _url.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
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
              TextField(
                key: const Key('sync-url'),
                controller: _url,
                keyboardType: TextInputType.url,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(labelText: s('serverUrl'), hintText: 'https://'),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('sync-email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(labelText: s('email')),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('sync-password'),
                controller: _password,
                obscureText: true,
                textDirection: TextDirection.ltr,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(labelText: s('password')),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      key: const Key('sync-login'),
                      onPressed: ui.busy ? null : () => controller.signIn(_url.text, _email.text, _password.text),
                      child: Text(s('login')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('sync-register'),
                      onPressed: ui.busy ? null : () => controller.signIn(_url.text, _email.text, _password.text, register: true),
                      child: Text(s('register')),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Text('${s('signedInAs')} ${_email.text}', key: const Key('sync-signed-in')),
              if (last != null) Text('${s('lastSync')}: ${last.toLocal().toString().substring(0, 16)}', style: const TextStyle(fontSize: 12)),
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
