import 'package:flutter/material.dart';

/// Roavvy brand seed colour (deep navy).
const _seed = Color(0xFF001F3F);

/// Light theme — clean whites with navy/gold accents.
ThemeData get roavvyLightTheme => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: Brightness.light,
  ),
);

/// Dark theme — deep navy surfaces, gold accents, readable on OLED.
ThemeData get roavvyDarkTheme => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: Brightness.dark,
    // Override key surface colours for a deep navy feel.
    surface: const Color(0xFF0D1B2A),
    onSurface: const Color(0xFFE8EDF2),
    surfaceContainerHighest: const Color(0xFF1A2B3C),
    surfaceContainerLow: const Color(0xFF0A1520),
    primary: const Color(0xFF5BA4F5),
    onPrimary: const Color(0xFF001F3F),
    secondary: const Color(0xFFF2C94C),
    onSecondary: const Color(0xFF001F3F),
    tertiary: const Color(0xFF2ED8B6),
    onTertiary: const Color(0xFF001F3F),
    error: const Color(0xFFFF6B6B),
  ),
);
