// lib/features/world_leap/domain/models/world_leap_failure_reason.dart

/// The reason a World Leap run ended in failure.
enum WorldLeapFailureReason {
  /// Roavvy landed in water / ocean.
  water,

  /// Roavvy landed in a country already visited during this run.
  repeatCountry,

  /// Roavvy landed back in the country they launched from.
  sameCountry,

  /// Landing coordinates could not be resolved to a valid country.
  invalidDestination,

  /// Roavvy landed in a country that was not the target.
  wrongCountry,

  /// The player ran out of time before launching.
  timeout,
}

extension WorldLeapFailureReasonX on WorldLeapFailureReason {
  String get displayName {
    switch (this) {
      case WorldLeapFailureReason.water:
        return 'Landed in the ocean!';
      case WorldLeapFailureReason.repeatCountry:
        return 'Already visited that country';
      case WorldLeapFailureReason.sameCountry:
        return 'Still in the same country!';
      case WorldLeapFailureReason.invalidDestination:
        return 'Invalid destination';
      case WorldLeapFailureReason.wrongCountry:
        return 'Missed the target!';
      case WorldLeapFailureReason.timeout:
        return 'Ran out of time!';
    }
  }

  String toJson() => name;

  static WorldLeapFailureReason fromJson(String value) =>
      WorldLeapFailureReason.values.firstWhere((e) => e.name == value);
}
