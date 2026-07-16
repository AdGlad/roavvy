# M173 — World Leap: Arcade Game Feel

**Status:** Complete

## Goal
Make World Leap feel like a polished arcade game that players want to return to daily.

## Changes

### Scoring & Feedback
1. **Floating score text**: `+150 pts` animates upward and fades out at the landing point on every successful shot.
2. **Combo milestone banner**: Full-width animated banner ("COMBO ×2!", "COMBO ×3!") slides in for 1.5 s when a new multiplier tier is reached.
3. **"BULLSEYE" / "PERFECT" / "GREAT" labels**: Based on landing distance from target centroid — shown as bold text burst at the quokka position.
4. **Star burst**: 3-star animation plays when speed bonus > 150 pts.

### Visual Polish
5. **Comet trail on flight**: The flying quokka/projectile leaves a fading dot trail (CustomPainter, no additional allocations).
6. **Landing particle burst**: 8–12 coloured particles explode from the landing point (simple CustomPainter animation, no external package needed).
7. **Target country glow**: Target polygon has an outer glow ring (blurred stroke in CustomPainter) that pulses brighter as time runs low.
8. **Power indicator colour ramp**: Slingshot band and power bar colour shifts from green → yellow → orange → red as power increases.
9. **Quokka expression variants**: Smug face on combo ×2+, panic face on last 10 s, victory frame on continent bonus.

### Streak & Progression
10. **Streak fire badge**: Persistent badge in HUD showing current streak with a flame icon. Animates on increment.
11. **Difficulty ramp feedback**: When difficulty increases (every 3 shots), a brief "TARGET SHRINKS" toast slides in.
12. **Personal best notification**: On run end, if new high score, banner shows "NEW BEST 🏆".

## Acceptance Criteria
- [ ] Floating score text appears on every successful shot
- [ ] Combo banner appears on multiplier tier unlock
- [ ] Comet trail renders without jank
- [ ] Landing particles fire on every landing
- [ ] Streak badge updates in HUD
- [ ] Personal best detected and shown
- [ ] `flutter analyze` clean
