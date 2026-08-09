import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../theme.dart';
import '../core/vault.dart';
import 'backup_screen.dart';
import 'code_card.dart';
import 'widgets.dart';

/// Adaptive home. One codebase, three shells sharing the same theme + cards:
///   • narrow  → mobile: single column + FAB
///   • web wide → top-nav + responsive grid
///   • desktop wide → sidebar + responsive grid
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
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 700) return _MobileHome(vault: widget.vault);
      if (kIsWeb) return _WebHome(vault: widget.vault);
      return _DesktopHome(vault: widget.vault);
    });
  }
}

void _openExport(BuildContext context, Vault vault) => Navigator.of(context)
    .push(MaterialPageRoute(builder: (_) => BackupScreen(vault: vault)));

// Responsive grid of code cards, shared by web + desktop.
Widget _grid(Vault vault) => GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 380,
        mainAxisExtent: 92,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: vault.entries.length,
      itemBuilder: (_, i) => CodeCard(entry: vault.entries[i]),
    );

Widget _sectionHead(BuildContext context, String title, String sub) {
  final t = Theme.of(context).extension<AppTokens>()!;
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
    const SizedBox(height: 2),
    Text(sub, style: TextStyle(color: t.muted, fontSize: 12.5)),
  ]);
}

// ---------------------------------------------------------------- MOBILE

class _MobileHome extends StatelessWidget {
  final Vault vault;
  const _MobileHome({required this.vault});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(children: const [
          Lockmark(size: 23),
          SizedBox(width: 9),
          Text('Vault', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19, letterSpacing: -0.3)),
        ]),
        actions: [
          IconButton(onPressed: () {}, icon: Icon(Icons.search_rounded, color: t.muted)),
          IconButton(
              tooltip: 'Encrypted export',
              onPressed: () => _openExport(context, vault),
              icon: Icon(Icons.ios_share_rounded, color: t.muted)),
          const SizedBox(width: 6),
        ],
      ),
      body: vault.entries.isEmpty
          ? const _EmptyState()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(15, 4, 15, 96),
              itemCount: vault.entries.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CodeCard(entry: vault.entries[i]),
              ),
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
}

// ---------------------------------------------------------------- WEB

class _WebHome extends StatelessWidget {
  final Vault vault;
  const _WebHome({required this.vault});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Column(children: [
        // top nav
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          decoration: BoxDecoration(color: scheme.surface, border: Border(bottom: BorderSide(color: t.border))),
          child: Row(children: [
            const Lockmark(size: 24),
            const SizedBox(width: 9),
            const Text('OTPVault', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: -0.3)),
            const SizedBox(width: 18),
            _NavPill(label: 'Vault', active: true, onTap: () {}),
            _NavPill(label: 'Settings', onTap: () {}),
            const Spacer(),
            _SearchBox(width: 200),
            const SizedBox(width: 10),
            IconButton(
                tooltip: 'Encrypted export',
                onPressed: () => _openExport(context, vault),
                icon: Icon(Icons.ios_share_rounded, color: t.muted, size: 20)),
            const SizedBox(width: 4),
            _AddButton(onPressed: () {}),
            const SizedBox(width: 14),
            CircleAvatar(radius: 16, backgroundColor: const Color(0xFF8B9CF7),
                child: Text('M', style: TextStyle(color: t.onAccent, fontWeight: FontWeight.w700, fontSize: 13))),
          ]),
        ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _sectionHead(context, 'Your codes', '${vault.entries.length} accounts · end-to-end encrypted'),
                  const SizedBox(height: 16),
                  Expanded(child: vault.entries.isEmpty ? const _EmptyState() : _grid(vault)),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- DESKTOP

class _DesktopHome extends StatelessWidget {
  final Vault vault;
  const _DesktopHome({required this.vault});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Row(children: [
        // sidebar
        Container(
          width: 216,
          decoration: BoxDecoration(color: scheme.surface, border: Border(right: BorderSide(color: t.border))),
          padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
              child: Row(children: const [
                Lockmark(size: 24),
                SizedBox(width: 9),
                Text('OTPVault', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: -0.3)),
              ]),
            ),
            _NavItem(icon: Icons.lock_outline_rounded, label: 'Vault', active: true, onTap: () {}),
            _NavItem(icon: Icons.import_export_rounded, label: 'Import / Export', onTap: () => _openExport(context, vault)),
            _NavItem(icon: Icons.settings_outlined, label: 'Settings', onTap: () {}),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: t.border))),
              child: Row(children: [
                Container(width: 7, height: 7, decoration: BoxDecoration(color: t.accent, shape: BoxShape.circle)),
                const SizedBox(width: 9),
                Text('Synced · winklemad', style: TextStyle(color: t.muted, fontSize: 12)),
              ]),
            ),
          ]),
        ),
        // main
        Expanded(
          child: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.border))),
              child: Row(children: [
                const Expanded(child: _SearchBox()),
                const SizedBox(width: 12),
                _AddButton(label: 'Add account', onPressed: () {}),
              ]),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: vault.entries.isEmpty ? const _EmptyState() : _grid(vault),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- shared bits

class _NavPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavPill({required this.label, this.active = false, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: active ? t.accent : t.muted,
        backgroundColor: active ? t.accent.withOpacity(0.14) : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, this.active = false, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: active ? t.accent.withOpacity(0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Icon(icon, size: 18, color: active ? t.accent : t.muted),
              const SizedBox(width: 10),
              Text(label,
                  style: TextStyle(
                      color: active ? t.accent : t.muted, fontSize: 13.5, fontWeight: FontWeight.w500)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  final double? width;
  const _SearchBox({this.width});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return Container(
      width: width,
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: t.surface2,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: t.border),
      ),
      child: Row(children: [
        Icon(Icons.search_rounded, size: 16, color: t.muted),
        const SizedBox(width: 9),
        Text('Search accounts', style: TextStyle(color: t.muted, fontSize: 13.5)),
      ]),
    );
  }
}

class _AddButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _AddButton({this.label = 'Add', required this.onPressed});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: t.accent,
        foregroundColor: t.onAccent,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
      icon: const Icon(Icons.add_rounded, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Lockmark(size: 56),
        const SizedBox(height: 20),
        const Text('No accounts yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('Add your first account to start generating codes.',
            style: TextStyle(color: t.muted, fontSize: 13)),
      ]),
    );
  }
}
