/// A photo selected from the device library for a travel anniversary pulse (M114).
///
/// Unlike [HeroImage], this model is sourced directly from photo_manager rather
/// than from the hero-image selection pipeline, so scene/mood/landmark metadata
/// is unavailable. Country and trip are resolved from Drift where possible.
class MemoryAnniversaryPhoto {
  const MemoryAnniversaryPhoto({
    required this.assetId,
    required this.capturedAt,
    this.countryCode,
    this.tripId,
  });

  /// photo_manager local identifier — used to load the thumbnail and full image.
  final String assetId;

  /// Original capture date of the photo.
  final DateTime capturedAt;

  /// ISO country code resolved from Drift photo_date_records, or null if not scanned.
  final String? countryCode;

  /// Trip ID resolved from Drift hero_images (rank-1 row), or null if no match.
  final String? tripId;

  /// Years between capturedAt and today.
  int yearsAgo(DateTime today) => today.year - capturedAt.year;
}
