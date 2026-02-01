import 'dart:io';
import 'package:flutter/material.dart';

/// Application theme configuration
///
/// Provides consistent theming across Android, Windows, and other platforms.
/// Includes both light and dark themes with platform-specific adjustments.
class AppTheme {
  // Primary seed color for Material Design 3 dynamic color scheme
  static const Color _seedColor = Colors.blue;

  /// Light theme
  static ThemeData get lightTheme {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,

      // Card styling (platform-aware)
      cardTheme: CardThemeData(
        elevation: Platform.isWindows ? 0 : 1, // Fluent uses flat cards
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // App bar styling
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
      ),

      // Floating action button styling
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 4,
      ),

      // Dialog styling (platform-aware)
      dialogTheme: DialogThemeData(
        elevation: Platform.isWindows ? 2 : 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Platform.isWindows ? 4 : 28),
        ),
      ),

      // Button styling
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: Platform.isWindows ? 1 : 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // Input decoration styling
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
      ),

      // Chip styling (for filter chips in results screen)
      chipTheme: ChipThemeData(
        elevation: Platform.isWindows ? 0 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  /// Dark theme
  static ThemeData get darkTheme {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,

      // Card styling (platform-aware)
      cardTheme: CardThemeData(
        elevation: Platform.isWindows ? 0 : 1,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // App bar styling
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
      ),

      // Floating action button styling
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 4,
      ),

      // Dialog styling (platform-aware)
      dialogTheme: DialogThemeData(
        elevation: Platform.isWindows ? 2 : 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Platform.isWindows ? 4 : 28),
        ),
      ),

      // Button styling
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: Platform.isWindows ? 1 : 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // Input decoration styling
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
      ),

      // Chip styling
      chipTheme: ChipThemeData(
        elevation: Platform.isWindows ? 0 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
