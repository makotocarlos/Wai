import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  const AppTheme._();

  static const Color _primaryGreen = Color(0xFF00FF88);
  static const Color _accentGreen = Color(0xFF00C76F);
  static const Color _background = Color(0xFF060606);
  static const Color _surface = Color(0xFF101010);
  static const Color _lightBackground = Color(0xFFF5F7F8);
  static const Color _lightSurface = Colors.white;
  static const Color _lightText = Color(0xFF101010);

  static ThemeData get darkGreen {
    final base = ThemeData.dark();

    final textTheme = GoogleFonts.poppinsTextTheme(base.textTheme).apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    );

    return base.copyWith(
      scaffoldBackgroundColor: _background,
      canvasColor: _background,
      colorScheme: base.colorScheme.copyWith(
        primary: _primaryGreen,
        secondary: _accentGreen,
        surface: _surface,
        background: _background,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: Colors.white,
        onBackground: Colors.white,
        brightness: Brightness.dark,
      ),
      textTheme: textTheme,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: _primaryGreen,
          fontWeight: FontWeight.w600,
        ),
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryGreen,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primaryGreen,
          textStyle: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: _surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primaryGreen, width: 2),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: Colors.white70),
        hintStyle: textTheme.bodyMedium?.copyWith(color: Colors.white38),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _surface,
        contentTextStyle: textTheme.bodyMedium,
        behavior: SnackBarBehavior.floating,
      ),
      cardColor: _surface,
      dividerColor: Colors.white12,
    );
  }

  static ThemeData get lightGreen {
    final base = ThemeData.light();

    final textTheme = GoogleFonts.poppinsTextTheme(base.textTheme).apply(
      bodyColor: _lightText,
      displayColor: _lightText,
    );

    return base.copyWith(
      scaffoldBackgroundColor: _lightBackground,
      canvasColor: _lightBackground,
      colorScheme: base.colorScheme.copyWith(
        primary: _accentGreen,
        secondary: _primaryGreen,
        surface: _lightSurface,
        background: _lightBackground,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: _lightText,
        onBackground: _lightText,
        brightness: Brightness.light,
      ),
      textTheme: textTheme,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: _accentGreen,
          fontWeight: FontWeight.w600,
        ),
        foregroundColor: _lightText,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _accentGreen,
          textStyle: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: _lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _accentGreen, width: 2),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: Colors.black54),
        hintStyle: textTheme.bodyMedium?.copyWith(color: Colors.black38),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _lightSurface,
        contentTextStyle: textTheme.bodyMedium,
        behavior: SnackBarBehavior.floating,
      ),
      cardColor: _lightSurface,
      dividerColor: Colors.black12,
    );
  }
}
