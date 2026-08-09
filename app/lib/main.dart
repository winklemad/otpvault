import 'package:flutter/material.dart';
import 'core/keybag.dart';
import 'core/vault.dart';
import 'ui/onboarding_screen.dart';
import 'ui/home_screen.dart';

void main() => runApp(const TwoFaApp());

class TwoFaApp extends StatelessWidget {
  const TwoFaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '2FA',
        theme: ThemeData(colorSchemeSeed: const Color(0xFF1A9E57), useMaterial3: true),
        home: const RootScreen(),
      );
}

/// Holds the unlocked session. Shows onboarding until an account exists, then
/// the code list. (Phase 0: an in-memory demo vault; wire local persistence +
/// sync next.)
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});
  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  Keybag? _session;
  Vault? _vault;

  void _onOnboarded(Keybag keybag) {
    setState(() {
      _session = keybag;
      _vault = Vault([
        TotpEntry(issuer: 'Example', label: 'you@example.com', secretBase32: 'JBSWY3DPEHPK3PXP'),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) return OnboardingScreen(onComplete: _onOnboarded);
    return HomeScreen(vault: _vault!);
  }
}
