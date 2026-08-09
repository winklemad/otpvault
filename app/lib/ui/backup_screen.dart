import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/backup.dart';
import '../core/vault.dart';

/// Encrypted export — seal the vault with a passphrase the user chooses here.
/// The resulting bytes are safe to store anywhere.
class BackupScreen extends StatefulWidget {
  final Vault vault;
  const BackupScreen({super.key, required this.vault});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _pass = TextEditingController();
  bool _busy = false;
  String? _status;

  Future<void> _export() async {
    if (_pass.text.length < 8) {
      setState(() => _status = 'Choose a passphrase of at least 8 characters.');
      return;
    }
    setState(() { _busy = true; _status = null; });
    try {
      final Uint8List bytes = await Backup.exportEncrypted(widget.vault, _pass.text);
      // TODO: persist bytes to a file the user picks (share_plus / file_selector).
      setState(() => _status = 'Encrypted backup ready (${bytes.length} bytes). '
          'Wire share_plus/file_selector to save it.');
    } catch (e) {
      setState(() => _status = 'Export failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Encrypted export')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(children: [
          const Text('Export an encrypted copy of your vault. You choose the passphrase; '
              'you need it (not your account password) to restore this file.'),
          const SizedBox(height: 16),
          TextField(controller: _pass, obscureText: true,
              decoration: const InputDecoration(labelText: 'Export passphrase')),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : _export,
            icon: const Icon(Icons.lock),
            label: Text(_busy ? 'Encrypting…' : 'Create encrypted backup'),
          ),
          if (_status != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(_status!)),
          const Divider(height: 40),
          const Text('Migrate to another app', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('⚠️ A plaintext otpauth:// export is also available for moving to another '
              'authenticator. It is UNENCRYPTED — use once and delete.',
              style: TextStyle(fontSize: 12, color: Colors.orange)),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              final uris = Backup.exportOtpauthUris(widget.vault); // TODO: gate behind a warning + share sheet
              showDialog(context: context, builder: (_) => AlertDialog(
                title: const Text('otpauth:// export (plaintext)'),
                content: Text('${uris.length} entries. Handle with care.'),
                actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
              ));
            },
            child: const Text('Plaintext otpauth export'),
          ),
        ]),
      ),
    );
  }
}
