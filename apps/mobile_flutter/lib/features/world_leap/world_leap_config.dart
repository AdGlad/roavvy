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

  // ── Sound Assets ───────────────────────────────────────────────────────────
  // All wl_* MP3s are procedurally generated 8-bit arcade sounds (public domain).
  // Source: gen_8bit_sounds.py (tools/sounds/) — square/pulse waves, ADSR envelopes.
  // Regenerate: python3 tools/sounds/gen_8bit_sounds.py && ffmpeg conversion.

  /// Rising charge tone (200→800 Hz) — slingshot pull tension.
  static const String soundStretch = 'audio/wl_stretch.mp3';

  /// Sharp 'PEW!' laser-style snap — elastic release, Space Invaders style.
  static const String soundLaunch = 'audio/wl_launch.mp3';

  /// Bell-curve whoosh with noise layer — matches flight arc shape.
  static const String soundWindFlight = 'audio/wl_wind.mp3';

  /// Low 'BOOM!' with high transient click — satisfying landing thud.
  static const String soundImpact = 'audio/wl_impact.mp3';

  /// Descending 3-note minor sting (C→G#→E) — Pac-Man death flavour.
  static const String soundMiss = 'audio/wl_miss.mp3';

  /// Single C6 blip — clean countdown tick.
  static const String soundTick = 'audio/wl_tick.mp3';

  /// 5-blip descending alarm (B5→B4) — urgent timeout sting.
  static const String soundTimeout = 'audio/wl_timeout.mp3';

  /// C-E-G-C ascending arpeggio + held chord — classic 8-bit win jingle.
  static const String soundFanfare = 'audio/wl_fanfare.mp3';

  /// G4→G3 descending minor scale — dignified 8-bit game-over melody.
  static const String soundGameOver = 'audio/wl_game_over.mp3';

  // ── Landing Tolerance ──────────────────────────────────────────────────────
  // Replaces the old manual 1–5 difficulty picker (usability rework): a
  // single fixed forgiveness radius applies to everyone, and the game's
  // actual difficulty curve comes from progressive target distance instead
  // (see "Progressive Target Distance" below).

  /// Landing is accepted within this radius (km) of the target centroid, even
  /// if the reverse-geocoded country differs (e.g. landing just over a
  /// border). Roughly the old grade-2 "Normal" tolerance.
  static const double landingToleranceKm = 250.0;

  // ── Progressive Target Distance ─────────────────────────────────────────────

  /// Number of successful launches over which target distance ramps from
  /// "nearest candidates only" to "any unvisited country" — early targets
  /// are close to the launch point so new players aren't asked to aim
  /// halfway around the globe on their first shot.
  static const int progressiveDistanceRampLaunches = 8;

  /// Minimum number of nearest candidates considered even on the very first
  /// shot, so target selection still has some variety rather than always
  /// picking the single closest country.
  static const int progressiveMinCandidatePool = 4;

  // ── Countdown Timer ────────────────────────────────────────────────────────

  /// Starting time limit (seconds) for the first shot.
  static const int countdownStartSeconds = 45;

  /// Minimum time limit (seconds) — floor after repeated successes.
  static const int countdownMinSeconds = 20;
}
