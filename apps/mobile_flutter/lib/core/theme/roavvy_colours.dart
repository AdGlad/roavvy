import 'package:flutter/material.dart';

abstract final class RoavvyColours {
  // Primary brand palette
  static const Color roavvyBlue = Color(0xFF2F80ED);
  static const Color roavvyGold = Color(0xFFF2C94C);
  static const Color roavvyCoral = Color(0xFFFF6B6B);
  static const Color roavvyMint = Color(0xFF2ED8B6);

  // Map colours
  static const Color mapUnvisited = Color(0xFFD1D5DB);
  static const Color mapVisited1 = Color(0xFF74C69D);
  static const Color mapVisited2to4 = Color(0xFF2D6A4F);
  static const Color mapVisited5plus = Color(0xFF1B4332);

  // Backgrounds
  static const Color backgroundWarm = Color(0xFFF8F6F0);
  static const Color backgroundDark = Color(0xFF1A1A2E);
  static const Color surfaceCard = Color(0xFFFFFFFF);

  // Overlay / glass
  static const Color glassLight = Color(0x80FFFFFF);
  static const Color glassDark = Color(0x99000000);

  // Continent colours — shared across stats screens
  static const Map<String, Color> continentColors = {
    'Africa': Color(0xFFFF8C42),
    'Asia': Color(0xFFE74C3C),
    'Europe': Color(0xFF3498DB),
    'North America': Color(0xFF27AE60),
    'South America': Color(0xFF8E44AD),
    'Oceania': Color(0xFF16A085),
  };

  // Continent emoji — shared across stats screens
  static const Map<String, String> continentEmoji = {
    'Africa': '🌍',
    'Asia': '🌏',
    'Europe': '🏰',
    'North America': '🌲',
    'South America': '🌿',
    'Oceania': '🌊',
  };
}
