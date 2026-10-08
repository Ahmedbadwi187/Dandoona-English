import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings.dart';
import '../sync/sync_controller.dart' show defaultApiBaseUrl;
import '../sync/sync_section.dart';

/// Parent settings: language, session timer (default 15 min), unlock all letters.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(s('settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(s('language'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            key: const Key('language-selector'),
            segments: [
              ButtonSegment(value: 'ar', label: Text(s('arabic'))),
              ButtonSegment(value: 'en', label: Text(s('english'))),
            ],
            selected: {settings.languageCode},
            onSelectionChanged: (v) => notifier.setLanguage(v.first),
          ),
          const SizedBox(height: 28),
          Text('${s('sessionLimit')}: ${settings.sessionMinutes}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          Slider(
            key: const Key('session-slider'),
            min: AppSettings.minSessionMinutes.toDouble(),
            max: AppSettings.maxSessionMinutes.toDouble(),
            divisions: (AppSettings.maxSessionMinutes - AppSettings.minSessionMinutes) ~/ 5,
            value: settings.sessionMinutes.toDouble(),
            label: '${settings.sessionMinutes}',
            onChanged: (v) => notifier.setSessionMinutes(v.round()),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            key: const Key('unlock-all'),
            contentPadding: EdgeInsets.zero,
            title: Text(s('unlockAll'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            subtitle: Text(s('unlockAllHint')),
            value: settings.unlockAll,
            onChanged: notifier.setUnlockAll,
          ),
          if (defaultApiBaseUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Text(s('cardsTitle'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 4),
            Text(s('cardsHint')),
            const SizedBox(height: 8),
            SelectableText(cardsUrl(defaultApiBaseUrl), key: const Key('cards-link'), textDirection: TextDirection.ltr),
            const SizedBox(height: 4),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                key: const Key('cards-copy'),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(ClipboardData(text: cardsUrl(defaultApiBaseUrl)));
                  messenger.showSnackBar(SnackBar(content: Text(s('cardsCopied'))));
                },
                icon: const Icon(Icons.copy_rounded),
                label: Text(s('cardsCopy')),
              ),
            ),
          ],
          const SizedBox(height: 20),
          const SyncSection(),
        ],
      ),
    );
  }
}

/// The address of the printable parent cards on the server (the same page for everyone).
String cardsUrl(String baseUrl) => '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/cards';
