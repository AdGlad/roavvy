import 'package:design_forge/design_forge.dart';

import 'studio_controller.dart';

/// The editor state behind a saved design — everything the customer chose that
/// the artwork alone does not carry.
///
/// A [DesignRecipe] is a complete, deterministic description of a *picture*: it
/// reproduces the print pixel for pixel, forever. It says nothing about the
/// session that produced it. Which Direction the customer was on, which Detail
/// within it, which countries and which years they had narrowed to, how the
/// front of the shirt was configured — all of that lives in the
/// [StudioController], and none of it survives a save.
///
/// Without it, reopening a saved design puts the right artwork into the *wrong*
/// session: the shirt looks correct until the first edit that regenerates
/// (changing Direction, or a country) — at which point the Studio rebuilds from
/// whatever state it happened to be holding and the saved design is gone. This
/// is the missing half, persisted alongside the recipes.
///
/// Deliberately plain data with no engine types in its JSON: enums travel by
/// `name`, so a value this build does not recognise is dropped back to its
/// default rather than crashing the restore ([_enumByName]).
class StudioSession {
  const StudioSession({
    this.subjectIndex = 0,
    this.detail = StudioDetail.grid,
    this.detailFamily,
    this.selectedCountryCodes = const [],
    this.sourceTrips = false,
    this.yearLo = 0,
    this.yearHi = 0,
    this.frontFit = FrontFit.chest,
    this.chestRight = false,
    this.frontArt = FrontArt.ribbon,
    this.ribbonAllCountries = false,
    this.version = currentVersion,
  });

  /// Bumped when a field is added that older readers must not misread. Fields
  /// so far are purely additive, so version 1 records restore correctly here.
  static const currentVersion = 1;

  /// The Direction (index into [StudioController.subjects]).
  final int subjectIndex;

  /// The Detail chosen under the Flags Direction.
  final StudioDetail detail;

  /// The Detail chosen under a family-based Direction, if any.
  final DesignFamily? detailFamily;

  /// The countries on the shirt, lowercase, in selection order.
  final List<String> selectedCountryCodes;

  /// Travels source: trips (one per visit) rather than countries.
  final bool sourceTrips;

  final int yearLo;
  final int yearHi;

  /// Front Design configuration (M21). Print state beside the back design.
  final FrontFit frontFit;
  final bool chestRight;
  final FrontArt frontArt;
  final bool ribbonAllCountries;

  final int version;

  Map<String, Object?> toJson() => {
        'v': version,
        'subject': subjectIndex,
        'detail': detail.name,
        if (detailFamily != null) 'detailFamily': detailFamily!.name,
        'countries': selectedCountryCodes,
        'sourceTrips': sourceTrips,
        'yearLo': yearLo,
        'yearHi': yearHi,
        'frontFit': frontFit.name,
        'chestRight': chestRight,
        'frontArt': frontArt.name,
        'ribbonAll': ribbonAllCountries,
      };

  /// Reads a persisted session. Every field is optional and every unknown value
  /// falls back to the default — a session written by a different build must
  /// degrade to "open it as it is", never to a failed or invented restore.
  factory StudioSession.fromJson(Map<String, Object?> j) => StudioSession(
        subjectIndex: (j['subject'] as num?)?.toInt() ?? 0,
        detail: _enumByName(StudioDetail.values, j['detail']) ??
            StudioDetail.grid,
        detailFamily: _enumByName(DesignFamily.values, j['detailFamily']),
        selectedCountryCodes: [
          for (final c in (j['countries'] as List? ?? const []))
            if (c is String) c.toLowerCase(),
        ],
        sourceTrips: j['sourceTrips'] == true,
        yearLo: (j['yearLo'] as num?)?.toInt() ?? 0,
        yearHi: (j['yearHi'] as num?)?.toInt() ?? 0,
        frontFit: _enumByName(FrontFit.values, j['frontFit']) ?? FrontFit.chest,
        chestRight: j['chestRight'] == true,
        frontArt: _enumByName(FrontArt.values, j['frontArt']) ?? FrontArt.ribbon,
        ribbonAllCountries: j['ribbonAll'] == true,
        version: (j['v'] as num?)?.toInt() ?? 1,
      );

  static T? _enumByName<T extends Enum>(List<T> values, Object? name) {
    if (name is! String) return null;
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }
}
