import 'package:flutter/material.dart';

/// App Theme with Pastel Colors
/// Minimalist design with soft, calming colors

class AppTheme {
  // Airbnb-style Color Palette
  static const Color primaryColor = Color(0xFFFF385C); // Airbnb Red/Pink
  static const Color secondaryColor = Color(0xFF008489); // Teal (Secondary)
  static const Color backgroundColor = Color(0xFFFFFFFF); // Pure White
  static const Color surfaceColor = Color(0xFFFFFFFF); // White
  static const Color scaffoldColor = Color(0xFFFFFFFF); // White

  // Text Colors
  static const Color textColor = Color(0xFF222222); // Deep Black
  static const Color subtitleColor = Color(0xFF717171); // Grey

  // Status Colors
  static const Color successColor = Color(0xFF008A05); // Green
  static const Color warningColor = Color(0xFFFAAD14); // Amber
  static const Color errorColor = Color(0xFFD93025); // Red
  static const Color softGrey = Color(0xFFE0E0E0); // Soft Grey for Empty States
  static const Color secondaryTextColor = Color(0xFF717171);

  static final BoxDecoration cardDecoration = BoxDecoration(
    color: surfaceColor,
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: Colors.grey.withOpacity(0.1)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: scaffoldColor,
      primaryColor: primaryColor,

      // Color Scheme
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        background: backgroundColor,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textColor,
        onBackground: textColor,
        onError: Colors.white,
        outline: Color(0xFFDDDDDD),
      ),

      // Typography (Simulating Circular/Inter)
      fontFamily:
          'Roboto', // Default fall-back, assume system font is good enough
      textTheme: const TextTheme(
        // Headings
        displayLarge: TextStyle(
          color: textColor,
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          color: textColor,
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        displaySmall: TextStyle(
          color: textColor,
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),

        // Titles
        headlineMedium: TextStyle(
          color: textColor,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: textColor,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: textColor,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),

        // Body
        bodyLarge: TextStyle(
          color: textColor,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: TextStyle(
          color: subtitleColor,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: TextStyle(
          color: subtitleColor,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),

      // AppBar Theme (Clean White)
      appBarTheme: const AppBarTheme(
        backgroundColor: scaffoldColor,
        foregroundColor: textColor,
        elevation: 0,
        centerTitle: false, // Left aligned like Airbnb
        titleTextStyle: TextStyle(
          color: textColor,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: textColor),
      ),

      // Card Theme (Subtle Border, No Shadow or very soft)
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFDDDDDD), width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8),
      ),

      // Input Decoration (Rounded, Grey Outline)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            30,
          ), // Pill shape for inputs preferred or rounded rect
          borderSide: const BorderSide(color: Color(0xFFB0B0B0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30), // Pill/Rounded
          borderSide: const BorderSide(color: Color(0xFFB0B0B0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(
            color: textColor,
            width: 2,
          ), // Black when focused
        ),
        labelStyle: const TextStyle(color: subtitleColor),
      ),

      // Button Theme (Pill shaped, Bold)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor, // Airbnb Red
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100), // Pill shape
          ),
        ),
      ),

      // Text Button (Simple link style)
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textColor,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
          ),
        ),
      ),

      // Floating Action Button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
      ),

      // Bottom Navigation Bar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryColor,
        unselectedItemColor: Color(0xFFB0B0B0),
        selectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        showUnselectedLabels: true,
      ),

      dividerTheme: const DividerThemeData(
        color: Color(0xFFEEEEEE),
        thickness: 1,
      ),
    );
  }
}
