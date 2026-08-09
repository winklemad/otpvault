import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config.dart';
import '../theme.dart';
import '../core/crypto.dart';
import '../core/keybag.dart';
import '../core/sync_client.dart';
import 'widgets.dart';

/// Signup: credentials → **recovery-key reveal (the critical step)** → create
/// account. Calls back with the unlocked [Keybag] on success.
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
          child: _step == _Step.credentials ? _credentials() : _recovery(),
        ),
      ),
    );
  }

  Widget _errorText() => _error == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(_error!, style: TextStyle(color: Theme.of(context).extension<AppTokens>()!.danger, fontSize: 13)),
        );

  Widget _credentials() {
    final t = Theme.of(context).extension<AppTokens>()!;
    return Column(children: [
      const SizedBox(height: 24),
      const Center(child: Lockmark(size: 60)),
      const SizedBox(height: 22),
      const Text('Create your vault',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
      const SizedBox(height: 8),
      Text('Your codes, encrypted end-to-end and synced across every device you own.',
          textAlign: TextAlign.center, style: TextStyle(color: t.muted, fontSize: 13.5, height: 1.5)),
      const SizedBox(height: 26),
      TextField(controller: _handle, decoration: const InputDecoration(labelText: 'Handle (email or username)')),
      const SizedBox(height: 13),
      TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Master password')),
      const SizedBox(height: 8),
      Text("Encrypts your vault on this device. It's never sent to our servers, and it can't be reset without your recovery key.",
          style: TextStyle(color: t.muted, fontSize: 11.5, height: 1.45)),
      _errorText(),
      const Spacer(),
      GradientButton(label: _busy ? 'Preparing…' : 'Continue', onPressed: _busy ? null : _prepare),
    ]);
  }

  Widget _recovery() {
    final t = Theme.of(context).extension<AppTokens>()!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: t.warn.withOpacity(0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: t.warn.withOpacity(0.35)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.warning_amber_rounded, size: 14, color: t.warn),
          const SizedBox(width: 6),
          Text('IMPORTANT — SAVE THIS',
              style: TextStyle(color: t.warn, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        ]),
      ),
      const SizedBox(height: 16),
      const Text('Your recovery key', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
      const SizedBox(height: 8),
      Text("The only way back in if you forget your password or lose every device. Store it in a password manager or on paper — we can't recover it for you.",
          style: TextStyle(color: t.muted, fontSize: 13.5, height: 1.5)),
      const SizedBox(height: 18),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Color.alphaBlend(t.warn.withOpacity(0.45), t.border)),
        ),
        child: Column(children: [
          SelectableText(_recoveryKey ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: kMono, fontSize: 15, letterSpacing: 2, height: 1.8)),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: _recoveryKey ?? ''));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recovery key copied')));
            },
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.copy_rounded, size: 15, color: t.accent),
              const SizedBox(width: 7),
              Text('Copy recovery key', style: TextStyle(color: t.accent, fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 4),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: _saved,
        activeColor: t.accent,
        onChanged: (v) => setState(() => _saved = v ?? false),
        title: const Text('I have saved my recovery key somewhere safe', style: TextStyle(fontSize: 13.5)),
      ),
      _errorText(),
      const Spacer(),
      GradientButton(
        label: _busy ? 'Creating…' : 'Create account',
        onPressed: (_saved && !_busy) ? _createAccount : null,
      ),
    ]);
  }
}
