// lib/features/world_leap/world_leap_config.dart
//
// Central configuration for World Leap.
// All tuning values live here. No magic numbers elsewhere.

class WorldLeapConfig {
  WorldLeapConfig._();

  // ── Scoring ────────────────────────────────────────────────────────────────

  /// Base points awarded for a successful country landing.
  static const int baseCountryScore = 100;

  /// Points awarded per 100 km of flight distance.
  static const int pointsPer100Km = 1;

  /// Minimum flight distance (km) required for a launch to be valid.
  static const double minLaunchDistanceKm = 100.0;

  /// Maximum flight distance (km) a single launch can travel.
  static const double maxLaunchDistanceKm = 20000.0;

  /// Long-shot bonus threshold 1 (km).
  static const double longShotThreshold1Km = 8000.0;

  /// Long-shot bonus awarded when distance >= [longShotThreshold1Km].
  static const int longShotBonus1 = 200;

  /// Long-shot bonus threshold 2 (km).
  static const double longShotThreshold2Km = 12000.0;

  /// Long-shot bonus awarded when distance >= [longShotThreshold2Km].
  static const int longShotBonus2 = 500;

  /// Bonus awarded for the first landing on each new continent in a run.
  static const int continentBonus = 250;

  // ── Heritage Bonus ─────────────────────────────────────────────────────────

  /// Heritage bonus for landing within this radius (km) of a UNESCO site.
  static const double heritageTier1RadiusKm = 100.0;

  /// Points awarded for landing within [heritageTier1RadiusKm].
  static const int heritageTier1Bonus = 50;

  /// Heritage bonus for landing within this radius (km) of a UNESCO site.
  static const double heritageTier2RadiusKm = 50.0;

  /// Points awarded for landing within [heritageTier2RadiusKm].
  static const int heritageTier2Bonus = 100;

  /// Heritage bonus for landing within this radius (km) of a UNESCO site.
  static const double heritageTier3RadiusKm = 10.0;

  /// Points awarded for landing within [heritageTier3RadiusKm].
  static const int heritageTier3Bonus = 250;

  // ── Launch Physics (Visual Only) ───────────────────────────────────────────

  /// Number of preview dots shown on the trajectory arc.
  static const int trajectoryDotCount = 20;

  /// Fraction of screen height that represents maximum slingshot pull distance.
  static const double maxPullFraction = 0.25;

  /// Minimum normalised power (0–1) required to register a launch.
  static const double minLaunchPower = 0.1;

  // ── Daily Game ─────────────────────────────────────────────────────────────

  /// Firestore collection for daily run documents.
  static const String runsCollection = 'world_leap_runs';

  /// Firestore collection for daily start country config.
  static const String dailyCollection = 'world_leap_daily';

  /// Firestore collection for leaderboard entries.
  static const String leaderboardCollection = 'world_leap_leaderboard';

  /// SharedPreferences key for today's cached run.
  static const String localRunKey = 'world_leap_run';

  /// SharedPreferences key for mute preference.
  static const String localMuteKey = 'world_leap_mute';

  // ── Animation Durations ────────────────────────────────────────────────────

  /// Duration (ms) of the globe fly-to animation after a landing.
  static const int flyToAnimationMs = 1200;

  /// Duration (ms) the score panel is displayed before auto-dismissing.
  static const int scorePanelDisplayDurationMs = 3000;

  /// Duration (ms) of the launch projectile animation.
  static const int launchAnimationMs = 1800;

  /// Duration (ms) of the landing splash/celebration animation.
  static const int landingAnimationMs = 1200;

  /// Stagger (ms) between score panel bonus rows animating in.
  static const int scorePanelRowStaggerMs = 100;

  // ── Globe Colours ──────────────────────────────────────────────────────────

  /// Colour (RGBA string) applied to visited countries on the globe.
  static const String visitedCountryColour = 'rgba(100, 220, 150, 0.85)';

  /// Colour (RGBA string) applied to the current/active country.
  static const String currentCountryColour = 'rgba(255, 200, 50, 0.95)';

  /// Default unvisited country colour.
  static const String defaultCountryColour = 'rgba(200, 200, 200, 0.2)';

  // ── Haptics ────────────────────────────────────────────────────────────────

  /// Vibration duration (ms) for slingshot pull increments.
  static const int hapticPullDurationMs = 20;

  /// Vibration duration (ms) for launch release.
  static const int hapticReleaseDurationMs = 50;

  /// Vibration duration (ms) for successful landing.
  static const int hapticLandingDurationMs = 80;

  /// Vibration duration (ms) for heritage bonus.
  static const int hapticHeritageDurationMs = 120;

  /// Vibration duration (ms) for game over / failure.
  static const int hapticFailureDurationMs = 300;

  // ── Asset Paths ────────────────────────────────────────────────────────────

  static const String quokkaAsset = 'assets/mobile_png/Quokka-Transparent-200.png';
  static const String unescoAsset = 'assets/geodata/whs_sites.json';

  static const String soundTension = 'audio/replay_travel_short.mp3';
  static const String soundLaunch = 'audio/replay_travel_long.mp3';
  static const String soundWind = 'audio/replay_travel_short.mp3';
  static const String soundLand = 'audio/scan_country_discovery.wav';
  static const String soundSplash = 'audio/replay_arrival.mp3';
  static const String soundCelebrate = 'audio/celebration.mp3';
  static const String soundGameOver = 'audio/replay_end.mp3';

  /// Short tick sound used for the countdown heartbeat.
  static const String soundTick = 'audio/scan_country_discovery.wav';

  // ── Countdown Timer ────────────────────────────────────────────────────────

  /// Starting time limit (seconds) for the first shot.
  static const int countdownStartSeconds = 15;

  /// Minimum time limit (seconds) — floor after repeated successes.
  static const int countdownMinSeconds = 5;
}
