# M142 — Merch Pre-Purchase Design Sharing

## Goal

Enable users to share a design concept before purchase — from the option selection
screen, at the moment of highest enthusiasm. Currently nothing is shareable until after
the user has configured size and colour in `LocalMockupPreviewScreen`.

Moving sharing earlier creates organic marketing at peak emotional engagement.

---

## Phases & Tasks

### T1 — Share action on `MerchOptionFeaturedCard`

**File:** `apps/mobile_flutter/lib/features/merch/merch_option_list_widgets.dart`

Add a share icon button to the top-right of `MerchOptionFeaturedCard` when the
card is in `_MerchGenState.ready` state:

```
┌────────────────────────────────────┐
│  [shirt mockup — 160px]     [↑ share] │
├────────────────────────────────────┤
│  [✦ Best Match]                    │
│  The Grand Tour                    │
│  Your travels across 6 countries   │
│  from £29.99                       │
│  [Design This Shirt]               │
└────────────────────────────────────┘
```

The share icon (`Icons.ios_share_rounded`) sits in the top-right of the preview area
as an `Positioned` widget inside the `Stack` that wraps the shirt mockup.

Tapping it calls `_shareDesign()`:

```dart
Future<void> _shareDesign() async {
  final bytes = _artworkBytes;
  if (bytes == null) return;
  await MerchShareExporter.share(
    context,
    artworkBytes: bytes,
    title: widget.option.title,
    subtitle: widget.option.artworkSubtitle,
    shirtColor: widget.option.suggestedShirtColor ?? 'Black',
  );
}
```

`MerchShareExporter.share()` already exists (`merch_share_exporter.dart`) and is
used in `LocalMockupPreviewScreen`. Verify its signature accepts these parameters
and update if needed (it may currently expect a shirt mockup image rather than artwork
bytes — adapt accordingly).

### T2 — Share action on `MerchOptionCard`

**File:** `apps/mobile_flutter/lib/features/merch/merch_option_list_widgets.dart`

Add a share icon to `MerchOptionCard` in the `_buildInfo()` section, below the
template label chip. Show only when `_state == _MerchGenState.ready`:

```
[template chip]  [↑]   ← share icon, 16px, Colors.white38
```

Tapping calls the same `MerchShareExporter.share()` pattern using `_artworkBytes`.

Keep the icon small and secondary — the primary tap action (navigate to preview) must
remain dominant.

### T3 — Review and adapt `MerchShareExporter`

**File:** `apps/mobile_flutter/lib/features/merch/merch_share_exporter.dart`

Read the current implementation. Ensure it produces a shareable image that includes:
- The shirt mockup (back, showing the artwork) rendered at share resolution
- The design title overlaid on the image or as share text
- The country count ("42 countries")
- A subtle Roavvy wordmark (text, not a logo asset — keep it simple)

If the current exporter requires a Printful mockup URL (cloud image), adapt it to also
accept local `artworkBytes` — compositing the artwork onto the local shirt asset using
`LocalMockupPainter` at 2× resolution. This ensures pre-purchase sharing works
without a Printful mockup.

The share text (for platforms that don't support image sharing) should be:

```
"[title] — [n] countries I've visited, designed with Roavvy 🌍"
```

### T4 — Tests

- Unit test: `MerchShareExporter` with artwork bytes produces a non-empty PNG.
- Widget test: Share icon appears on `MerchOptionFeaturedCard` when state is ready.
- Widget test: Share icon does not appear on `MerchOptionFeaturedCard` when loading.

---

## File Map

```
apps/mobile_flutter/lib/features/merch/
  merch_option_list_widgets.dart   EDIT — share icon on featured + standard cards
  merch_share_exporter.dart        EDIT — support local artworkBytes path

apps/mobile_flutter/test/features/merch/
  merch_share_exporter_test.dart   NEW  — 1 unit test
  merch_option_share_test.dart     NEW  — 2 widget tests
```

---

## ADR-175

**Pre-purchase sharing uses local artwork bytes, not Printful mockup URL (M142)**

Decision: Pre-purchase sharing composites artwork onto the local shirt asset using
`LocalMockupPainter` at 2× resolution, without waiting for a Printful photorealistic
mockup. This keeps sharing available at the earliest possible moment (option selection
screen) and avoids requiring a cloud roundtrip. The shared image is a design preview,
not a production-quality print mockup — this is appropriate for social sharing.

Status: Accepted

---

## Definition of Done

- [ ] Share icon appears on `MerchOptionFeaturedCard` in ready state.
- [ ] Share icon appears on `MerchOptionCard` in ready state.
- [ ] Share icon does not appear while card is loading or in error state.
- [ ] `MerchShareExporter.share()` works with local `artworkBytes` (no Printful URL needed).
- [ ] Shared image includes design title and country count.
- [ ] Share text falls back gracefully on platforms that don't support image sharing.
- [ ] 3 tests pass.
- [ ] `flutter analyze` — no new warnings.

**Phase:** 27 — Merch UX
**Depends on:** M139
