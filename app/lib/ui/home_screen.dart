import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/totp.dart';
import '../core/vault.dart';
import 'backup_screen.dart';

/// The main list of live TOTP codes.
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('2FA'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Encrypted export',
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => BackupScreen(vault: widget.vault))),
          ),
        ],
      ),
      body: widget.vault.entries.isEmpty
          ? const Center(child: Text('No accounts yet. Tap + to scan a QR code.'))
          : ListView(
              children: widget.vault.entries.map((e) {
                final code = Totp.generate(e.secretBytes,
                    digits: e.digits, period: e.period, algorithm: e.algorithm);
                final left = Totp.secondsRemaining(period: e.period);
                return ListTile(
                  title: Text(
                    '${code.substring(0, code.length ~/ 2)} ${code.substring(code.length ~/ 2)}',
                    style: const TextStyle(fontSize: 28, fontFeatures: [FontFeature.tabularFigures()]),
                  ),
                  subtitle: Text(e.issuer.isEmpty ? e.label : '${e.issuer} · ${e.label}'),
                  trailing: SizedBox(
                    width: 28, height: 28,
                    child: CircularProgressIndicator(value: left / e.period, strokeWidth: 3),
                  ),
                );
              }).toList(),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {}, // TODO: open mobile_scanner → TotpEntry.fromUri → add to vault → push()
        child: const Icon(Icons.qr_code_scanner),
      ),
    );
  }
}
