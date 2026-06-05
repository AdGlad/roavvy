import 'package:shared_models/shared_models.dart';

/// Context required to evaluate exclusive design lock/unlock status.
///
/// Evaluated entirely on the client from existing Riverpod providers
/// (ADR-176 — no server-side access control needed for aspirational designs).
class MerchUnlockContext {
  const MerchUnlockContext({
    required this.countryCount,
    required this.continentCount,
  });

  final int countryCount;
  final int continentCount;
}

// ── Unlock conditions ─────────────────────────────────────────────────────────

/// What a user needs to reach to unlock an exclusive design.
sealed class MerchUnlockCondition {
  const MerchUnlockCondition();

  bool isSatisfied(MerchUnlockContext ctx);

  /// Countries/continents still needed, or 0 if already satisfied.
  int remaining(MerchUnlockContext ctx);
}

class CountryCountCondition extends MerchUnlockCondition {
  const CountryCountCondition(this.target);

  final int target;

  @override
  bool isSatisfied(MerchUnlockContext ctx) => ctx.countryCount >= target;

  @override
  int remaining(MerchUnlockContext ctx) =>
      (target - ctx.countryCount).clamp(0, target);
}

class ContinentCountCondition extends MerchUnlockCondition {
  const ContinentCountCondition(this.target);

  final int target;

  @override
  bool isSatisfied(MerchUnlockContext ctx) => ctx.continentCount >= target;

  @override
  int remaining(MerchUnlockContext ctx) =>
      (target - ctx.continentCount).clamp(0, target);
}

// ── Exclusive design model ───────────────────────────────────────────────────

/// A shirt design that is locked behind a milestone achievement.
///
/// Designs are aspirational motivators — not paid gated content — so lock
/// status is evaluated client-side (ADR-176).
class MerchExclusiveDesign {
  const MerchExclusiveDesign({
    required this.id,
    required this.label,
    required this.description,
    required this.unlockCondition,
    required this.template,
    required this.emoji,
  });

  final String id;

  /// Short display name, e.g. "Half the World".
  final String label;

  /// Unlock requirement sentence, e.g. "Visit 50 countries".
  final String description;

  final MerchUnlockCondition unlockCondition;

  /// Card template used when generating the design.
  final CardTemplateType template;

  /// Shown on the locked/unlocked badge.
  final String emoji;

  bool isUnlocked(MerchUnlockContext ctx) => unlockCondition.isSatisfied(ctx);

  /// Remaining units (countries or continents) to unlock, or 0 if unlocked.
  int remaining(MerchUnlockContext ctx) => unlockCondition.remaining(ctx);
}

// ── Catalogue ─────────────────────────────────────────────────────────────────

const kMerchExclusiveDesigns = [
  MerchExclusiveDesign(
    id: 'world_explorer',
    label: 'World Explorer',
    description: 'Visit 25 countries',
    unlockCondition: CountryCountCondition(25),
    template: CardTemplateType.timeline,
    emoji: '🧭',
  ),
  MerchExclusiveDesign(
    id: 'half_the_world',
    label: 'Half the World',
    description: 'Visit 50 countries',
    unlockCondition: CountryCountCondition(50),
    template: CardTemplateType.passport,
    emoji: '🌍',
  ),
  MerchExclusiveDesign(
    id: 'global_citizen',
    label: 'Global Citizen',
    description: 'Visit all 6 continents',
    unlockCondition: ContinentCountCondition(6),
    template: CardTemplateType.badge,
    emoji: '🌐',
  ),
  MerchExclusiveDesign(
    id: 'century_club',
    label: 'The Century Club',
    description: 'Visit 100 countries',
    unlockCondition: CountryCountCondition(100),
    template: CardTemplateType.grid,
    emoji: '💯',
  ),
];
