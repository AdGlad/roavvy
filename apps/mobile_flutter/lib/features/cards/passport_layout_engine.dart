import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/country_names.dart';
import 'passport_stamp_model.dart';

/// Deterministic stamp placement engine for the passport card template.
///
/// Produces a stable [List<StampData>] for any given set of trips/codes and
/// canvas size. Same user → same layout across all devices and sessions.
/// (ADR-096)
class PassportLayoutEngine {
  const PassportLayoutEngine._();

  static const int _kMaxStamps = 20;
  static const int _kMaxAttempts = 8;

  /// Lay out stamps for [trips] and any bare [countryCodes] that have no trip.
  ///
  /// [seed] defaults to a hash of [countryCodes] so the layout is stable per
  /// user while still allowing callers to vary it (e.g. a shuffle button).
  static List<StampData> layout({
    required List<TripRecord> trips,
    required List<String> countryCodes,
    required Size canvasSize,
    int? seed,
  }) {
    if (countryCodes.isEmpty) return const [];

    final effectiveSeed = seed ?? countryCodes.join().hashCode;
    final rng = math.Random(effectiveSeed);

    // Build ordered input list: trips sorted by startedOn, then trip-less codes
    final tripCodes = trips.map((t) => t.countryCode).toSet();
    final extraCodes =
        countryCodes.where((c) => !tripCodes.contains(c)).toList();

    final sortedTrips = List<TripRecord>.from(trips)
      ..sort((a, b) => a.startedOn.compareTo(b.startedOn));

    // Unified index list: trip index (≥0) or bare code index (negated offset)
    // We iterate them in order to produce deterministic shape/color cycling.
    final totalCount =
        math.min(sortedTrips.length + extraCodes.length, _kMaxStamps);

    final stamps = <StampData>[];
    final placedCentres = <Offset>[];
    final placedRadii = <double>[];

    final marginX = canvasSize.width * 0.08;
    final marginY = canvasSize.height * 0.08;
    final usableW = canvasSize.width - marginX * 2;
    final usableH = canvasSize.height - marginY * 2;

    var tripIdx = 0;
    var codeIdx = 0;
    var stampIdx = 0;

    while (stampIdx < totalCount) {
      final isTripStamp = tripIdx < sortedTrips.length;
      final StampData stamp;

      final shape = StampShape.values[stampIdx % StampShape.values.length];
      final color = _colorFromCode(
        isTripStamp ? sortedTrips[tripIdx].countryCode : extraCodes[codeIdx],
      );
      final rotation = (rng.nextDouble() * 2 - 1) * (12 * math.pi / 180);
      final scale = 0.85 + rng.nextDouble() * 0.3; // 0.85 – 1.15
      final baseRadius = 38.0 * scale;

      // Find a non-occluded placement
      Offset? centre;
      for (var attempt = 0; attempt < _kMaxAttempts; attempt++) {
        final candidate = Offset(
          marginX + rng.nextDouble() * usableW,
          marginY + rng.nextDouble() * usableH,
        );
        if (_acceptable(candidate, baseRadius, placedCentres, placedRadii)) {
          centre = candidate;
          break;
        }
      }
      // Accept best-effort on failure (place at random, no collision check)
      centre ??= Offset(
        marginX + rng.nextDouble() * usableW,
        marginY + rng.nextDouble() * usableH,
      );

      if (isTripStamp) {
        final trip = sortedTrips[tripIdx];
        stamp = StampData.fromTrip(
          trip,
          shape: shape,
          color: color,
          rotation: rotation,
          center: centre,
          scale: scale,
          isEntry: stampIdx % 2 == 0,
          countryName: kCountryNames[trip.countryCode] ?? trip.countryCode,
        );
        tripIdx++;
      } else {
        final code = extraCodes[codeIdx];
        stamp = StampData.fromCode(
          code,
          shape: shape,
          color: color,
          rotation: rotation,
          center: centre,
          scale: scale,
          countryName: kCountryNames[code] ?? code,
        );
        codeIdx++;
      }

      stamps.add(stamp);
      placedCentres.add(centre);
      placedRadii.add(baseRadius);
      stampIdx++;
    }

    return stamps;
  }

  /// Reject placement if the centre is within 80% of any existing stamp radius.
  static bool _acceptable(
    Offset candidate,
    double radius,
    List<Offset> centres,
    List<double> radii,
  ) {
    for (var i = 0; i < centres.length; i++) {
      final dist = (candidate - centres[i]).distance;
      final minDist = (radius + radii[i]) * 0.8;
      if (dist < minDist) return false;
    }
    return true;
  }

  /// Deterministic color from country code hash.
  static StampColor _colorFromCode(String code) {
    if (code.length < 2) return StampColor.blue;
    final hash = code.codeUnitAt(0) * 31 + code.codeUnitAt(1);
    return StampColor.values[hash % StampColor.values.length];
  }
}
