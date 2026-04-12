import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/country_names.dart';
import 'passport_stamp_model.dart';

/// Result returned by [PassportLayoutEngine.layout].
class PassportLayoutResult {
  const PassportLayoutResult({
    required this.stamps,
    required this.wasForced,
  });

  /// The placed stamps for this layout.
  final List<StampData> stamps;

  /// `true` when [PassportLayoutEngine.layout] was called with `forPrint=true`
  /// and forced `entryOnly=true` because the adaptive baseRadius would have
  /// dropped below 8 px (ADR-102 / ADR-113).
  final bool wasForced;
}

/// A single entry in the ordered stamp list built before layout.
class _StampEntry {
  const _StampEntry({
    required this.trip,
    required this.code,
    required this.isEntry,
  });

  /// The trip this stamp belongs to, or `null` for bare-code stamps.
  final TripRecord? trip;
  final String code;
  final bool isEntry;
}

/// Deterministic stamp placement engine for the passport card template.
///
/// Produces a stable [PassportLayoutResult] for any given set of trips/codes
/// and canvas size. Same user → same layout across all devices and sessions.
/// (ADR-097 / ADR-113)
class PassportLayoutEngine {
  const PassportLayoutEngine._();

  // Maximum stamps rendered per card. Raised from 20 to accommodate one entry
  // stamp and one exit stamp per trip (ADR-113).
  static const int _kMaxStamps = 200;


  // ── Safe Zones (ADR-117 Decision 1) ───────────────────────────────────────
  // Title safe zone: Top 18% of height.
  // Branding safe zone: Bottom-left 110x40 logical pixels.
  static const double _kTitleSafeZoneHeightFraction = 0.18;
  static const double _kBrandingSafeZoneWidth = 110.0;
  static const double _kBrandingSafeZoneHeight = 40.0;

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

  /// Build the ordered stamp entry list from sorted trips and bare codes.
  ///
  /// When [entryOnly] is false, each trip produces two entries: entry
  /// (date = startedOn) then exit (date = endedOn). When true, only the
  /// entry stamp is produced. Bare [extraCodes] always produce a single entry.
  static List<_StampEntry> _buildEntries(
    List<TripRecord> sortedTrips,
    List<String> extraCodes,
    bool entryOnly,
  ) {
    final entries = <_StampEntry>[];
    for (final trip in sortedTrips) {
      entries.add(_StampEntry(trip: trip, code: trip.countryCode, isEntry: true));
      if (!entryOnly) {
        entries.add(_StampEntry(trip: trip, code: trip.countryCode, isEntry: false));
      }
    }
    for (final code in extraCodes) {
      entries.add(_StampEntry(trip: null, code: code, isEntry: true));
    }
    return entries;
  }

