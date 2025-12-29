import 'package:flutter/material.dart';

/// App Theme with Pastel Colors
/// Minimalist design with soft, calming colors

class AppTheme {
  // Pastel Color Palette
  static const Color backgroundColor = Color(0xFFF5F5F0); // Off-white / light beige
  static const Color primaryColor = Color(0xFFA8C5A3); // Muted teal / sage green
  static const Color accentColor = Color(0xFFB8D4F0); // Pastel blue
  static const Color textColor = Color(0xFF4A4A4A); // Dark grey
  static const Color cardColor = Color(0xFFFFFFFF); // White for cards
  static const Color successColor = Color(0xFFB8D4B8); // Pastel green
  static const Color warningColor = Color(0xFFFFE5B4); // Pastel orange/yellow
  static const Color errorColor = Color(0xFFFFCCCC); // Pastel red

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: accentColor,
        surface: cardColor,
        background: backgroundColor,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: textColor,
        onSurface: textColor,
        onBackground: textColor,
        onError: textColor,
      ),
      scaffoldBackgroundColor: backgroundColor,
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: textColor, fontSize: 32, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(color: textColor, fontSize: 28, fontWeight: FontWeight.bold),
        displaySmall: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: textColor, fontSize: 16),
        bodyMedium: TextStyle(color: textColor, fontSize: 14),
        bodySmall: TextStyle(color: textColor, fontSize: 12),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryColor.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryColor.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 2,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cardColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: textColor.withOpacity(0.6),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}

