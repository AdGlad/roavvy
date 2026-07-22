# M172 — World Leap: Audio & Haptic Polish

**Status:** Complete

## Problem
- `wl_stretch.mp3` never plays during drag (aimNotifier doesn't call notifyListeners)
- `wl_timeout.mp3` defined but never triggered
- `wl_game_over.mp3` defined but never triggered
- No combo-escalation sounds (same sound at ×1.5, ×2, ×3)
- Haptics are minimal — no celebration pattern, no failure thud

## Changes
1. Add aim-drag sound: hook `aimNotifier` listener in map widget to play/throttle stretch sound.
2. Trigger `wl_timeout.mp3` on `FailureReason.timeout`.
3. Trigger `wl_game_over.mp3` on `Complete` state (fanfare → game_over after delay).
4. Add combo sound escalation: distinct audio cue when hitting ×1.5, ×2, ×3 multiplier.
5. Haptic patterns: 
   - Miss: `HapticFeedback.heavyImpact` × 2 with 80 ms gap
   - Landed (regular): `mediumImpact`
   - Landed (long-shot bonus): `heavyImpact`
   - Timeout: `vibrate` buzz pattern
   - Combo unlock: custom 3-pulse pattern
6. Volume ramp on wind sound proportional to power (0.3–1.0).

## Acceptance Criteria
- [ ] Stretch sound plays during drag
- [ ] Timeout plays timeout sound + buzz haptic
- [ ] Game over plays correct sound sequence
- [ ] Combo milestone triggers distinct audio cue
- [ ] All audio is mutable via existing mute toggle
