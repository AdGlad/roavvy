import 'inferred_country_visit.dart';

/// Stats and results produced by a single scan run.
///
/// [ScanSummary] is the complete output of one call to the Swift PhotoKit
/// bridge. It is produced at the app layer (not stored in shared_models) and
/// converted to [InferredCountryVisit] records before being merged into the
/// persistent store.
///
/// The distinction between [assetsWithLocation] and [geocodeAttempts] matters:
/// coordinate bucketing at 0.5° deduplicate nearby GPS points before geocoding,
/// so [geocodeAttempts] ≤ [assetsWithLocation]. In the current spike, the Swift
/// bridge does not track buckets separately — set both to the same value until
/// the bridge is extended.
class ScanSummary {
  const ScanSummary({
    required this.scannedAt,
    required this.assetsInspected,
    required this.assetsWithLocation,
    required this.geocodeAttempts,
    required this.geocodeSuccesses,
    required this.countries,
  }) : assert(geocodeAttempts <= assetsWithLocation,
            'geocodeAttempts cannot exceed assetsWithLocation');

  /// UTC timestamp when the scan started.
  final DateTime scannedAt;

  /// Total photo assets examined by the scan pipeline.
  final int assetsInspected;

  /// Assets that carried GPS metadata.
  final int assetsWithLocation;

  /// Unique coordinate buckets submitted to the geocoder after deduplication.
  /// ≤ [assetsWithLocation]. Equal to [assetsWithLocation] in the current spike
  /// because the bridge does not yet report this separately.
  final int geocodeAttempts;

  /// Coordinate buckets successfully resolved to a country code.
  final int geocodeSuccesses;

  /// One entry per country detected in this scan run.
  final List<InferredCountryVisit> countries;

  int get assetsWithoutLocation => assetsInspected - assetsWithLocation;
  int get geocodeFailures => geocodeAttempts - geocodeSuccesses;
  int get countryCount => countries.length;
}
