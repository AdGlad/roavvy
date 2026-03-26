import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/country_names.dart';
import 'passport_stamp_model.dart';

/// Deterministic stamp placement engine for the passport card template.
///
/// Produces a stable [List<StampData>] for any given set of trips/codes and
/// canvas size. Same user → same layout across all devices and sessions.
/// (ADR-097)
class PassportLayoutEngine {
  const PassportLayoutEngine._();

  static const int _kMaxStamps = 20;
  static const int _kMaxAttempts = 8;

  /// Grid cells for soft-grid clustering (3 columns × 4 rows = 12 cells).
  static const int _kGridCols = 3;
  static const int _kGridRows = 4;

  // ── Category-balanced style pools (ADR-097 Decision 12) ───────────────────
  // Each code maps deterministically to a category (25% each), then to a style
  // within that category. This prevents too many circles appearing together.

  static const _circleStyles = [
    StampStyle.airportEntry,
    StampStyle.airportExit,
    StampStyle.vintage,
    StampStyle.dottedCircle,
    StampStyle.multiRing,
  ];
  static const _rectStyles = [
    StampStyle.landBorder,
    StampStyle.visaApproval,
    StampStyle.modernSans,
    StampStyle.blockText,
  ];
  static const _polyStyles = [
    StampStyle.triangle,
    StampStyle.hexBadge,
    StampStyle.octagon,
    StampStyle.diamond,
  ];
  static const _otherStyles = [
    StampStyle.transit,
    StampStyle.oval,
  ];

  /// Derives a stamp style from [code] using category-balanced selection.
  ///
  /// catKey maps code chars → 0–19, dividing into 4 equal 25% buckets:
  /// 0–4 circles, 5–9 rectangles, 10–14 polygons, 15–19 other.
  static StampStyle _styleForCode(String code) {
    if (code.isEmpty) return StampStyle.airportEntry;
    final c0 = code.codeUnitAt(0);
    final c1 = code.length > 1 ? code.codeUnitAt(1) : 0;
    final catKey = (c0 * 13 + c1 * 7) % 20;
    final hash = code.hashCode.abs();
    if (catKey < 5) return _circleStyles[hash % _circleStyles.length];
    if (catKey < 10) return _rectStyles[hash % _rectStyles.length];
    if (catKey < 15) return _polyStyles[hash % _polyStyles.length];
    return _otherStyles[hash % _otherStyles.length];
  }

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

    final totalCount =
        math.min(sortedTrips.length + extraCodes.length, _kMaxStamps);

    final stamps = <StampData>[];
    final placedCentres = <Offset>[];
    final placedRadii = <double>[];

    final marginX = canvasSize.width * 0.08;
    final marginY = canvasSize.height * 0.08;
    final usableW = canvasSize.width - marginX * 2;
    final usableH = canvasSize.height - marginY * 2;

    // Soft-grid cell occupancy tracking
    final cellOccupancy = List<int>.filled(_kGridCols * _kGridRows, 0);

    var tripIdx = 0;
    var codeIdx = 0;
    var stampIdx = 0;

