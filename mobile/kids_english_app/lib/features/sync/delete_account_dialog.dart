import 'package:flutter/material.dart';

import '../../core/palette.dart';
import '../../core/strings.dart';
import 'sync_controller.dart';

/// Asks the parent to confirm with their password, then deletes the account and its server data.
/// (Google Play and the App Store require an in-app way to delete an account.)
Future<void> confirmDeleteAccount(BuildContext context, Strings s, SyncController controller) async {
  final password = await showDialog<String>(
    context: context,
    builder: (_) => _DeleteAccountDialog(s: s),
  );
  if (password != null && password.isNotEmpty) await controller.deleteAccount(password);
}

/// Owns its text controller, so it is disposed only after the dialog has fully left the screen.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.s});
  final Strings s;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Directionality(
      textDirection: s.direction,
      child: AlertDialog(
        title: Text(s('deleteAccountTitle')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(s('deleteAccountBody')),
            const SizedBox(height: 12),
            TextField(
              key: const Key('delete-password'),
              controller: _password,
              obscureText: true,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(labelText: s('password')),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(s('cancel'))),
          TextButton(
            key: const Key('delete-confirm'),
            onPressed: () => Navigator.pop(context, _password.text),
            child: Text(s('delete'), style: const TextStyle(color: Palette.red)),
          ),
        ],
      ),
    );
  }
}
