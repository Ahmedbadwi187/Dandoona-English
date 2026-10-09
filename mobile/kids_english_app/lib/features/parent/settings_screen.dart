import 'package:flutter/material.dart';
import 'parent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings.dart';
import '../sync/sync_controller.dart' show defaultApiBaseUrl;
import '../sync/sync_section.dart';
import '../../core/type.dart';
import '../../core/loading_action.dart';

/// Parent settings: language, session timer (default 15 min), unlock all letters.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _settingLanguage = false;

  Future<void> _setLanguage(String code) async {
    if (_settingLanguage) return;
    setState(() => _settingLanguage = true);
    try {
      await ref.read(settingsProvider.notifier).setLanguage(code);
    } finally {
      if (mounted) setState(() => _settingLanguage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(s('settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(s('language'), style: parentSubtitle.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            key: const Key('language-selector'),
            segments: [
              ButtonSegment(value: 'ar', label: Text(s('arabic'))),
              ButtonSegment(value: 'en', label: Text(s('english'))),
            ],
            selected: {settings.languageCode},
            selectedIcon: LoadingContent(loading: _settingLanguage, child: const Icon(Icons.check)),
            onSelectionChanged: _settingLanguage ? null : (v) => _setLanguage(v.first),
          ),
          const SizedBox(height: 28),
          Text('${s('sessionLimit')}: ${settings.sessionMinutes}',
              style: parentSubtitle.copyWith(fontWeight: FontWeight.w800)),
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
            title: Text(s('unlockAll'), style: parentSubtitle.copyWith(fontWeight: FontWeight.w800)),
            subtitle: Text(s('unlockAllHint')),
            value: settings.unlockAll,
            onChanged: notifier.setUnlockAll,
          ),
          if (defaultApiBaseUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Text(s('cardsTitle'), style: parentSubtitle.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(s('cardsHint')),
            const SizedBox(height: 8),
            SelectableText(cardsUrl(defaultApiBaseUrl), key: const Key('cards-link'), textDirection: TextDirection.ltr),
            const SizedBox(height: 4),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: LoadingAction(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(ClipboardData(text: cardsUrl(defaultApiBaseUrl)));
                  if (context.mounted) messenger.showSnackBar(SnackBar(content: Text(s('cardsCopied'))));
                },
                builder: (onPressed, loading) => OutlinedButton.icon(
                  key: const Key('cards-copy'),
                  style: parentOutlinedStyle(context),
                  onPressed: onPressed,
                  icon: LoadingContent(loading: loading, size: 18, child: const Icon(Icons.copy_rounded, size: 18)),
                  label: Text(s('cardsCopy')),
                ),
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
