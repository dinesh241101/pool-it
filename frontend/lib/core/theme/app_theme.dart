import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF43A047);
  static const Color primaryDark = Color(0xFF2E7D32);
  static const Color secondaryColor = Color(0xFF1E88E5);
  static const Color accentColor = Color(0xFFFF8F00);
  static const Color errorColor = Color(0xFFE53935);
  static const Color backgroundColor = Color(0xFFF0F2F5);
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color successColor = Color(0xFF43A047);
  static const Color warningColor = Color(0xFFFF8F00);

  static List<Color> primaryGradient = [
    primaryColor,
    primaryDark,
  ];

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    primarySwatch: Colors.green,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundColor,
    cardTheme: const CardThemeData(
      color: cardColor,
      elevation: 0,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        elevation: 0,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: const TextStyle(color: textSecondary),
    ),
    dividerTheme: const DividerThemeData(
      space: 0,
      thickness: 1,
      color: Color(0xFFE5E7EB),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: primaryColor,
      unselectedItemColor: textSecondary,
    ),
  );
}
