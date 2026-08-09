import 'package:flutter/material.dart';

/// Custom design tokens beyond the Material ColorScheme (the "quiet vault" look).
/// Read via `Theme.of(context).extension<AppTokens>()!`.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  final Color surface2, border, muted, accent, accentDeep, onAccent, warn, danger;
  const AppTokens({
    required this.surface2,
    required this.border,
    required this.muted,
    required this.accent,
    required this.accentDeep,
    required this.onAccent,
    required this.warn,
    required this.danger,
  });

  static const dark = AppTokens(
    surface2: Color(0xFF17211D),
    border: Color(0xFF223029),
    muted: Color(0xFF7C8B83),
    accent: Color(0xFF34D399),
    accentDeep: Color(0xFF10B981),
    onAccent: Color(0xFF06120D),
    warn: Color(0xFFF5B54A),
    danger: Color(0xFFF0776F),
  );

  static const light = AppTokens(
    surface2: Color(0xFFEEF3F0),
    border: Color(0xFFE1E9E4),
    muted: Color(0xFF5C6B63),
    accent: Color(0xFF12A150),
    accentDeep: Color(0xFF0E8A45),
    onAccent: Color(0xFFFFFFFF),
    warn: Color(0xFFB4791C),
    danger: Color(0xFFD4544C),
  );

  @override
  AppTokens copyWith({
    Color? surface2, Color? border, Color? muted, Color? accent,
    Color? accentDeep, Color? onAccent, Color? warn, Color? danger,
  }) =>
      AppTokens(
        surface2: surface2 ?? this.surface2,
        border: border ?? this.border,
        muted: muted ?? this.muted,
        accent: accent ?? this.accent,
        accentDeep: accentDeep ?? this.accentDeep,
        onAccent: onAccent ?? this.onAccent,
        warn: warn ?? this.warn,
        danger: danger ?? this.danger,
      );

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      surface2: Color.lerp(surface2, other.surface2, t)!,
      border: Color.lerp(border, other.border, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentDeep: Color.lerp(accentDeep, other.accentDeep, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

class AppTheme {
  static ThemeData dark() => _build(Brightness.dark);
  static ThemeData light() => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final tokens = isDark ? AppTokens.dark : AppTokens.light;
    final bg = isDark ? const Color(0xFF0A0F0D) : const Color(0xFFEEF2F0);
    final surface = isDark ? const Color(0xFF111A16) : const Color(0xFFFFFFFF);
    final text = isDark ? const Color(0xFFE9F1EC) : const Color(0xFF10201A);

    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF16A34A),
      brightness: brightness,
    ).copyWith(
      surface: surface,
      onSurface: text,
      primary: tokens.accent,
      onPrimary: tokens.onAccent,
    );

    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: c, width: w),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      extensions: [tokens],
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardColor: surface,
      dividerColor: tokens.border,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surface2,
        labelStyle: TextStyle(color: tokens.muted, fontSize: 13),
        floatingLabelStyle: TextStyle(color: tokens.accent),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: border(tokens.border),
        enabledBorder: border(tokens.border),
        focusedBorder: border(tokens.accent, 1.5),
      ),
    );
  }
}
