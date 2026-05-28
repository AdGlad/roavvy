import 'dart:math' as math;

import 'package:flutter/material.dart';

// ── Distance & bearing ─────────────────────────────────────────────────────

/// Great-circle distance between two lat/lng points in kilometres (Haversine).
double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = _rad(lat2 - lat1);
  final dLng = _rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// Initial bearing in degrees (0 = N, 90 = E, 180 = S, 270 = W) from
/// [fromLat]/[fromLng] to [toLat]/[toLng].
double bearingDeg(double fromLat, double fromLng, double toLat, double toLng) {
  final dLng = _rad(toLng - fromLng);
  final lat1 = _rad(fromLat);
  final lat2 = _rad(toLat);
  final y = math.sin(dLng) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
  return (_deg(math.atan2(y, x)) + 360) % 360;
}

/// Maps [bearing] (0–360°) to a lowercase cardinal direction string.
///
/// Returns one of: north, north-east, east, south-east,
///                 south, south-west, west, north-west.
String cardinalDirection(double bearing) {
  const dirs = [
    'north',
    'north-east',
    'east',
    'south-east',
    'south',
    'south-west',
    'west',
    'north-west',
  ];
  return dirs[((bearing + 22.5) / 45).floor() % 8];
}

// ── Hot/cold rating ────────────────────────────────────────────────────────

/// Temperature label and display colour for a given [km] distance to target.
///
/// Thresholds (inclusive upper bound):
///   <= 250 km  → On fire   🔴
///   <= 1000 km → Hot       🟠
///   <= 3000 km → Warm      🟡
///   <= 7000 km → Cold      🔵
///   > 7000 km  → Freezing  ❄️
({String label, String emoji, Color color}) hotColdRating(double km) {
  if (km <= 250) {
    return (label: 'On fire', emoji: '🔥', color: const Color(0xFFD32F2F));
  }
  if (km <= 1000) {
    return (label: 'Hot', emoji: '♨️', color: const Color(0xFFFF6F00));
  }
  if (km <= 3000) {
    return (label: 'Warm', emoji: '🌡', color: const Color(0xFFF9A825));
  }
  if (km <= 7000) {
    return (label: 'Cold', emoji: '🌨', color: const Color(0xFF1976D2));
  }
  return (label: 'Freezing', emoji: '❄️', color: const Color(0xFF0288D1));
}

// ── Private helpers ─────────────────────────────────────────────────────────

double _rad(double deg) => deg * math.pi / 180;
double _deg(double rad) => rad * 180 / math.pi;
