import 'package:shared_models/shared_models.dart';

/// A travel identity associated with a user's achievement context.
///
/// Resolved by [TravelIdentityInfo.forContext] from the achievement type,
/// country count, trip count, and stamp count. Used to personalise merch
/// gallery presentation, section labels, and story copy (ADR-155).
enum TravelIdentity {
  passportCollector,
  europeExplorer,
  asiaExplorer,
  africaExplorer,
  americasExplorer,
  oceaniaExplorer,
  mediterraneanExplorer,
  islandExplorer,
  hemisphereHopper,
  worldTraveller,
  globalExplorer,
  frequentFlyer,
  adventurer,
}

/// Display metadata for a [TravelIdentity].
class TravelIdentityInfo {
  const TravelIdentityInfo({
    required this.identity,
    required this.displayName,
    required this.tagline,
    required this.emoji,
  });

  final TravelIdentity identity;

  /// Short title, e.g. "Europe Explorer".
  final String displayName;

  /// One-line emotional tagline, e.g. "Collecting stamps across the continent".
  final String tagline;

  /// Representative emoji shown in the celebration header.
  final String emoji;

  // ── Factory ────────────────────────────────────────────────────────────────

  /// Resolves the most appropriate [TravelIdentityInfo] for the given context.
  ///
  /// Resolution rules (first match wins):
  /// 1. Continent-scope achievement → continent explorer
  /// 2. Region-scope achievement → region explorer
  /// 3. Passport-stamp milestone → passportCollector
  /// 4. 50+ countries → worldTraveller
  /// 5. Continent-breadth achievement (≥4 continents) → globalExplorer
  /// 6. 10+ trips → frequentFlyer
  /// 7. 10+ stamps → passportCollector
  /// 8. Fallback → adventurer
  static TravelIdentityInfo forContext({
    Achievement? achievement,
    required List<String> codes,
    required int tripCount,
    required int stampCount,
  }) {
    if (achievement != null) {
      final continent = achievement.continentScope;
      if (continent != null) {
        return switch (continent) {
          'Europe' => kTravelIdentityInfo[TravelIdentity.europeExplorer]!,
          'Asia' => kTravelIdentityInfo[TravelIdentity.asiaExplorer]!,
          'Africa' => kTravelIdentityInfo[TravelIdentity.africaExplorer]!,
          'North America' ||
          'South America' =>
            kTravelIdentityInfo[TravelIdentity.americasExplorer]!,
          'Oceania' => kTravelIdentityInfo[TravelIdentity.oceaniaExplorer]!,
          _ => kTravelIdentityInfo[TravelIdentity.adventurer]!,
        };
      }

      final region = achievement.regionScope;
      if (region != null) {
        return switch (region) {
          'Mediterranean' =>
            kTravelIdentityInfo[TravelIdentity.mediterraneanExplorer]!,
          'SoutheastAsia' =>
            kTravelIdentityInfo[TravelIdentity.islandExplorer]!,
          _ => kTravelIdentityInfo[TravelIdentity.adventurer]!,
        };
      }

      if (achievement.category == AchievementCategory.trips &&
          achievement.merch == MerchTriggerType.passportStamp) {
        return kTravelIdentityInfo[TravelIdentity.passportCollector]!;
      }

      if (achievement.category == AchievementCategory.continents &&
          achievement.progressTarget >= 4) {
        return kTravelIdentityInfo[TravelIdentity.globalExplorer]!;
      }
    }

    if (codes.length >= 50) {
      return kTravelIdentityInfo[TravelIdentity.worldTraveller]!;
    }
    if (tripCount >= 10) {
      return kTravelIdentityInfo[TravelIdentity.frequentFlyer]!;
    }
    if (stampCount >= 10) {
      return kTravelIdentityInfo[TravelIdentity.passportCollector]!;
    }

    return kTravelIdentityInfo[TravelIdentity.adventurer]!;
  }
}

/// Canonical display metadata for every [TravelIdentity].
const Map<TravelIdentity, TravelIdentityInfo> kTravelIdentityInfo = {
  TravelIdentity.passportCollector: TravelIdentityInfo(
    identity: TravelIdentity.passportCollector,
    displayName: 'Passport Collector',
    tagline: 'Every stamp tells a story',
    emoji: '📖',
  ),
  TravelIdentity.europeExplorer: TravelIdentityInfo(
    identity: TravelIdentity.europeExplorer,
    displayName: 'Europe Explorer',
    tagline: 'Collecting stamps across the continent',
    emoji: '🌍',
  ),
  TravelIdentity.asiaExplorer: TravelIdentityInfo(
    identity: TravelIdentity.asiaExplorer,
    displayName: 'Asia Explorer',
    tagline: 'Discovering the ancient and the new',
    emoji: '🌏',
  ),
  TravelIdentity.africaExplorer: TravelIdentityInfo(
    identity: TravelIdentity.africaExplorer,
    displayName: 'Africa Explorer',
    tagline: 'Adventures across the continent',
    emoji: '🌍',
  ),
  TravelIdentity.americasExplorer: TravelIdentityInfo(
    identity: TravelIdentity.americasExplorer,
    displayName: 'Americas Explorer',
    tagline: 'From north to south',
    emoji: '🌎',
  ),
  TravelIdentity.oceaniaExplorer: TravelIdentityInfo(
    identity: TravelIdentity.oceaniaExplorer,
    displayName: 'Oceania Explorer',
    tagline: 'Islands, reefs, and open skies',
    emoji: '🌊',
  ),
  TravelIdentity.mediterraneanExplorer: TravelIdentityInfo(
    identity: TravelIdentity.mediterraneanExplorer,
    displayName: 'Mediterranean Explorer',
    tagline: 'Sun, sea, and stamps',
    emoji: '☀️',
  ),
  TravelIdentity.islandExplorer: TravelIdentityInfo(
    identity: TravelIdentity.islandExplorer,
    displayName: 'Island Explorer',
    tagline: 'Hopping between paradise',
    emoji: '🏝️',
  ),
  TravelIdentity.hemisphereHopper: TravelIdentityInfo(
    identity: TravelIdentity.hemisphereHopper,
    displayName: 'Hemisphere Hopper',
    tagline: 'Both sides of the world',
    emoji: '🌐',
  ),
  TravelIdentity.worldTraveller: TravelIdentityInfo(
    identity: TravelIdentity.worldTraveller,
    displayName: 'World Traveller',
    tagline: 'Half the world explored',
    emoji: '✈️',
  ),
  TravelIdentity.globalExplorer: TravelIdentityInfo(
    identity: TravelIdentity.globalExplorer,
    displayName: 'Global Explorer',
    tagline: 'Every continent, every story',
    emoji: '🗺️',
  ),
  TravelIdentity.frequentFlyer: TravelIdentityInfo(
    identity: TravelIdentity.frequentFlyer,
    displayName: 'Frequent Flyer',
    tagline: 'Always on the move',
    emoji: '✈️',
  ),
  TravelIdentity.adventurer: TravelIdentityInfo(
    identity: TravelIdentity.adventurer,
    displayName: 'Adventurer',
    tagline: 'Always somewhere new',
    emoji: '🧭',
  ),
};