  /// Lay out stamps for [trips] and any bare [countryCodes] that have no trip.
  ///
  /// Produces one entry stamp **and** one exit stamp per [TripRecord] when
  /// [entryOnly] is false (ADR-113). Exit stamps use [TripRecord.endedOn] as
  /// their date. Stamp radius scales down automatically as count grows so all
  /// stamps remain individually visible even at 100+ counts.
  ///
  /// [seed] defaults to a hash of [countryCodes] so the layout is stable per
  /// user while still allowing callers to vary it.
  ///
  /// When [forPrint] is `true` the layout applies a 3% safe-zone margin (vs
  /// the default 8%), disables all edge clipping, and uses a uniform adaptive
  /// base radius (ADR-102). If the computed radius would drop below 8 px and
  /// [entryOnly] was not already set, [entryOnly] is forced and
  /// [PassportLayoutResult.wasForced] will be `true`.
  static PassportLayoutResult layout({
    required List<TripRecord> trips,
    required List<String> countryCodes,
    required Size canvasSize,
    int? seed,
    bool entryOnly = false,
    bool forPrint = false,
  }) {
    if (countryCodes.isEmpty) {
      return const PassportLayoutResult(stamps: [], wasForced: false);
    }

    final effectiveSeed = seed ?? countryCodes.join().hashCode;
    final rng = math.Random(effectiveSeed);

    final tripCodes = trips.map((t) => t.countryCode).toSet();
    final extraCodes =
        countryCodes.where((c) => !tripCodes.contains(c)).toList();

    final sortedTrips = List<TripRecord>.from(trips)
      ..sort((a, b) => a.startedOn.compareTo(b.startedOn));

    // Build entry list and compute total count.
    var entries = _buildEntries(sortedTrips, extraCodes, entryOnly);
    int totalCount = math.min(entries.length, _kMaxStamps);

    // ── Print-safe mode setup (ADR-102) ──────────────────────────────────────
    final marginFraction = forPrint ? 0.03 : 0.08;
    final marginX = canvasSize.width * marginFraction;
    final marginY = canvasSize.height * marginFraction;
    final usableW = canvasSize.width - marginX * 2;
    final usableH = canvasSize.height - marginY * 2;

    // Dynamic base radius: full size (56 px) for ≤ 20 stamps, scales down
    // smoothly as count grows — 56 × √(min(1, 20/n)) — clamped to [6, 56].
    // Raised from 38 → 56 so stamps fill the available space when count is low.
    final dynamicRadius = totalCount > 0
        ? (56.0 * math.sqrt(math.min(1.0, 20.0 / totalCount))).clamp(6.0, 56.0)
        : 56.0;

    // Determine forPrint base radius and check wasForced (ADR-102 / ADR-113).
    double? forPrintBaseRadius;
    bool wasForced = false;
    if (forPrint && totalCount > 0) {
      forPrintBaseRadius = dynamicRadius;
      if (dynamicRadius < 8.0 && !entryOnly) {
        wasForced = true;
        entryOnly = true;
        // Rebuild entries with forced entryOnly so count is halved.
        entries = _buildEntries(sortedTrips, extraCodes, true);
        totalCount = math.min(entries.length, _kMaxStamps);
        // Recompute radius for the reduced count.
        forPrintBaseRadius = totalCount > 0
            ? (56.0 * math.sqrt(math.min(1.0, 20.0 / totalCount)))
                .clamp(6.0, 56.0)
            : 56.0;
      }
    }

    // Grid: size to fit all stamps exactly (ceil so every stamp gets a cell).
    // Sequential assignment (not weighted-random) guarantees even coverage with
    // no large gaps. Jitter within each cell keeps the layout organic.
    final canvasAspect = usableW / math.max(1.0, usableH);
    final gridCols =
        math.max(2, math.sqrt(totalCount.toDouble() * canvasAspect).ceil());
    final gridRows =
        math.max(2, (totalCount / gridCols).ceil());

    final stamps = <StampData>[];
    final placedCentres = <Offset>[];
    final placedRadii = <double>[];

    for (var stampIdx = 0; stampIdx < totalCount; stampIdx++) {
      final entry = entries[stampIdx];

      final style = _styleForCode(entry.code);
      final inkFamilyIndex = StampInkPalette.familyIndexForCode(entry.code);
      final ageEffect = StampAgeEffect.fromWeightedRandom(rng.nextDouble());

      // ADR-097: ±20° rotation
      final rotation = (rng.nextDouble() * 2 - 1) * (20 * math.pi / 180);

      // In print mode use uniform adaptive radius; otherwise ±10% variety.
      final double scale;
      final double baseRadius;
      if (forPrint && forPrintBaseRadius != null) {
        baseRadius = forPrintBaseRadius;
        scale = baseRadius / 38.0;
      } else {
        final variety = 0.9 + rng.nextDouble() * 0.2;
        baseRadius = (dynamicRadius * variety).clamp(6.0, 38.0);
        scale = baseRadius / 38.0;
      }

      // Sequential grid assignment: each stamp gets its own cell, guaranteeing
      // even coverage with no large gaps. Jitter within ±40% of cell dims keeps
      // the layout organic. Safe zones are enforced via clamping.
      final cellW = usableW / gridCols;
      // Usable height starts below the title safe zone.
      final safeStartY =
          math.max(marginY, canvasSize.height * _kTitleSafeZoneHeightFraction);
      final availableH = (canvasSize.height - marginY) - safeStartY;
      final cellH = math.max(1.0, availableH / gridRows);
      final cellCol = stampIdx % gridCols;
      final cellRow = stampIdx ~/ gridCols;

      // Jitter ±40% of cell half-dimensions for a natural, scattered look.
      final jitterX = (rng.nextDouble() - 0.5) * cellW * 0.8;
      final jitterY = (rng.nextDouble() - 0.5) * cellH * 0.8;

      final rawCentre = Offset(
        marginX + (cellCol + 0.5) * cellW + jitterX,
        safeStartY + (cellRow + 0.5) * cellH + jitterY,
      );

      // Clamp to keep stamps inside usable area and clear of safe zones.
      Offset? centre = Offset(
        rawCentre.dx.clamp(marginX + baseRadius, canvasSize.width - marginX - baseRadius),
        rawCentre.dy.clamp(safeStartY + baseRadius, canvasSize.height - marginY - baseRadius),
      );

      // If clamped into a safe zone, nudge towards usable centre.
      if (_isInSafeZone(centre, baseRadius, canvasSize)) {
        centre = Offset(centre.dx, safeStartY + availableH * 0.5);
      }

      // 8% chance of edge clipping in normal mode; disabled in print (ADR-102).
      Rect? edgeClip;
      if (!forPrint && rng.nextDouble() < 0.08) {
        edgeClip = _edgeClipRect(centre, baseRadius, canvasSize, rng);
      }

      final StampData stamp;
      if (entry.trip != null) {
        final trip = entry.trip!;
        stamp = StampData.fromTrip(
          trip,
          stampDate: entry.isEntry ? trip.startedOn : trip.endedOn,
          style: style,
          inkFamilyIndex: inkFamilyIndex,
          ageEffect: ageEffect,
          rotation: rotation,
          center: centre,
          scale: scale,
          isEntry: entry.isEntry,
          countryName: kCountryNames[trip.countryCode] ?? trip.countryCode,
          edgeClip: edgeClip,
        );
      } else {
        stamp = StampData.fromCode(
          entry.code,
          style: style,
          inkFamilyIndex: inkFamilyIndex,
          ageEffect: ageEffect,
          rotation: rotation,
          center: centre,
          scale: scale,
          countryName: kCountryNames[entry.code] ?? entry.code,
          edgeClip: edgeClip,
        );
      }

      stamps.add(stamp);
      placedCentres.add(centre);
      placedRadii.add(baseRadius);
    }

    return PassportLayoutResult(stamps: stamps, wasForced: wasForced);
  }

