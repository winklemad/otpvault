import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../core/backup.dart';
import '../core/vault.dart';
import 'widgets.dart';

/// Encrypted export — seal the vault with a passphrase the user chooses here.
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
    final t = Theme.of(context).extension<AppTokens>()!;
    return Scaffold(
      appBar: AppBar(title: const Text('Encrypted export')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Export an encrypted copy of your vault. You choose the passphrase; you need it '
              '(not your account password) to restore this file.',
              style: TextStyle(color: t.muted, fontSize: 13.5, height: 1.5)),
          const SizedBox(height: 18),
          TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: 'Export passphrase')),
          const SizedBox(height: 18),
          GradientButton(label: _busy ? 'Encrypting…' : 'Create encrypted backup', onPressed: _busy ? null : _export),
          if (_status != null)
            Padding(padding: const EdgeInsets.only(top: 16), child: Text(_status!, style: TextStyle(color: t.muted, fontSize: 13))),
          const SizedBox(height: 28),
          Divider(color: t.border),
          const SizedBox(height: 16),
          const Text('Migrate to another app', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.warning_amber_rounded, size: 15, color: t.warn),
            const SizedBox(width: 7),
            Expanded(
              child: Text('A plaintext otpauth:// export is also available for moving to another authenticator. '
                  'It is UNENCRYPTED — use once and delete.',
                  style: TextStyle(fontSize: 12, color: t.warn, height: 1.45)),
            ),
          ]),
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(side: BorderSide(color: t.border), foregroundColor: t.muted),
            onPressed: () {
              final uris = Backup.exportOtpauthUris(widget.vault); // TODO: gate behind warning + share sheet
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
