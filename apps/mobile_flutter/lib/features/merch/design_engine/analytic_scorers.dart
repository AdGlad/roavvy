import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:shared_models/shared_models.dart';

import '../../cards/flag_grid_layout_engine.dart';
import '../merch_preset.dart';
import '../merch_template_ranker.dart';
import 'design_engine_contracts.dart';
import 'design_params.dart';
import 'printability.dart';
import 'travel_profile.dart';

/// M198 — the analytic ("tier 1") scorers (§6.2). Each encodes one graphic-design
/// heuristic over the layout GEOMETRY + genome + profile. All are pure,
/// isolate-safe, and ignore the [thumbnail] param (that's the pixel tier), so
/// they can rank 100+ candidates before any raster.

// ── Coverage / balance ───────────────────────────────────────────────────────

/// Rewards an even fill with a centre-of-mass near the canvas centre — the
/// designer's "balanced composition". Measured from the real flag-grid tiles;
/// non-grid templates are assumed centred/balanced by their template logic.
class CoverageBalanceScorer implements DesignScorer {
  const CoverageBalanceScorer({this.weight = 1.0});

  @override
  final double weight;

  @override
  String get name => 'CoverageBalance';

  @override
  double score(
    DesignParams params,
    TravelProfile profile, {
    Uint8List? thumbnail,
  }) {
    if (params.template != CardTemplateType.grid) return 0.7;
    final canvas = printCanvasFor(params.imageSize);
    final tiles = printGridTiles(params);
    if (tiles.isEmpty) return 0.0;

    // Area-weighted centroid.
    var ax = 0.0, ay = 0.0, area = 0.0;
    for (final t in tiles) {
      final a = t.rect.width * t.rect.height;
      ax += t.rect.center.dx * a;
      ay += t.rect.center.dy * a;
      area += a;
    }
    if (area <= 0) return 0.0;
    final centroid = Offset(ax / area, ay / area);
    final centre = Offset(canvas.width / 2, canvas.height / 2);
    final offset =
        (centroid.dx - centre.dx).abs() / canvas.width +
        (centroid.dy - centre.dy).abs() / canvas.height;
    final centreScore = (1.0 - offset * 2.0).clamp(0.0, 1.0);

    // Size evenness (low coefficient of variation of tile areas → even fill).
    final mean = area / tiles.length;
    var varSum = 0.0;
    for (final t in tiles) {
      final a = t.rect.width * t.rect.height;
      varSum += (a - mean) * (a - mean);
    }
    final cv = mean > 0 ? math.sqrt(varSum / tiles.length) / mean : 1.0;
    final evenScore = (1.0 - cv).clamp(0.0, 1.0);

    return (0.6 * centreScore + 0.4 * evenScore).clamp(0.0, 1.0);
  }
}

// ── Whitespace / breathing room ──────────────────────────────────────────────

/// Penalises BOTH cramped and sparse designs — a healthy band peaks around
/// [idealCoverage]. Uses the analytic ink-coverage estimate.
class WhitespaceScorer implements DesignScorer {
  const WhitespaceScorer({
    this.weight = 0.8,
    this.idealCoverage = 0.55,
    this.tolerance = 0.5,
  });

  @override
  final double weight;
  final double idealCoverage;
  final double tolerance;

  @override
  String get name => 'Whitespace';

  @override
  double score(
    DesignParams params,
    TravelProfile profile, {
    Uint8List? thumbnail,
  }) {
    final cov = estimateInkCoverage(params);
    final dev = (cov - idealCoverage).abs();
    return (1.0 - dev / tolerance).clamp(0.0, 1.0);
  }
}

// ── Focal hierarchy ──────────────────────────────────────────────────────────

/// Rewards a clear dominant element (a single outline / hero flag) and
/// penalises uniform "mush" (a dense, undifferentiated grid of many equal
/// flags). A designer's figure/ground.
class FocalHierarchyScorer implements DesignScorer {
  const FocalHierarchyScorer({this.weight = 1.0});

  @override
  final double weight;

  @override
  String get name => 'FocalHierarchy';

  @override
  double score(
    DesignParams params,
    TravelProfile profile, {
    Uint8List? thumbnail,
  }) {
    final n = params.countryCodes.length;

    // A single-country silhouette/outline clip is the strongest possible focal.
    const singleClips = {
      GridClipShape.countryOutline,
      GridClipShape.animalSilhouette,
      GridClipShape.plantSilhouette,
      GridClipShape.landmarkSilhouette,
    };
    if (singleClips.contains(params.clipShape)) return 0.95;
    if (params.clipShape == GridClipShape.heart ||
        params.clipShape == GridClipShape.circle) {
      return 0.75; // a contained shape still reads as one object
    }
    if (n == 1) return 0.80;

    switch (params.template) {
      case CardTemplateType.typography:
      case CardTemplateType.landmark:
      case CardTemplateType.wordCloud:
        return 0.62; // frequency/size sizing gives some hierarchy
      case CardTemplateType.grid:
        final base = n <= 6 ? 0.58 : (n <= 15 ? 0.44 : 0.32);
        // Montage's scale variation breaks up the uniformity a little.
        return params.gridLayoutMode == FlagGridLayoutMode.montage
            ? (base + 0.06).clamp(0.0, 1.0)
            : base;
      case CardTemplateType.passport:
        return 0.50;
      case CardTemplateType.timeline:
        return 0.55; // headline entry reads first
      case CardTemplateType.journeys:
        return 0.60; // origin→destination route gives directional hierarchy
      case CardTemplateType.heart:
      case CardTemplateType.frontRibbon:
      case CardTemplateType.badge:
        return 0.55;
    }
  }
}

