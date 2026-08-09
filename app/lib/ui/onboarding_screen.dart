import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config.dart';
import '../core/crypto.dart';
import '../core/keybag.dart';
import '../core/sync_client.dart';

/// Signup flow: credentials → **recovery-key reveal (the critical step)** →
/// create account. Calls back with the unlocked [Keybag] on success.
class OnboardingScreen extends StatefulWidget {
  final void Function(Keybag keybag) onComplete;
  const OnboardingScreen({super.key, required this.onComplete});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _Step { credentials, recoveryKey }

class _OnboardingScreenState extends State<OnboardingScreen> {
  _Step _step = _Step.credentials;
  final _handle = TextEditingController();
  final _password = TextEditingController();

  String? _recoveryKey;
  KeybagInit? _init;
  String? _authVerifier;
  late final saltAuth = VaultCrypto.randomSalt();
  String? _resetTag;

  bool _busy = false;
  bool _saved = false;
  String? _error;

  Future<void> _prepare() async {
    if (_handle.text.trim().isEmpty || _password.text.length < 8) {
      setState(() => _error = 'Enter a handle and a password of at least 8 characters.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final rk = Keybag.generateRecoveryKey();
      final init = await Keybag.create(_password.text, rk); // argon2id ×2 — ~1s
      final verifier = await VaultCrypto.deriveAuthVerifier(_password.text, saltAuth);
      final tag = await init.keybag.resetTag();
      setState(() {
        _recoveryKey = rk;
        _init = init;
        _authVerifier = verifier;
        _resetTag = tag;
        _step = _Step.recoveryKey;
      });
    } catch (e) {
      setState(() => _error = 'Could not prepare account: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createAccount() async {
    setState(() { _busy = true; _error = null; });
    try {
      final client = SyncClient(kSyncBaseUrl);
      await client.signup(
        handle: _handle.text.trim(),
        authVerifier: _authVerifier!,
        saltAuth: saltAuth,
        wrappedDekPw: _init!.wrappedByPassword,
        saltPw: _init!.saltPw,
        wrappedDekRec: _init!.wrappedByRecovery,
        saltRec: _init!.saltRec,
        dekResetTag: _resetTag!,
      );
      widget.onComplete(_init!.keybag);
    } catch (e) {
      setState(() => _error = 'Signup failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _step == _Step.credentials ? _credentials() : _recovery(),
      ),
    );
  }

  Widget _credentials() => ListView(children: [
        TextField(controller: _handle, decoration: const InputDecoration(labelText: 'Handle (email or username)')),
        const SizedBox(height: 12),
        TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Master password')),
        const SizedBox(height: 8),
        const Text('This encrypts your vault. It is never sent to the server and cannot be reset without your recovery key.',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
        const SizedBox(height: 20),
        FilledButton(onPressed: _busy ? null : _prepare, child: _busy ? const Text('Preparing…') : const Text('Continue')),
      ]);

  Widget _recovery() => ListView(children: [
        const Text('Save your recovery key', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('This is the ONLY way back into your vault if you forget your password or lose all your devices. '
            'Write it down or store it in a password manager. We cannot recover it for you.'),
        const SizedBox(height: 16),
        Card(
          color: const Color(0xFFF2F4F5),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SelectableText(_recoveryKey ?? '',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 16, letterSpacing: 1)),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => Clipboard.setData(ClipboardData(text: _recoveryKey ?? '')),
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy'),
          ),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _saved,
          onChanged: (v) => setState(() => _saved = v ?? false),
          title: const Text('I have saved my recovery key somewhere safe'),
        ),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: (_saved && !_busy) ? _createAccount : null,
          child: _busy ? const Text('Creating…') : const Text('Create account'),
        ),
      ]);
}
