import 'effective_visited_country.dart';
import 'inferred_country_visit.dart';
import 'user_added_country.dart';
import 'user_removed_country.dart';

/// Computes the effective visited-country set from the three input collections.
///
/// ## Precedence rules
///
/// 1. **Removals are absolute.** A [UserRemovedCountry] suppresses both any
///    [InferredCountryVisit] and any [UserAddedCountry] for the same code —
///    including records produced by future scans. Only an explicit user action
///    (a new [UserAddedCountry] recorded after the removal) can lift the
///    suppression.
///
/// 2. **User additions are honoured unconditionally.** A [UserAddedCountry]
///    not suppressed by a removal will always appear in the effective set,
///    even when no photo evidence exists.
///
/// 3. **Multiple inferred records for the same country are merged.** Across
///    scan runs, [InferredCountryVisit.firstSeen] takes the earliest value,
///    [InferredCountryVisit.lastSeen] takes the latest, and
///    [InferredCountryVisit.photoCount] is summed.
///
/// 4. **User addition + inferred for the same code are combined.** The
///    resulting [EffectiveVisitedCountry] carries photo evidence from the
///    inferred side; the user addition contributes no extra metadata.
///
/// ## Output
///
/// An unordered list of [EffectiveVisitedCountry] — at most one entry per
/// country code. Sorting (alphabetical, by count, etc.) is the caller's
/// responsibility.
List<EffectiveVisitedCountry> effectiveVisitedCountries({
  required List<InferredCountryVisit> inferred,
  required List<UserAddedCountry> added,
  required List<UserRemovedCountry> removed,
}) {
  // Step 1 — build removal set. O(r).
  final removedCodes = {for (final r in removed) r.countryCode};

  // Step 2 — merge all inferred records by country code. O(i).
  final inferredByCode = <String, _MergedInferred>{};
  for (final v in inferred) {
    if (removedCodes.contains(v.countryCode)) continue;
    final existing = inferredByCode[v.countryCode];
    if (existing == null) {
      inferredByCode[v.countryCode] = _MergedInferred.fromSingle(v);
    } else {
      inferredByCode[v.countryCode] = existing.mergeWith(v);
    }
  }

  // Step 3 — build the effective set. Start with all inferred countries.
  final result = <String, EffectiveVisitedCountry>{
    for (final e in inferredByCode.entries)
      e.key: EffectiveVisitedCountry(
        countryCode: e.key,
        hasPhotoEvidence: true,
        firstSeen: e.value.firstSeen,
        lastSeen: e.value.lastSeen,
        photoCount: e.value.photoCount,
      ),
  };

  // Step 4 — apply user additions. O(a).
  for (final a in added) {
    if (removedCodes.contains(a.countryCode)) continue;
    if (!result.containsKey(a.countryCode)) {
      // No inferred evidence — manually added only.
      result[a.countryCode] = EffectiveVisitedCountry(
        countryCode: a.countryCode,
        hasPhotoEvidence: false,
      );
      // If there IS inferred evidence, the existing entry already covers it;
      // the user addition adds no new metadata, so we leave it unchanged.
    }
  }

  return result.values.toList();
}

/// Internal accumulator for merging multiple [InferredCountryVisit] records
/// for the same country code across scan runs.
class _MergedInferred {
  _MergedInferred({
    required this.firstSeen,
    required this.lastSeen,
    required this.photoCount,
  });

  factory _MergedInferred.fromSingle(InferredCountryVisit v) => _MergedInferred(
        firstSeen: v.firstSeen,
        lastSeen: v.lastSeen,
        photoCount: v.photoCount,
      );

  DateTime? firstSeen;
  DateTime? lastSeen;
  int photoCount;

  _MergedInferred mergeWith(InferredCountryVisit v) {
    final fs = firstSeen;
    final ls = lastSeen;
    final vfs = v.firstSeen;
    final vls = v.lastSeen;
    return _MergedInferred(
      firstSeen: fs == null
          ? vfs
          : (vfs == null ? fs : (vfs.isBefore(fs) ? vfs : fs)),
      lastSeen: ls == null
          ? vls
          : (vls == null ? ls : (vls.isAfter(ls) ? vls : ls)),
      photoCount: photoCount + v.photoCount,
    );
  }
}
