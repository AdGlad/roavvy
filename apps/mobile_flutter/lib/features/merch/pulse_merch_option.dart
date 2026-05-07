import 'package:shared_models/shared_models.dart';

/// The scope that determines which countries and trips are included.
enum PulseMerchScope {
  /// Stamps for the specific trip that generated the pulse.
  pulseTrip,

  /// All countries visited in the pulse photo's calendar year.
  pulseYear,

  /// All visits to the pulse photo's country, across all time.
  allVisitsToCountry,

  /// Every visited country, all time.
  allTime,
}

/// A single pre-scoped merch idea derived from a Memory Pulse.
///
/// [codes] and [trips] are already resolved for the given [scope] so that
/// both the front and back artwork are always generated from the same set of
/// data — fixing the bug where the back used all countries while the front
/// was scoped to one.
class PulseMerchOption {
  const PulseMerchOption({
    required this.id,
    required this.title,
    required this.description,
    required this.scope,
    required this.template,
    required this.codes,
    required this.trips,
    this.entryOnly = false,
    this.jitter = 0.4,
    this.stampSizeMultiplier = 1.0,
  });

  final String id;
  final String title;
  final String description;
  final PulseMerchScope scope;
  final CardTemplateType template;

  /// Country codes used to generate artwork. Same set for front and back.
  final List<String> codes;

  /// Trips used for stamp generation. Scoped to match [codes].
  final List<TripRecord> trips;

  final bool entryOnly;
  final double jitter;
  final double stampSizeMultiplier;

  /// Human-readable label shown in the template chip.
  String get templateLabel => switch (template) {
        CardTemplateType.passport => 'Passport stamps',
        CardTemplateType.grid => 'Flag grid',
        CardTemplateType.heart => 'Heart flags',
        CardTemplateType.timeline => 'Timeline',
        CardTemplateType.frontRibbon => 'Ribbon',
      };
}
