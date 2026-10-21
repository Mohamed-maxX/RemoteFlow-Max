import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Deep Cyber Navy Backgrounds
  static const Color bgDark = Color(0xFF070B19);
  static const Color bgDarkSecondary = Color(0xFF0F172A);
  static const Color bgSurface = Color(0xFF111C35);
  static const Color bgCard = Color(0x331E293B);
  static const Color bgCardHover = Color(0x661E293B);
  static const Color bgGlass = Color(0x1FFFFFFF);

  // Vibrant Neon Accents
  static const Color cyanNeon = Color(0xFF00E5FF);
  static const Color cyanGlow = cyanNeon;
  static const Color orangeNeon = Color(0xFFFF6B00);
  static const Color purpleNeon = Color(0xFF7C3AED);
  static const Color emeraldNeon = Color(0xFF10B981);
  static const Color roseNeon = Color(0xFFF43F5E);
  static const Color amberNeon = Color(0xFFFFB703);

  // Status Colors
  static const Color greenActive = Color(0xFF10B981);
  static const Color redAlert = Color(0xFFEF4444);

  // Text Colors
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Borders
  static const Color borderSubtle = Color(0x2600E5FF);
  static const Color borderHighlight = Color(0x6600E5FF);
  static const Color borderGlass = Color(0x26FFFFFF);

  // Gradients
  static const LinearGradient bgGradient = LinearGradient(
    colors: [Color(0xFF050814), Color(0xFF0A1024), Color(0xFF0F172A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient neonAccentGradient = LinearGradient(
    colors: [cyanNeon, purpleNeon, orangeNeon],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassCardGradient = LinearGradient(
    colors: [Color(0x331E293B), Color(0x1A0F172A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cyanGlowGradient = LinearGradient(
    colors: [Color(0xFF00E5FF), Color(0xFF0091EA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient orangeGlowGradient = LinearGradient(
    colors: [Color(0xFFFF6B00), Color(0xFFFF3D00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static BoxDecoration glassDecoration({
    Color? borderColor,
    double borderRadius = 18,
    Color? fillColor,
    bool glow = false,
    Color? glowColor,
  }) {
    return BoxDecoration(
      color: fillColor ?? const Color(0x22131F37),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? borderGlass,
        width: 1.2,
      ),
      boxShadow: glow
          ? [
              BoxShadow(
                color: (glowColor ?? cyanNeon).withOpacity(0.25),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ]
          : [
              const BoxShadow(
                color: Color(0x40000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
    );
  }

  static ThemeData get darkTheme {
    final baseTextTheme = ThemeData.dark().textTheme;
    final cairoTextTheme = GoogleFonts.cairoTextTheme(baseTextTheme);

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      primaryColor: cyanNeon,
      colorScheme: const ColorScheme.dark(
        primary: cyanNeon,
        secondary: orangeNeon,
        tertiary: purpleNeon,
        surface: bgSurface,
      ),
      textTheme: cairoTextTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.cairo(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cyanNeon,
          foregroundColor: bgDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15),
          elevation: 6,
          shadowColor: cyanNeon.withOpacity(0.4),
        ),
      ),
    );
  }
}
