import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_models/shared_models.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum StampShape { circular, rectangular, oval, doubleRing }

enum StampColor {
  blue(Color(0xFF1A3A6B)),
  red(Color(0xFF8B1A1A)),
  purple(Color(0xFF4A1A6B)),
  green(Color(0xFF1A5C2A)),
  black(Color(0xFF1A1A1A));

  const StampColor(this.color);
  final Color color;
}

// ── StampData ─────────────────────────────────────────────────────────────────

/// Rendering artefact for a single passport stamp.
///
/// Not a domain model — no Firestore serialisation. Derived transiently at
/// paint time from [TripRecord] data or country codes (ADR-096).
@immutable
class StampData {
  const StampData({
    required this.countryCode,
    required this.countryName,
    required this.shape,
    required this.color,
    required this.rotation,
    required this.center,
    required this.scale,
    this.dateLabel,
    this.entryLabel = 'ENTRY',
  });

  final String countryCode;
  final String countryName;
  final StampShape shape;
  final StampColor color;

  /// Rotation in radians. Range: roughly ±0.21 rad (±12°).
  final double rotation;

  /// Position of the stamp centre within the canvas, in logical pixels.
  final Offset center;

  /// Scale factor (default 1.0). Used by layout engine for size variety.
  final double scale;

  /// Formatted date string, e.g. "12 JAN 2023". Null when no trip data.
  final String? dateLabel;

  /// "ENTRY" or "EXIT".
  final String entryLabel;

  static String _formatDate(DateTime dt) =>
      DateFormat('dd MMM yyyy').format(dt).toUpperCase();

  /// Create a [StampData] from a [TripRecord].
  ///
  /// [isEntry] determines whether the label is "ENTRY" or "EXIT".
  factory StampData.fromTrip(
    TripRecord trip, {
    required StampShape shape,
    required StampColor color,
    required double rotation,
    required Offset center,
    required bool isEntry,
    double scale = 1.0,
    String countryName = '',
  }) {
    return StampData(
      countryCode: trip.countryCode,
      countryName: countryName,
      shape: shape,
      color: color,
      rotation: rotation,
      center: center,
      scale: scale,
      dateLabel: _formatDate(trip.startedOn),
      entryLabel: isEntry ? 'ENTRY' : 'EXIT',
    );
  }

  /// Create a [StampData] from a bare country code (no trip data).
  factory StampData.fromCode(
    String code, {
    required StampShape shape,
    required StampColor color,
    required double rotation,
    required Offset center,
    double scale = 1.0,
    String countryName = '',
  }) {
    return StampData(
      countryCode: code,
      countryName: countryName,
      shape: shape,
      color: color,
      rotation: rotation,
      center: center,
      scale: scale,
      dateLabel: null,
      entryLabel: 'ENTRY',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StampData &&
          countryCode == other.countryCode &&
          shape == other.shape &&
          color == other.color &&
          rotation == other.rotation &&
          center == other.center &&
          scale == other.scale &&
          dateLabel == other.dateLabel &&
          entryLabel == other.entryLabel;

  @override
  int get hashCode => Object.hash(
        countryCode,
        shape,
        color,
        rotation,
        center,
        scale,
        dateLabel,
        entryLabel,
      );
}
