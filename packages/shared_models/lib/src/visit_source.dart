/// Whether a [CountryVisit] was detected automatically or added by the user.
enum VisitSource {
  /// Inferred from photo GPS metadata via the scan pipeline.
  auto,

  /// Explicitly added or edited by the user.
  /// Manual records are never overwritten by automatic detection.
  manual,
}
