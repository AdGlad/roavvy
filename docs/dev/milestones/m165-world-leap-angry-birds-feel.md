# M165 — World Leap: Angry Birds Feel

**Status: Complete (2026-06-27)**

## Goal

Elevate World Leap from a functional slingshot game to a satisfying, tactile experience inspired by Angry Birds. Focus on juicy visual feedback, cohesive sound design, and scoring depth (star ratings, combo streaks).

---

## Problem

The current game works but feels flat:
- Slingshot pull has no visual richness (static white band, no power feedback)
- Launch and landing have no screen impact
- Countdown tick reuses the landing sound (confusing)
- Sounds are repurposed travel/replay clips — not designed for fast arcade feel
- No star rating or combo system to reward skill

---

## Changes

### Visual feel

| # | Change | File |
|---|---|---|
| 1 | Band colour shifts white → yellow → red as power increases | `slingshot_widget.dart` |
| 2 | Vertical power meter bar next to slingshot | `slingshot_widget.dart` |
| 3 | Band snaps back to rest position on release (spring animation) | `slingshot_widget.dart` |
| 4 | Screen shake on launch and landing | `world_leap_screen.dart` |
| 5 | Landing splash ripple marker on map | `world_leap_map_widget.dart` |
| 6 | Miss indicator: dotted line from landing to target when wrong country | `world_leap_map_widget.dart` |

### Scoring depth

| # | Change | File |
|---|---|---|
| 7 | Star rating (1–3) per shot based on time remaining | `world_leap_score_breakdown.dart`, `world_leap_score_panel.dart` |
| 8 | Combo streak multiplier (×1.5 at 3, ×2 at 5, ×3 at 8+) | `world_leap_run.dart`, `world_leap_controller.dart`, `world_leap_score_breakdown.dart`, `world_leap_scoring_service.dart`, `world_leap_score_panel.dart` |

### Sound

| # | Change | File |
|---|---|---|
| 9 | Rename sound constants to match new asset names; add missing events | `world_leap_config.dart`, `world_leap_audio_service.dart` |

---

## Sound asset names (to source from freesound.org or kenney.nl)

| Constant | File name | Description |
|---|---|---|
| `soundStretch` | `wl_stretch.mp3` | Rubber creak, gets tighter as power increases |
| `soundLaunch` | `wl_launch.mp3` | Elastic snap + whoosh |
| `soundWindFlight` | `wl_wind.mp3` | Short wind whistle |
| `soundImpact` | `wl_impact.mp3` | Punchy thud on landing |
| `soundMiss` | `wl_miss.mp3` | Cartoon boing / wrong-country |
| `soundTick` | `wl_tick.wav` | Sharp click (distinct from landing) |
| `soundTimeout` | `wl_timeout.mp3` | Dramatic fail horn |
| `soundFanfare` | `wl_fanfare.mp3` | 3-note success jingle |
| `soundGameOver` | `wl_game_over.mp3` | End-of-run sting |

---

## Star rating thresholds

| Stars | Time remaining |
|---|---|
| ⭐⭐⭐ | > 10 s |
| ⭐⭐ | 5 – 10 s |
| ⭐ | < 5 s (but target hit) |

---

## Combo streak multiplier

| Streak | Multiplier |
|---|---|
| < 3 | ×1.0 |
| 3–4 | ×1.5 |
| 5–7 | ×2.0 |
| 8 + | ×3.0 |

Resets to 0 on wrong country or timeout.

---

## Acceptance Criteria

- [x] Band colour visibly shifts from white to red during pull
- [x] Power meter visible alongside slingshot while dragging
- [x] Screen shakes briefly on launch and on landing
- [x] Splash ripple appears at landing point, fades after ~1.5 s
- [x] Wrong country shows dotted line from landing to target country centre
- [x] Score panel shows star rating (1–3) per shot
- [x] Score panel shows combo multiplier when streak ≥ 3
- [x] `flutter analyze` produces zero new warnings
- [x] All new sound constants reference distinct asset paths