    while (stampIdx < totalCount) {
      final isTripStamp = tripIdx < sortedTrips.length;
      final code = isTripStamp
          ? sortedTrips[tripIdx].countryCode
          : extraCodes[codeIdx];

      // Derive style from country code only — entry and exit of the same
      // country always get the same stamp shape and colour (only the
      // ENTRY/EXIT label text differs). Category-balanced to ensure variety.
      final style = _styleForCode(code);
      final inkFamilyIndex = StampInkPalette.familyIndexForCode(code);
      final ageEffect =
          StampAgeEffect.fromWeightedRandom(rng.nextDouble());

      // ADR-097: ±20° rotation (was ±12°)
      final rotation = (rng.nextDouble() * 2 - 1) * (20 * math.pi / 180);
      final scale = 0.85 + rng.nextDouble() * 0.3; // 0.85 – 1.15
      final baseRadius = 38.0 * scale;

      // Find a non-occluded placement using soft-grid weighting
      Offset? centre;
      for (var attempt = 0; attempt < _kMaxAttempts; attempt++) {
        final candidateCell = _weightedCell(cellOccupancy, rng);
        final cellW = usableW / _kGridCols;
        final cellH = usableH / _kGridRows;
        final cellCol = candidateCell % _kGridCols;
        final cellRow = candidateCell ~/ _kGridCols;
        final candidate = Offset(
          marginX + cellCol * cellW + rng.nextDouble() * cellW,
          marginY + cellRow * cellH + rng.nextDouble() * cellH,
        );
        if (_acceptable(candidate, baseRadius, placedCentres, placedRadii)) {
          centre = candidate;
          cellOccupancy[candidateCell]++;
          break;
        }
      }
      // Accept best-effort on failure
      centre ??= Offset(
        marginX + rng.nextDouble() * usableW,
        marginY + rng.nextDouble() * usableH,
      );

      // 8% chance of edge clipping (partial stamp at page boundary)
      Rect? edgeClip;
      if (rng.nextDouble() < 0.08) {
        edgeClip = _edgeClipRect(centre, baseRadius, canvasSize, rng);
      }

      final StampData stamp;
      if (isTripStamp) {
        final trip = sortedTrips[tripIdx];
        stamp = StampData.fromTrip(
          trip,
          style: style,
          inkFamilyIndex: inkFamilyIndex,
          ageEffect: ageEffect,
          rotation: rotation,
          center: centre,
          scale: scale,
          isEntry: stampIdx % 2 == 0,
          countryName: kCountryNames[trip.countryCode] ?? trip.countryCode,
          edgeClip: edgeClip,
        );
        tripIdx++;
      } else {
        stamp = StampData.fromCode(
          code,
          style: style,
          inkFamilyIndex: inkFamilyIndex,
          ageEffect: ageEffect,
          rotation: rotation,
          center: centre,
          scale: scale,
          countryName: kCountryNames[code] ?? code,
          edgeClip: edgeClip,
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

  /// Soft-grid cell selection: probability ∝ 1/(1+occupancy).
  static int _weightedCell(List<int> occupancy, math.Random rng) {
    // Compute unnormalised weights
    final weights =
        occupancy.map((o) => 1.0 / (1.0 + o)).toList();
    final total = weights.fold(0.0, (a, b) => a + b);
    final pick = rng.nextDouble() * total;
    var cumulative = 0.0;
    for (var i = 0; i < weights.length; i++) {
      cumulative += weights[i];
      if (pick <= cumulative) return i;
    }
    return occupancy.length - 1;
  }

  /// Create an edge-clip rect that cuts 10–25% of the stamp's bounding box
  /// from the nearest page edge.
  static Rect? _edgeClipRect(
    Offset centre,
    double radius,
    Size pageSize,
    math.Random rng,
  ) {
    // Find the nearest edge
    final dLeft = centre.dx;
    final dRight = pageSize.width - centre.dx;
    final dTop = centre.dy;
    final dBottom = pageSize.height - centre.dy;
    final minD = [dLeft, dRight, dTop, dBottom].reduce(math.min);

    final cropFraction = 0.10 + rng.nextDouble() * 0.15; // 10–25%
    final cropAmount = radius * 2 * cropFraction;

    if (minD == dLeft) {
      return Rect.fromLTWH(
          centre.dx - radius + cropAmount, 0, pageSize.width, pageSize.height);
    } else if (minD == dRight) {
      return Rect.fromLTWH(
          0, 0, centre.dx + radius - cropAmount, pageSize.height);
    } else if (minD == dTop) {
      return Rect.fromLTWH(
          0, centre.dy - radius + cropAmount, pageSize.width, pageSize.height);
    } else {
      return Rect.fromLTWH(
          0, 0, pageSize.width, centre.dy + radius - cropAmount);
    }
  }
}
