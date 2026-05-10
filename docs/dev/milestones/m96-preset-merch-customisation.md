# M96 — Preset-Driven Merch & Advanced Customisation

**Phase:** 20 — Commerce Experience
**Depends on:** M75 (inline config UX), M85 (confirmation screen), M93 (hero image card background)
**Status:** Not started

---

## Goal

Replace the current blank-state card-first merch flow with a preset-driven experience: the user
immediately sees a t-shirt mockup generated from a smart preset (no manual config required). A
two-layer customisation system lets users make quick tweaks inline (colour, size, placement) or
go deeper via an explicit "Customise Design" sheet. A single generated image is locked in as the
source of truth for the entire purchase pipeline. Printful mockup placement and "none" handling
are fixed. Mockup loading gets a progress indicator and retry logic.

Scope out: post-purchase "My Merch" screen (separate milestone); gift messages (M81); shipping
speed selection (M83); web checkout.

---

## What already exists (do NOT rebuild)

- `local_mockup_preview_screen.dart` — full inline config UX (M75), Printful mockup fetch, colour/
  size/placement controls
- `MerchOrderConfirmationScreen` — mandatory pre-checkout confirmation gate (M85)
- `card_image_renderer.dart` — renders passport/grid/heart card to PNG bytes (M93 adds hero bg)
- `CardTemplateType` enum — passport | grid | heart
- Shopify `createMerchCart` callable Cloud Function

---

## Preset system

### Data model

```dart
class MerchPreset {
  final String id;
  final String label;              // display name, e.g. "Recent Trip"
  final MerchPresetConfig config;
}

class MerchPresetConfig {
  final CardTemplateType layout;   // passport | grid | heart
  final MerchCountrySource source; // recentTrip | thisYear | allTime | singleCountry
  final double jitter;             // 0.0–1.0
  final MerchDensity density;      // sparse | balanced | dense
  final MerchStampMode stampMode;  // entryOnly | entryExit
}
```

### Built-in presets

| ID | Label | Layout | Source | Jitter | Density |
|---|---|---|---|---|---|
| `recent_trip` | Recent Trip | passport | recentTrip | 0.8 | balanced |
| `this_year` | This Year | grid | thisYear | 0.2 | adaptive |
| `all_time` | All Countries | grid | allTime | 0.1 | dense |
| `single_country` | Single Country | passport | singleCountry | 0.5 | sparse |

Default preset on flow entry: `recent_trip`.

### Config override pattern

```dart
final finalConfig = selectedPreset.config.copyWithOverrides(userOverrides);
generateImage(finalConfig);
```

Users never edit raw config — they apply overrides on top of the active preset.

---

## Flow

```
[Trigger: country unlock / daily pulse / profile stats CTA]
        |
        v
[MerchEntryScreen]
  - Loads default preset (recent_trip)
  - Generates image from preset config immediately (local, on-device)
  - Shows t-shirt mockup (front + back) with local render
  - Async: fetches Printful mockup in background (~20 sec)
        |
        v  (mockup visible)
[Layer 1 — Quick Controls, always inline]
  - Shirt colour chip strip
  - Size selector (XS S M L XL XXL)
  - Front placement: left_chest | centre | right_chest | none
  - Back placement: centre | none
  Any change: re-fetches Printful mockup; shows progress indicator
        |
        v  (optional)
[Layer 2 — Advanced Customisation sheet]
  Entry: "Customise Design" button (only after initial mockup shown)
  - Preset picker: switch preset (resets base config, retains compatible overrides)
  - Country selection: add/remove by year / region / trip filter
  - Layout: grid | scattered | badge
  - Jitter: low | medium | high
  - Density: sparse | balanced | dense
  - Stamp mode: entry only | entry + exit
  Any change: regenerates image + re-fetches Printful mockup
        |
        v
[Review & Checkout] -> MerchOrderConfirmationScreen (M85, unchanged)
```

---

## Image persistence

- Generated PNG bytes stored in a single `_artworkBytes` field in screen state
- Written once on generation; never silently regenerated
- Passed immutably to `MerchOrderConfirmationScreen` at push time
- Same bytes used for local mockup fallback and as artwork for Printful order

Forbidden:
- Regenerating image on navigation events without explicit user action
- Using different bytes in the confirmation screen or checkout payload

---

## Printful mockup fixes

### Placement accuracy

- `left_chest`, `centre`, `right_chest` must map to the correct Printful `placement` values
- No silent fallback to `centre` when a different placement is requested
- Placement values validated before API call; throw `ArgumentError` on unmapped value

### "None" placement

- `frontPosition == 'none'` must request a real blank-shirt mockup, not skip the API call
- Return the blank mockup URL; do not fall back to local render

### Back design rendering

- `backPosition == 'centre'` must render the back mockup correctly
- `backPosition == 'none'` must request a blank-back mockup

---

## Mockup loading UX

While Printful mockup is generating (~20 sec):
- Show `LinearProgressIndicator` below the mockup area
- Display copy: "Generating your shirt preview..."
- Disable "Review & Checkout" button until mockup is ready or max retries reached
- Auto-retry up to 2 times on network error (exponential backoff: 3s, 6s)
- After 3 failures: show amber warning "Preview unavailable — you can still proceed" and re-enable button

---

## Files in scope

| File | Change |
|---|---|
| `lib/features/merch/merch_preset.dart` | NEW — MerchPreset, MerchPresetConfig, built-in presets |
| `lib/features/merch/merch_customisation_sheet.dart` | NEW — Layer 2 advanced customisation bottom sheet |
| `lib/features/merch/local_mockup_preview_screen.dart` | MODIFY — integrate preset system, Layer 1 controls, image lock, mockup UX fixes |
| `lib/features/merch/printful_placement_mapper.dart` | NEW — validated placement enum → Printful string mapping |

---

## Acceptance criteria

- [ ] Default preset generates a design and shows a t-shirt mockup immediately on flow entry
- [ ] Quick Controls (colour, size, placement) are visible inline without tapping anything
- [ ] "Customise Design" button only appears after initial mockup is shown
- [ ] Switching preset resets base config; compatible user overrides survive
- [ ] `_artworkBytes` is set once and never silently replaced
- [ ] `MerchOrderConfirmationScreen` receives the same bytes used in the mockup preview
- [ ] Printful placement `left_chest` / `right_chest` / `centre` map correctly; no silent fallback
- [ ] `frontPosition == 'none'` returns a real blank-shirt Printful mockup URL
- [ ] Progress indicator shown during Printful mockup fetch
- [ ] Retry logic fires up to 2 times; fallback warning shown after 3 failures
- [ ] flutter analyze passes with zero new issues