// ── Aspect fit ───────────────────────────────────────────────────────────────

/// Penalises orientation mismatch / letterboxing — a naturally tall subject
/// (country outline, stacked type) forced landscape wastes the print area, and
/// vice-versa. Pure heuristic: we can't load the outline asset in an isolate, so
/// each clip/template has an expected orientation (see grid_clip_shape_orientation
/// for the rendered-asset version M191 uses at draw time).
class AspectFitScorer implements DesignScorer {
  const AspectFitScorer({this.weight = 0.6});

  @override
  final double weight;

  @override
  String get name => 'AspectFit';

  /// Expected portrait-ness, or null when either orientation reads fine.
  static bool? _expectPortrait(DesignParams params) {
    switch (params.clipShape) {
      case GridClipShape.countryOutline:
      case GridClipShape.animalSilhouette:
      case GridClipShape.plantSilhouette:
        return true; // most countries / animals are taller than wide
      case GridClipShape.landmarkSilhouette:
      case GridClipShape.continentOutline:
        return false; // landmarks / continents read wide
      case GridClipShape.heart:
      case GridClipShape.circle:
      case GridClipShape.none:
        break;
    }
    return switch (params.template) {
      CardTemplateType.typography => true,
      CardTemplateType.passport => true,
      CardTemplateType.timeline => false,
      CardTemplateType.wordCloud => false,
      CardTemplateType.landmark => false,
      CardTemplateType.grid => null,
      CardTemplateType.journeys => null, // serpentine route adapts to either
      CardTemplateType.heart => null,
      CardTemplateType.frontRibbon => false,
      CardTemplateType.badge => null,
    };
  }

  @override
  double score(
    DesignParams params,
    TravelProfile profile, {
    Uint8List? thumbnail,
  }) {
    final expect = _expectPortrait(params);
    if (expect == null) return 0.80; // either orientation is fine
    return params.isPortrait == expect ? 1.0 : 0.45;
  }
}

// ── Profile fit ──────────────────────────────────────────────────────────────

/// How well the design matches the traveller: template affinity from
/// [MerchTemplateRanker] priority for the profile, plus country-set relevance to
/// the persona. Feeds [DesignScore.profileFit].
class ProfileFitScorer implements DesignScorer {
  const ProfileFitScorer({this.weight = 1.2});

  @override
  final double weight;

  @override
  String get name => 'ProfileFit';

  @override
  double score(
    DesignParams params,
    TravelProfile profile, {
    Uint8List? thumbnail,
  }) {
    // Template affinity from the ranker (priority 1 == best; exclude == worst).
    final ranks = MerchTemplateRanker.rankFor(codeCount: profile.countryCount);
    MerchTemplateRank? rank;
    for (final r in ranks) {
      if (r.template == params.template) {
        rank = r;
        break;
      }
    }
    final double templateScore;
    if (rank == null || rank.exclude) {
      templateScore = 0.1;
    } else {
      templateScore = (1.0 - (rank.priority - 1) / 8.0).clamp(0.1, 1.0);
    }

    final sourceBonus = _sourceAffinity(profile.persona, params.source);
    return (0.7 * templateScore + 0.3 * sourceBonus).clamp(0.0, 1.0);
  }

  /// Persona → country-source affinity (0..1). A globe-trotter loves the
  /// all-time map; a recent adventurer loves this-year / recent-trip; a deep
  /// diver loves a single country.
  static double _sourceAffinity(
    TravelPersona persona,
    MerchCountrySource source,
  ) {
    switch (persona) {
      case TravelPersona.soloDeepDive:
        return source == MerchCountrySource.singleCountry
            ? 1.0
            : (source == MerchCountrySource.recentTrip ? 0.7 : 0.4);
      case TravelPersona.recentAdventurer:
        return switch (source) {
          MerchCountrySource.recentTrip => 1.0,
          MerchCountrySource.thisYear => 0.9,
          MerchCountrySource.allTime => 0.5,
          MerchCountrySource.singleCountry => 0.6,
        };
      case TravelPersona.continentHopper:
      case TravelPersona.globeTrotter:
        return switch (source) {
          MerchCountrySource.allTime => 1.0,
          MerchCountrySource.thisYear => 0.6,
          MerchCountrySource.recentTrip => 0.4,
          MerchCountrySource.singleCountry => 0.3,
        };
      case TravelPersona.regionExplorer:
        return switch (source) {
          MerchCountrySource.allTime => 0.9,
          MerchCountrySource.thisYear => 0.6,
          MerchCountrySource.recentTrip => 0.5,
          MerchCountrySource.singleCountry => 0.5,
        };
      case TravelPersona.homebodyPlusOne:
        return switch (source) {
          MerchCountrySource.recentTrip => 0.9,
          MerchCountrySource.singleCountry => 0.8,
          MerchCountrySource.thisYear => 0.7,
          MerchCountrySource.allTime => 0.7,
        };
    }
  }
}

/// The default analytic aesthetic scorers (excluding [ProfileFitScorer], which
/// feeds [DesignScore.profileFit] separately).
const List<DesignScorer> kDefaultAnalyticScorers = [
  CoverageBalanceScorer(),
  WhitespaceScorer(),
  FocalHierarchyScorer(),
  AspectFitScorer(),
];

/// The default profile-fit scorer (kept separate so it maps onto
/// [DesignScore.profileFit]).
const DesignScorer kDefaultProfileScorer = ProfileFitScorer();
