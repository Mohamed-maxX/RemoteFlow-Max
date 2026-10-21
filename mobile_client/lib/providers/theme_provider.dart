import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/preferences_service.dart';

enum AppThemeMode {
  cinematicNeon, // ثيم نيون سينمائي
  floatingGlass, // ثيم زجاجي عائم
  cyberGaming,   // ثيم ألعاب داكن
}

class ThemeConfig {
  final AppThemeMode mode;
  final String title;
  final IconData icon;
  final Color primaryColor;
  final Color accentColor;
  final Color secondaryAccent;
  final Color bgDark;
  final Color bgSurface;
  final LinearGradient bgGradient;
  final Color cardFillColor;
  final Color cardBorderColor;
  final Color glowColor;
  final ThemeData themeData;

  const ThemeConfig({
    required this.mode,
    required this.title,
    required this.icon,
    required this.primaryColor,
    required this.accentColor,
    required this.secondaryAccent,
    required this.bgDark,
    required this.bgSurface,
    required this.bgGradient,
    required this.cardFillColor,
    required this.cardBorderColor,
    required this.glowColor,
    required this.themeData,
  });

  static ThemeConfig forMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.floatingGlass:
        const primary = Color(0xFF38BDF8); // Crystal Light Blue
        const accent = Color(0xFF2DD4BF);  // Aquamarine Ice
        const bg1 = Color(0xFF0B132B);
        const bg2 = Color(0xFF1C2541);
        const bg3 = Color(0xFF283457);

        return ThemeConfig(
          mode: mode,
          title: "ثيم زجاجي عائم",
          icon: Icons.blur_on_rounded,
          primaryColor: primary,
          accentColor: accent,
          secondaryAccent: const Color(0xFF818CF8),
          bgDark: bg1,
          bgSurface: const Color(0x33FFFFFF),
          bgGradient: const LinearGradient(
            colors: [bg1, bg2, bg3],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          cardFillColor: const Color(0x28FFFFFF),
          cardBorderColor: const Color(0x38FFFFFF),
          glowColor: primary,
          themeData: _buildThemeData(
            brightness: Brightness.dark,
            primary: primary,
            scaffoldBg: bg1,
            surface: const Color(0xFF1C2541),
          ),
        );

      case AppThemeMode.cyberGaming:
        const primary = Color(0xFF10B981); // Toxic Emerald / Lime
        const accent = Color(0xFFFF3366);  // Blazing Crimson
        const bg1 = Color(0xFF08090C);
        const bg2 = Color(0xFF101218);
        const bg3 = Color(0xFF181B24);

        return ThemeConfig(
          mode: mode,
          title: "ثيم ألعاب داكن",
          icon: Icons.sports_esports_rounded,
          primaryColor: primary,
          accentColor: accent,
          secondaryAccent: const Color(0xFFFF6600),
          bgDark: bg1,
          bgSurface: const Color(0xFF141824),
          bgGradient: const LinearGradient(
            colors: [bg1, bg2, bg3],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          cardFillColor: const Color(0x40161A24),
          cardBorderColor: const Color(0x4010B981),
          glowColor: primary,
          themeData: _buildThemeData(
            brightness: Brightness.dark,
            primary: primary,
            scaffoldBg: bg1,
            surface: const Color(0xFF101218),
          ),
        );

      case AppThemeMode.cinematicNeon:
      default:
        const primary = Color(0xFF00E5FF); // Electric Cyan
        const accent = Color(0xFF7C3AED);  // Violet
        const bg1 = Color(0xFF050814);
        const bg2 = Color(0xFF0A1024);
        const bg3 = Color(0xFF0F172A);

        return ThemeConfig(
          mode: mode,
          title: "ثيم نيون سينمائي",
          icon: Icons.auto_awesome_rounded,
          primaryColor: primary,
          accentColor: accent,
          secondaryAccent: const Color(0xFFFF6B00),
          bgDark: bg1,
          bgSurface: const Color(0xFF111C35),
          bgGradient: const LinearGradient(
            colors: [bg1, bg2, bg3],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          cardFillColor: const Color(0x33101C38),
          cardBorderColor: const Color(0x2600E5FF),
          glowColor: primary,
          themeData: _buildThemeData(
            brightness: Brightness.dark,
            primary: primary,
            scaffoldBg: bg1,
            surface: const Color(0xFF111C35),
          ),
        );
    }
  }

  static ThemeData _buildThemeData({
    required Brightness brightness,
    required Color primary,
    required Color scaffoldBg,
    required Color surface,
  }) {
    final baseTextTheme = ThemeData.dark().textTheme;
    final cairoTextTheme = GoogleFonts.cairoTextTheme(baseTextTheme);

    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: scaffoldBg,
      primaryColor: primary,
      colorScheme: ColorScheme.dark(
        primary: primary,
        surface: surface,
      ),
      textTheme: cairoTextTheme.apply(
        bodyColor: const Color(0xFFF8FAFC),
        displayColor: const Color(0xFFF8FAFC),
      ),
    );
  }
}

class ThemeNotifier extends StateNotifier<ThemeConfig> {
  ThemeNotifier() : super(_getInitialTheme());

  static ThemeConfig _getInitialTheme() {
    final idx = PreferencesService.themeModeIndex;
    if (idx >= 0 && idx < AppThemeMode.values.length) {
      return ThemeConfig.forMode(AppThemeMode.values[idx]);
    }
    return ThemeConfig.forMode(AppThemeMode.cinematicNeon);
  }

  void setTheme(AppThemeMode mode) {
    state = ThemeConfig.forMode(mode);
    PreferencesService.setThemeModeIndex(mode.index);
  }

  void cycleNext() {
    final nextIndex = (state.mode.index + 1) % AppThemeMode.values.length;
    setTheme(AppThemeMode.values[nextIndex]);
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeConfig>((ref) {
  return ThemeNotifier();
});
