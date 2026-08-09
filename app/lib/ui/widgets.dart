import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';

const kMono = 'monospace';

/// The brand lockmark: a lock glyph on a gradient rounded square.
class Lockmark extends StatelessWidget {
  final double size;
  const Lockmark({super.key, this.size = 24});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.accent, t.accentDeep],
        ),
        boxShadow: [BoxShadow(color: t.accentDeep.withOpacity(0.4), blurRadius: size * 0.6, offset: Offset(0, size * 0.25))],
      ),
      child: Icon(Icons.lock_outline_rounded, size: size * 0.58, color: t.onAccent),
    );
  }
}

/// Full-width gradient primary button.
class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const GradientButton({super.key, required this.label, this.onPressed});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(15),
          child: Ink(
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [t.accent, t.accentDeep],
              ),
            ),
            child: Center(
              child: Text(label,
                  style: TextStyle(color: t.onAccent, fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: -0.2)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Colored rounded-square avatar with the issuer's initials.
class IssuerAvatar extends StatelessWidget {
  final String issuer;
  const IssuerAvatar({super.key, required this.issuer});

  static const _palette = [
    Color(0xFFE2E8F0), Color(0xFFF6A04A), Color(0xFFFACC4A),
    Color(0xFF8B9CF7), Color(0xFF6EE7B7), Color(0xFFF0776F), Color(0xFFA7C5EB),
  ];

  @override
  Widget build(BuildContext context) {
    final initials = _initials(issuer);
    final color = _palette[issuer.codeUnits.fold<int>(0, (a, b) => a + b) % _palette.length];
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(13)),
      alignment: Alignment.center,
      child: Text(initials,
          style: const TextStyle(color: Color(0xFF06120D), fontWeight: FontWeight.w700, fontSize: 16)),
    );
  }

  static String _initials(String s) {
    final trimmed = s.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
    return trimmed.substring(0, trimmed.length >= 2 ? 2 : 1);
  }
}

/// Circular countdown that colors from accent → danger as time runs out.
class CountdownRing extends StatelessWidget {
  final int remaining; // seconds left
  final int period;
  const CountdownRing({super.key, required this.remaining, required this.period});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final color = remaining <= 5 ? t.danger : t.accent;
    return SizedBox(
      width: 34,
      height: 34,
      child: CustomPaint(
        painter: _RingPainter(progress: remaining / period, color: color, track: t.border),
        child: Center(
          child: Text('$remaining',
              style: TextStyle(fontFamily: kMono, fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color, track;
  _RingPainter({required this.progress, required this.color, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.width - 3) / 2;
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = track;
    canvas.drawCircle(center, radius, trackPaint);
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, progress.clamp(0, 1) * 2 * math.pi, false, arcPaint);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.color != color;
}
