/// Maps app-facing placement strings to validated Printful API placement values.
///
/// The app uses human-readable placement identifiers (`center`, `left_chest`,
/// `right_chest`, `none`). Printful's API expects different string values that
/// must be sent exactly as defined in its product spec.
///
/// Decision (ADR-147): placement validation is centralised here so
/// [LocalMockupPreviewScreen] never sends an unmapped or silently-wrong value.
/// `none` maps to the same Printful placement as `center` — the caller is
/// responsible for omitting the artwork file when position is `none` (Printful
/// then returns a blank-shirt mockup rather than no mockup at all).
class PrintfulPlacementMapper {
  PrintfulPlacementMapper._();

  // ── Front placement ────────────────────────────────────────────────────────

  static const _kFrontMap = <String, String>{
    'center':      'front',
    'left_chest':  'front_left',
    'right_chest': 'front_right',
    // 'none' → blank shirt: use 'front' placement but send no artwork file.
    'none':        'front',
  };

  // ── Back placement ─────────────────────────────────────────────────────────

  static const _kBackMap = <String, String>{
    'center': 'back',
    // 'none' → blank back: use 'back' placement but send no artwork file.
    'none':   'back',
  };

  /// Maps an app front-placement string to the Printful API value.
  ///
  /// Throws [ArgumentError] if [position] is not a known front placement.
  static String mapFront(String position) {
    final mapped = _kFrontMap[position];
    if (mapped == null) {
      throw ArgumentError.value(
        position,
        'position',
        'Unknown front placement — expected one of: ${_kFrontMap.keys.join(', ')}',
      );
    }
    return mapped;
  }

  /// Maps an app back-placement string to the Printful API value.
  ///
  /// Throws [ArgumentError] if [position] is not a known back placement.
  static String mapBack(String position) {
    final mapped = _kBackMap[position];
    if (mapped == null) {
      throw ArgumentError.value(
        position,
        'position',
        'Unknown back placement — expected one of: ${_kBackMap.keys.join(', ')}',
      );
    }
    return mapped;
  }

  /// Returns `true` when [position] should send an artwork file to Printful.
  ///
  /// `none` skips the file upload (blank shirt/back); all other positions send
  /// artwork.
  static bool sendsArtwork(String position) => position != 'none';
}
