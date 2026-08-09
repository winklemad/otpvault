import 'package:flutter/material.dart';
import 'theme.dart';
import 'core/keybag.dart';
import 'core/vault.dart';
import 'ui/onboarding_screen.dart';
import 'ui/home_screen.dart';

void main() => runApp(const TwoFaApp());

class TwoFaApp extends StatelessWidget {
  const TwoFaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'OTPVault',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.dark, // dark-first "quiet vault" look
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
        TotpEntry(issuer: 'GitHub', label: 'winklemad', secretBase32: 'JBSWY3DPEHPK3PXP'),
        TotpEntry(issuer: 'Cloudflare', label: 'admin@nuivio.com', secretBase32: 'KRSXG5CTMVRXEZLU'),
        TotpEntry(issuer: 'AWS', label: 'root', secretBase32: 'NB2W45DFOIZA'),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) return OnboardingScreen(onComplete: _onOnboarded);
    return HomeScreen(vault: _vault!);
  }
}
