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
  static const double _kTitleSafeZoneHeightFraction = 0.09;
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
  ///
  /// All entry stamps are placed before all exit stamps. This puts each group
  /// in a separate half of the grid so paired stamps for the same country land
  /// far apart rather than in adjacent cells.
  ///
  /// Trips are deduplicated by (countryCode, startDate) before processing.
  /// The photo scanner can produce multiple TripRecords for the same country
  /// on the same day (e.g. Geneva and Zurich both mapping to CH on the same
  /// transit day). Without deduplication, entry+exit mode doubles the stamp
  /// count for each duplicate, flooding the card with redundant same-date
  /// stamps. The earliest trip per (code, date) is kept.
  static List<_StampEntry> _buildEntries(
    List<TripRecord> sortedTrips,
    List<String> extraCodes,
    bool entryOnly,
  ) {
    // Deduplicate: keep one trip per (countryCode, calendar date).
    final seen = <String>{};
    final deduped = <TripRecord>[];
    for (final trip in sortedTrips) {
      final d = trip.startedOn;
      final key = '${trip.countryCode}:${d.year}-${d.month}-${d.day}';
      if (seen.add(key)) deduped.add(trip);
    }

    // Interleave entry and exit stamps per trip so they are evenly distributed
    // across the stamp list. The caller shuffles the final list, so the order
    // here only matters for keeping entry/exit of the same trip close in the
    // source list (which randomisation naturally spreads apart).
    final result = <_StampEntry>[];
    for (final trip in deduped) {
      result.add(_StampEntry(trip: trip, code: trip.countryCode, isEntry: true));
      if (!entryOnly) {
        result.add(_StampEntry(trip: trip, code: trip.countryCode, isEntry: false));
      }
    }
    for (final code in extraCodes) {
      result.add(_StampEntry(trip: null, code: code, isEntry: true));
    }
    return result;
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
    double sizeMultiplier = 1.0,
    double jitterFactor = 0.4,
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

    // Build entry list, then shuffle with the seeded RNG so stamps are
    // distributed randomly across the grid (no entry-top / exit-bottom bias).
    var entries = _buildEntries(sortedTrips, extraCodes, entryOnly)
      ..shuffle(rng);
    int totalCount = math.min(entries.length, _kMaxStamps);

    // ── Print-safe mode setup (ADR-102) ──────────────────────────────────────
    final marginFraction = forPrint ? 0.03 : 0.08;
    final marginX = canvasSize.width * marginFraction;
    final marginY = canvasSize.height * marginFraction;
    final usableW = canvasSize.width - marginX * 2;
    final usableH = canvasSize.height - marginY * 2;

    // Dynamic base radius: scales continuously with stamp count — 45 × √(20/n)
    // — clamped to [6, 100]. Coefficient reduced from 56 to 45 (≈ 20% smaller)
    // so stamps are less crowded and overlap less. (M86 fix)
    //
    //   n=2  → 45×√10 ≈ 142 → 100 px (ceiling)
    //   n=5  → 45×√4  =  90 →  90 px
    //   n=10 → 45×√2  ≈  64 px
    //   n=20 → 45×√1  =  45 px
    //   n=40 → 45×√0.5 ≈ 32 px
    final dynamicRadius = totalCount > 0
        ? (45.0 * math.sqrt(20.0 / totalCount)).clamp(6.0, 100.0)
        : 100.0;

    // Determine forPrint base radius and check wasForced (ADR-102 / ADR-113).
    double? forPrintBaseRadius;
    bool wasForced = false;
    if (forPrint && totalCount > 0) {
      forPrintBaseRadius = dynamicRadius;
      if (dynamicRadius < 8.0 && !entryOnly) {
        wasForced = true;
        entryOnly = true;
        // Rebuild entries with forced entryOnly so count is halved.
        entries = _buildEntries(sortedTrips, extraCodes, true)
          ..shuffle(rng);
        totalCount = math.min(entries.length, _kMaxStamps);
        // Recompute radius for the reduced count.
        forPrintBaseRadius = totalCount > 0
            ? (56.0 * math.sqrt(20.0 / totalCount)).clamp(6.0, 100.0)
            : 100.0;
      }
    }

    // Stamp-available area: below the title safe zone, above the bottom margin.
    final safeStartY =
        math.max(marginY, canvasSize.height * _kTitleSafeZoneHeightFraction);
    final availableH = (canvasSize.height - marginY) - safeStartY;

    // Grid: size to fit all stamps exactly (ceil so every stamp gets a cell).
    // Sequential assignment (not weighted-random) guarantees even coverage with
    // no large gaps. Jitter within each cell keeps the layout organic.
    //
    // Compute gridRows first using the actual stamp-area aspect ratio (which
    // excludes the title safe zone). On portrait canvases this produces more
    // rows than columns, distributing stamps across the full portrait height
    // rather than clustering them in a few wide rows near the centre.
    //
    // Grid floor is 1 (not 2) so that very small counts (1–3 stamps) get a
    // single-column or single-row grid that spans the full canvas height rather
    // than clustering all stamps in one quadrant of a forced 2×2 grid.
    final stampAreaAspect = usableW / math.max(1.0, availableH);
    final gridRows =
        math.max(1, math.sqrt(totalCount.toDouble() / stampAreaAspect).ceil());
    final gridCols =
        math.max(1, (totalCount / gridRows).ceil());

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
        baseRadius = (dynamicRadius * variety * sizeMultiplier).clamp(4.0, 60.0);
        scale = baseRadius / 38.0;
      }

      // Sequential grid assignment: each stamp gets its own cell, guaranteeing
      // even coverage with no large gaps. Jitter within ±30% of cell dims keeps
      // the layout organic while limiting excessive overlap.
      final cellW = usableW / gridCols;
      final cellH = math.max(1.0, availableH / gridRows);
      final cellCol = stampIdx % gridCols;
      final cellRow = stampIdx ~/ gridCols;

      // Jitter ±30% of cell dimensions for a natural, scattered look. Stamps
      // are 25% smaller than before so the extra spread no longer causes
      // excessive overlap.
      final jitterX = (rng.nextDouble() - 0.5) * cellW * jitterFactor;
      final jitterY = (rng.nextDouble() - 0.5) * cellH * jitterFactor;

      final rawCentre = Offset(
        marginX + (cellCol + 0.5) * cellW + jitterX,
        safeStartY + (cellRow + 0.5) * cellH + jitterY,
      );

      // Stamps render at targetW = baseRadius * 2.1, so they extend
      // baseRadius * 1.05 from their centre. Use this half-width for clamping
      // so stamps fit fully inside the portrait boundary.
      final halfStampW = baseRadius * 1.05;
      // Clamp to keep stamps inside usable area and clear of safe zones.
      Offset? centre = Offset(
        rawCentre.dx.clamp(marginX + halfStampW, canvasSize.width - marginX - halfStampW),
        rawCentre.dy.clamp(safeStartY + halfStampW, canvasSize.height - marginY - halfStampW),
      );

      // If clamped into a safe zone, nudge towards usable centre.
      if (_isInSafeZone(centre, halfStampW, canvasSize)) {
        centre = Offset(centre.dx, safeStartY + availableH * 0.5);
      }

      // 8% chance of edge clipping in normal mode; disabled in print (ADR-102).
      Rect? edgeClip;
      if (!forPrint && rng.nextDouble() < 0.08) {
        edgeClip = _edgeClipRect(centre, halfStampW, canvasSize, rng);
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