  /// Returns `true` if any part of a stamp with [radius] at [center] would
  /// overlap the top (title) or bottom-left (branding) safe zones.
  static bool _isInSafeZone(Offset center, double radius, Size canvasSize) {
    // 1. Title Safe Zone (Top 18%)
    if (center.dy - radius < canvasSize.height * _kTitleSafeZoneHeightFraction) {
      return true;
    }

    // 2. Branding Safe Zone (Bottom-Left 110x40)
    // We add a small buffer (4px) to ensure no visual tangent.
    if (center.dx - radius < _kBrandingSafeZoneWidth + 4 &&
        center.dy + radius > canvasSize.height - _kBrandingSafeZoneHeight - 4) {
      return true;
    }

    return false;
  }

  /// Create an edge-clip rect that cuts 10–25% of the stamp's bounding box
  /// from the nearest page edge.
  static Rect? _edgeClipRect(
    Offset centre,
    double radius,
    Size pageSize,
    math.Random rng,
  ) {
    final dLeft = centre.dx;
    final dRight = pageSize.width - centre.dx;
    final dTop = centre.dy;
    final dBottom = pageSize.height - centre.dy;
    final minD = [dLeft, dRight, dTop, dBottom].reduce(math.min);

    final cropFraction = 0.10 + rng.nextDouble() * 0.15;
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
