import 'dart:async';
import 'package:flutter/material.dart';
import 'core/totp.dart';
import 'core/vault.dart';

/// Phase 0 skeleton: a local-only authenticator (no backend). It generates
/// live TOTP codes from an in-memory vault. Wire in QR scanning (mobile_scanner),
/// local persistence, then cloud sync (core/sync_client.dart) from here.
void main() => runApp(const TwoFaApp());

class TwoFaApp extends StatelessWidget {
  const TwoFaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '2FA',
        theme: ThemeData(colorSchemeSeed: const Color(0xFF1A9E57), useMaterial3: true),
        home: const HomeScreen(),
      );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _timer;

  // Demo entry (replace with a loaded, decrypted vault).
  final Vault _vault = Vault([
    TotpEntry(issuer: 'Example', label: 'you@example.com', secretBase32: 'JBSWY3DPEHPK3PXP'),
  ]);

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
    return Scaffold(
      appBar: AppBar(title: const Text('2FA')),
      body: ListView(
        children: _vault.entries.map((e) {
          final code = Totp.generate(e.secretBytes,
              digits: e.digits, period: e.period, algorithm: e.algorithm);
          final left = Totp.secondsRemaining(period: e.period);
          return ListTile(
            title: Text('${code.substring(0, code.length ~/ 2)} ${code.substring(code.length ~/ 2)}',
                style: const TextStyle(fontSize: 28, fontFeatures: [FontFeature.tabularFigures()])),
            subtitle: Text(e.issuer.isEmpty ? e.label : '${e.issuer} · ${e.label}'),
            trailing: SizedBox(
              width: 28, height: 28,
              child: CircularProgressIndicator(value: left / e.period, strokeWidth: 3),
            ),
          );
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {}, // TODO: open mobile_scanner and add via TotpEntry.fromUri
        child: const Icon(Icons.qr_code_scanner),
      ),
    );
  }
}
