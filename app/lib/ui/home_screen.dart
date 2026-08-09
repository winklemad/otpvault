import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../core/totp.dart';
import '../core/vault.dart';
import 'backup_screen.dart';
import 'widgets.dart';

/// The main list of live TOTP codes — the "quiet vault" home.
class HomeScreen extends StatefulWidget {
  final Vault vault;
  const HomeScreen({super.key, required this.vault});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(children: [
          const Lockmark(size: 24),
          const SizedBox(width: 9),
          const Text('OTPVault', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19, letterSpacing: -0.3)),
        ]),
        actions: [
          IconButton(onPressed: () {}, icon: Icon(Icons.search_rounded, color: t.muted)),
          IconButton(
            tooltip: 'Encrypted export',
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => BackupScreen(vault: widget.vault))),
            icon: Icon(Icons.ios_share_rounded, color: t.muted),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: widget.vault.entries.isEmpty
          ? _empty(t)
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              itemCount: widget.vault.entries.length,
              itemBuilder: (_, i) => _CodeCard(entry: widget.vault.entries[i]),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {}, // TODO: mobile_scanner → TotpEntry.fromUri → add + push()
        backgroundColor: t.accent,
        foregroundColor: t.onAccent,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _empty(AppTokens t) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lockmark(size: 56),
            const SizedBox(height: 20),
            const Text('No accounts yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Tap  +  to scan a QR code and add your first account.',
                style: TextStyle(color: t.muted, fontSize: 13)),
          ],
        ),
      );
}

class _CodeCard extends StatelessWidget {
  final TotpEntry entry;
  const _CodeCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final scheme = Theme.of(context).colorScheme;
    final code = Totp.generate(entry.secretBytes,
        digits: entry.digits, period: entry.period, algorithm: entry.algorithm);
    final remaining = Totp.secondsRemaining(period: entry.period);
    final expiring = remaining <= 5;

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.fromLTRB(14, 13, 15, 14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IssuerAvatar(issuer: entry.issuer.isEmpty ? entry.label : entry.issuer),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.issuer.isEmpty ? entry.label : entry.issuer,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: -0.1)),
                if (entry.issuer.isNotEmpty && entry.label.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(entry.label,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: t.muted, fontSize: 12)),
                  ),
                const SizedBox(height: 7),
                Text(
                  code, // single unbroken 6-digit value
                  style: TextStyle(
                    fontFamily: kMono,
                    fontSize: 27,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 4,
                    color: expiring ? t.danger : scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          CountdownRing(remaining: remaining, period: entry.period),
        ],
      ),
    );
  }
}
