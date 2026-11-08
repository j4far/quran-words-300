import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;

import '../state/app_state.dart';

class Brand {
  static const primary = Color(0xFF006B5A);
  static const deep = Color(0xFF004C43);
  static const gold = Color(0xFFC99A2E);
  static const cream = Color(0xFFFFF8EC);
  static const paper = Color(0xFFFFFCF5);
  static const ink = Color(0xFF182B2A);
  static const muted = Color(0xFF5F6F6A);
  static const line = Color(0xFFE8DCC5);
}

/// Extra colours the screens need beyond the Material scheme.
@immutable
class QwColors extends ThemeExtension<QwColors> {
  const QwColors({
    required this.gold,
    required this.panel,
    required this.arabic,
    required this.success,
    required this.error,
    required this.line,
    required this.muted,
    required this.hero,
    required this.onHero,
  });

  final Color gold;
  final Color panel;
  final Color arabic;
  final Color success;
  final Color error;
  final Color line;
  final Color muted;
  final Color hero;
  final Color onHero;

  @override
  QwColors copyWith() => this;

  @override
  QwColors lerp(QwColors? other, double t) => other ?? this;
}

extension QwThemeX on BuildContext {
  QwColors get qw => Theme.of(this).extension<QwColors>()!;
}

ThemeData buildTheme(Brightness b, AppSettings s) {
  final dark = b == Brightness.dark;
  final hc = s.highContrast;
  final dys = s.dyslexiaMode;

  final bg = dark
      ? (hc ? Colors.black : const Color(0xFF0E1918))
      : (hc ? Colors.white : (dys ? const Color(0xFFFFF3DD) : Brand.paper));
  final surface = dark
      ? (hc ? const Color(0xFF111111) : const Color(0xFF172524))
      : (hc ? Colors.white : (dys ? const Color(0xFFFFF8E8) : Colors.white));
  final ink = dark ? (hc ? Colors.white : const Color(0xFFE7F0EE)) : (hc ? Colors.black : Brand.ink);
  final primary = dark
      ? (hc ? const Color(0xFF7FF0D8) : const Color(0xFF5CC3AC))
      : (hc ? const Color(0xFF00463B) : Brand.primary);

  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.primary,
    brightness: b,
  ).copyWith(
    primary: primary,
    onPrimary: dark ? Colors.black : Colors.white,
    secondary: Brand.gold,
    surface: surface,
    onSurface: ink,
    surfaceContainerLowest: bg,
    outline: dark ? const Color(0xFF3A4C4A) : (hc ? Colors.black54 : Brand.line),
  );

  final colors = QwColors(
    gold: dark ? const Color(0xFFE0B955) : Brand.gold,
    panel: dark
        ? (hc ? const Color(0xFF1A1A1A) : const Color(0xFF1D2E2C))
        : (dys ? const Color(0xFFFCEBCB) : Brand.cream),
    arabic: dys
        ? (dark ? const Color(0xFF9CC4FF) : const Color(0xFF1C4E9A))
        : ink,
    success: dark ? const Color(0xFF6BD49B) : const Color(0xFF1E7B4F),
    error: dark ? const Color(0xFFFF8A80) : const Color(0xFFB3261E),
    line: dark ? const Color(0xFF2C3E3C) : (hc ? Colors.black38 : Brand.line),
    muted: dark ? (hc ? Colors.white70 : const Color(0xFF9DB0AC)) : (hc ? Colors.black87 : Brand.muted),
    hero: dark ? const Color(0xFF0B3D36) : Brand.deep,
    onHero: Brand.cream,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: b,
    scaffoldBackgroundColor: bg,
    extensions: [colors],
    splashFactory: s.reducedMotion ? NoSplash.splashFactory : null,
    pageTransitionsTheme: s.reducedMotion
        ? const PageTransitionsTheme(builders: {
            TargetPlatform.iOS: _NoTransition(),
            TargetPlatform.android: _NoTransition(),
          })
        : const PageTransitionsTheme(builders: {
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          }),
  );

  final text = base.textTheme.apply(
    bodyColor: ink,
    displayColor: ink,
  );

  return base.copyWith(
    textTheme: dys
        ? text.copyWith(
            bodyLarge: text.bodyLarge?.copyWith(height: 1.6, letterSpacing: .4, fontSize: 17),
            bodyMedium: text.bodyMedium?.copyWith(height: 1.6, letterSpacing: .3, fontSize: 15.5),
          )
        : text,
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.line),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: primary.withValues(alpha: .14),
      elevation: 0,
      labelTextStyle: WidgetStatePropertyAll(
          text.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 52),
        side: BorderSide(color: colors.line, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide(color: colors.line),
    ),
    dividerTheme: DividerThemeData(color: colors.line, space: 1),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((st) =>
          st.contains(WidgetState.selected) ? Colors.white : colors.muted),
      trackColor: WidgetStateProperty.resolveWith((st) =>
          st.contains(WidgetState.selected) ? primary : colors.line.withValues(alpha: .6)),
      trackOutlineColor: WidgetStateProperty.resolveWith((st) =>
          st.contains(WidgetState.selected) ? primary : colors.muted),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),
  );
}

class _NoTransition extends PageTransitionsBuilder {
  const _NoTransition();
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context,
          Animation<double> a, Animation<double> b, Widget child) =>
      child;
}
