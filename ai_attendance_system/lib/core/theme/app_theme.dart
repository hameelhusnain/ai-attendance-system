import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const brandGreen = Color(0xFF00D18E);
  static const accentOrange = Color(0xFFFF8A00);
  static const accentPurple = Color(0xFF8B5CF6);
  static const surfaceDark = Color(0xFF0B0B10);
  static const surfaceAlt = Color(0xFF12141B);
  static const surfaceCard = Color(0xFF151923);
  static const border = Color(0xFF262B36);
  static const textPrimary = Color(0xFFF5F7FF);
  static const textSecondary = Color(0xFFB1B9C6);
  static const muted = Color(0xFF7C8698);
  static const danger = Color(0xFFFF5C5C);
  static const lightSurface = Color(0xFFF4F6FA);
  static const lightSurfaceAlt = Color(0xFFEFF2F7);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightBorder = Color(0xFFD7DEE8);
  static const lightTextPrimary = Color(0xFF101318);
  static const lightTextSecondary = Color(0xFF5C667A);
  static const lightMuted = Color(0xFF7A8499);

  static bool isDarkTheme(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color surfaceCardFor(BuildContext context) =>
      isDarkTheme(context) ? surfaceCard : lightCard;
  static Color surfaceAltFor(BuildContext context) =>
      isDarkTheme(context) ? surfaceAlt : lightSurfaceAlt;
  static Color borderFor(BuildContext context) =>
      isDarkTheme(context) ? border : lightBorder;
  static Color textPrimaryFor(BuildContext context) =>
      isDarkTheme(context) ? textPrimary : lightTextPrimary;
  static Color textSecondaryFor(BuildContext context) =>
      isDarkTheme(context) ? textSecondary : lightTextSecondary;
  static Color mutedFor(BuildContext context) => isDarkTheme(context) ? muted : lightMuted;

  static ThemeData get light {
    final base = ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: brandGreen,
        brightness: Brightness.light,
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.soraTextTheme(base.textTheme).apply(
        bodyColor: lightTextPrimary,
        displayColor: lightTextPrimary,
      ),
      scaffoldBackgroundColor: lightSurface,
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: const BorderSide(color: Color(0xFFD4DCE7)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: brandGreen, width: 1.2),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightCard,
        selectedItemColor: brandGreen,
        unselectedItemColor: lightTextSecondary,
        type: BottomNavigationBarType.fixed,
      ),
      dividerColor: lightBorder,
    );
  }

  static ThemeData get dark {
    final scheme = const ColorScheme.dark(
      primary: brandGreen,
      onPrimary: Color(0xFF04120C),
      secondary: accentOrange,
      onSecondary: Color(0xFF1A0E02),
      tertiary: accentPurple,
      onTertiary: Colors.white,
      background: surfaceDark,
      onBackground: textPrimary,
      surface: surfaceCard,
      onSurface: textPrimary,
      surfaceVariant: surfaceAlt,
      onSurfaceVariant: textSecondary,
      error: danger,
      onError: Colors.white,
    );

    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: scheme,
    );
    final textTheme = GoogleFonts.soraTextTheme(base.textTheme).apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );

    return base.copyWith(
      scaffoldBackgroundColor: surfaceDark,
      textTheme: textTheme,
      dividerColor: border,
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceDark,
        foregroundColor: textPrimary,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: surfaceCard,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: brandGreen,
          foregroundColor: const Color(0xFF04120C),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: const BorderSide(color: accentPurple),
          foregroundColor: textPrimary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: textSecondary),
        labelStyle: const TextStyle(color: textSecondary),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accentPurple, width: 1.2),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceAlt,
        selectedItemColor: brandGreen,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceAlt,
        selectedColor: brandGreen.withOpacity(0.2),
        labelStyle: const TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: surfaceCard,
        textStyle: TextStyle(color: textPrimary),
      ),
    );
  }
}
