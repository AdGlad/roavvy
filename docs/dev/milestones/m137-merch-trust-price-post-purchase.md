# M137 — Merch Trust: Fix Product Names, Price Transparency & Post-Purchase Design

## Goal

Three targeted fixes that eliminate the biggest trust and conversion problems in the
merch purchase flow — all S-complexity, bundled into a single milestone.

1. **Fix "Roavvy Test Tee"** — replace the hardcoded product name in order history with
   the stored design title, so users see emotionally resonant names instead of a test
   artifact.
2. **Price on option cards** — surface the "from £X" price on `MerchOptionCard` and
   `MerchOptionFeaturedCard` so users know the cost before investing emotional energy.
3. **Post-purchase shows the design** — pass and display the shirt mockup on
   `MerchPostPurchaseScreen` so the first thing users see after buying is their design,
   not just a generic confirmation.

---

## Phases & Tasks

### T1 — Fix product name in order history

**File:** `apps/mobile_flutter/lib/features/merch/merch_orders_screen.dart`

`MerchOrderSummary.fromDoc` currently derives product name with a hardcoded lookup:

```dart
final productName =
    variantId.contains('Poster') ? 'Travel Poster' : 'Roavvy Test Tee';
```

Replace with a title stored in the Firestore document at order creation time:

```dart
final productName = data['title'] as String? ??
    data['designTitle'] as String? ??
    (variantId.contains('Poster') ? 'Travel Poster' : 'Travel T-shirt');
```

- Read `title` first (written by `LocalMockupPreviewScreen` when it creates the cart
  item via `MerchCartRepository`).
- Fallback for older orders without a title field: "Travel T-shirt" (not "Roavvy Test Tee").
- No Firestore schema migration needed — new field is additive.

Also update `MerchCartItem` and `MerchCartRepository` to ensure the design title
is written to the cart item document at creation time. The title is already available
in `LocalMockupPreviewScreen` as `_titleController.text` or equivalent.

### T2 — Surface price on merch option cards

**File:** `apps/mobile_flutter/lib/features/merch/merch_option_list_widgets.dart`

Add a price label to `MerchOptionCard._buildInfo()` and `MerchOptionFeaturedCard`:

```dart
// Below the template label chip in MerchOptionCard
Text(
  'from ${MerchProduct.tshirt.fromPrice}',
  style: const TextStyle(
    color: Colors.white54,
    fontSize: 10,
  ),
),
```

For `MerchOptionFeaturedCard`, place the price as a small line below the description,
above the "Design This Shirt" CTA:

```
[✦ Best Match]
Europe 2024
Your travels across 6 European countries
from £29.99
[Design This Shirt]
```

- Use `MerchProduct.tshirt.fromPrice` — the value is already defined in
  `merch_variant_lookup.dart`.
- Do not show a specific variant price — "from £X" is the correct framing at this stage.
- Posters are not surfaced on option cards (only T-shirts), so no poster pricing needed here.

### T3 — Post-purchase screen shows the design

**File:** `apps/mobile_flutter/lib/features/merch/merch_post_purchase_screen.dart`

Add an optional `frontMockupUrl` parameter to `MerchPostPurchaseScreen`:

```dart
class MerchPostPurchaseScreen extends StatefulWidget {
  const MerchPostPurchaseScreen({
    super.key,
    required this.product,
    required this.countryCount,
    this.frontMockupUrl,    // ADD
    this.designTitle,       // ADD
  });

  final MerchProduct product;
  final int countryCount;
  final String? frontMockupUrl;   // Printful photorealistic mockup
  final String? designTitle;      // MerchStory-generated title
```

When `frontMockupUrl` is non-null, render it above the confetti content, before the
🎉 emoji:

```
┌────────────────────────────────┐
│  [shirt mockup image — 280px]  │
│  [title: "The Grand Tour"]     │
│                                │
│  🎉                            │
│  Your order is on its way!     │
│  ...                           │
│  [Back to my map]              │
│  [Share my design]             │
└────────────────────────────────┘
```

- Use `Image.network` with a `CircularProgressIndicator` loading builder and a
  fallback icon (`Icons.dry_cleaning_outlined`) if the URL fails.
- Show `designTitle` in bold below the mockup image when non-null.
- When `frontMockupUrl` is null (older flow paths), the screen renders exactly as
  before — purely additive change.

**Callers to update:**

`LocalMockupPreviewScreen` (`_pollForOrderConfirmation` / `_onApproveAndBuy`) —
pass `frontMockupUrl: _mockupUrl` and `designTitle: _currentTitle` when pushing
`MerchPostPurchaseScreen`.

---

## File Map

```
apps/mobile_flutter/lib/features/merch/
  merch_orders_screen.dart          EDIT — fix product name fallback
  merch_cart_repository.dart        EDIT — write title field to cart item doc
  merch_cart_item.dart              EDIT — add title field if not present
  merch_option_list_widgets.dart    EDIT — price label on option cards
  merch_post_purchase_screen.dart   EDIT — optional mockup + title display
  local_mockup_preview_screen.dart  EDIT — pass frontMockupUrl + designTitle
```

---

## Definition of Done

- [ ] Order history never shows "Roavvy Test Tee"; new orders show design title;
      old orders show "Travel T-shirt".
- [ ] `MerchOptionCard` and `MerchOptionFeaturedCard` both show "from £X".
- [ ] `MerchPostPurchaseScreen` displays the shirt mockup image and design title when
      `frontMockupUrl` is provided; falls back gracefully when null.
- [ ] `LocalMockupPreviewScreen` passes `frontMockupUrl` and `designTitle` to the
      post-purchase screen.
- [ ] `flutter analyze` — no new warnings.
- [ ] No change to Printful, Shopify, or Firebase Function behaviour.

**Phase:** 27 — Merch UX
**Depends on:** M120 ✅
