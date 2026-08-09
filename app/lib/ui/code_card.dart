import 'package:flutter/material.dart';
import '../theme.dart';
import '../core/totp.dart';
import '../core/vault.dart';
import 'widgets.dart';

/// A single account's live code — shared across the mobile list and the
/// web/desktop grid so every platform renders identically.
class CodeCard extends StatelessWidget {
  final TotpEntry entry;
  const CodeCard({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final scheme = Theme.of(context).colorScheme;
    final code = Totp.generate(entry.secretBytes,
        digits: entry.digits, period: entry.period, algorithm: entry.algorithm);
    final remaining = Totp.secondsRemaining(period: entry.period);
    final expiring = remaining <= 5;
    final hasBoth = entry.issuer.isNotEmpty && entry.label.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 15, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          IssuerAvatar(issuer: entry.issuer.isEmpty ? entry.label : entry.issuer),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.issuer.isEmpty ? entry.label : entry.issuer,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: -0.1)),
                if (hasBoth)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(entry.label,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: t.muted, fontSize: 12)),
                  ),
                const SizedBox(height: 6),
                Text(code, // single unbroken 6-digit value
                    style: TextStyle(
                      fontFamily: kMono,
                      fontSize: 25,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 3,
                      color: expiring ? t.danger : scheme.onSurface,
                    )),
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
