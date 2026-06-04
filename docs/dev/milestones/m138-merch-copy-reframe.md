# M138 — Merch Copy Reframe: Language, Labels & Empty States

## Goal

Reframe the emotional language throughout the merch purchase flow — from administrative
and transactional to personal and celebratory — without changing any backend logic or
navigation structure.

Changes:
1. Rename "Orders" tab to "My Collection".
2. Rewrite empty states to be aspirational rather than instructional.
3. Reframe the checkout confirmation checkbox to be reassuring rather than legalistic.
4. Rename "Share my order" → "Share my design" with a better share message.
5. Replace engineering labels in the customisation sheet with outcome language.

---

## Phases & Tasks

### T1 — "Orders" → "My Collection" + empty state rewrites

**File:** `apps/mobile_flutter/lib/features/merch/merch_shop_screen.dart`

In `MerchShopScreen.build`, update the `TabBar`:

```dart
// BEFORE
const Tab(icon: Icon(Icons.shopping_bag_outlined), text: 'Orders'),

// AFTER
const Tab(icon: Icon(Icons.collections_bookmark_outlined), text: 'My Collection'),
```

Update the cart tab empty state text:

```dart
// BEFORE
'Your cart is empty.\n\nHead to the map, pick your countries, '
'and design your first personalised t-shirt.'

// AFTER
'No designs saved yet.\n\nCreate your first shirt from an achievement '
'or a Memory Pulse — it takes less than a minute.'
```

Update the orders/collection empty state in `MerchOrdersBody`:

```dart
// BEFORE
'No orders yet. Head to the Shop to order your first personalised item.'

// AFTER
'Your travel collection is empty.\n\nEvery shirt you order appears here '
'as a permanent record of your adventures.'
```

Also update `MerchCartScreen` (standalone screen, not the tab body) with the same
cart empty state text for consistency.

### T2 — Reframe checkout confirmation checkbox

**File:** `apps/mobile_flutter/lib/features/merch/merch_cart_screen.dart`
→ `CartItemCheckoutScreen`

Update the `CheckboxListTile.title`:

```dart
// BEFORE
const Text(
  'I confirm the size, colour, design, and print positions '
  'shown above are correct.',
),

// AFTER
const Text(
  'I\'m happy with my design and ready to order.',
),
```

Move `MerchCustomProductWarning` to *below* the checkbox (currently it appears above,
creating a wall of warning before the user reaches the confirm step). Reorder the
`Column` children so the checkbox appears before the warning widget.

### T3 — "Share my design" with design-specific share text

**File:** `apps/mobile_flutter/lib/features/merch/merch_post_purchase_screen.dart`

Add an optional `designTitle` parameter (also added in M137-T3 — coordinate or merge).
Update the share button label and share text:

```dart
// BEFORE
child: const Text('Share my order'),

// AFTER
child: const Text('Share my design'),
```

Update `_shareOrder`:

```dart
void _shareOrder(BuildContext context) {
  final title = widget.designTitle;
  final shareText = title != null
      ? 'Just had my "$title" shirt made — '
        '${widget.countryCount} countries I\'ve visited, '
        'designed with Roavvy \u{1F30D}'
      : 'Just ordered a ${widget.product.name} with all '
        '${widget.countryCount} countries I\'ve visited — '
        'made with Roavvy \u{1F30D}';
  // ... existing share logic
}
```

### T4 — Outcome language in customisation sheet

**File:** `apps/mobile_flutter/lib/features/merch/merch_customisation_sheet.dart`

Replace section labels and option labels:

| Current label | Replacement |
|---|---|
| `'Scatter'` section | `'Arrangement'` |
| `'Low'` | `'Structured'` |
| `'Medium'` | `'Spread'` |
| `'High'` | `'Scattered'` |
| `'Density'` section | `'Fill style'` |
| `'Sparse'` | `'Airy'` |
| `'Balanced'` | `'Balanced'` (keep) |
| `'Dense'` | `'Packed'` |
| `'Stamps'` section | `'Stamps per country'` |
| `'Entry only'` | `'One per country'` |
| `'Entry + Exit'` | `'Entry and exit'` |

Keep all underlying `_config.copyWithOverrides(...)` logic unchanged — these are
display-only label changes.

### T5 — Fix "My orders" screen title

**File:** `apps/mobile_flutter/lib/features/merch/merch_orders_screen.dart`

Update the `AppBar` title in `MerchOrdersScreen`:

```dart
// BEFORE
AppBar(title: const Text('My orders'))

// AFTER
AppBar(title: const Text('My Collection'))
```

---

## File Map

```
apps/mobile_flutter/lib/features/merch/
  merch_shop_screen.dart          EDIT — tab label, cart empty state
  merch_cart_screen.dart          EDIT — cart empty state, checkbox reorder
  merch_orders_screen.dart        EDIT — AppBar title
  merch_post_purchase_screen.dart EDIT — share button label + share text
  merch_customisation_sheet.dart  EDIT — option labels (display only)
```

---

## Definition of Done

- [ ] Shop tab shows "My Collection" (not "Orders"); icon updated.
- [ ] Cart empty state is aspirational, not instructional.
- [ ] Collection empty state frames history as a personal gallery.
- [ ] Checkout confirmation checkbox reads "I'm happy with my design and ready to order."
- [ ] `MerchCustomProductWarning` appears *below* the checkbox, not above.
- [ ] Share button says "Share my design"; share text includes design title when available.
- [ ] Customisation sheet uses outcome labels throughout.
- [ ] `flutter analyze` — no new warnings.
- [ ] No change to navigation, data layer, or checkout flow.

**Phase:** 27 — Merch UX
**Depends on:** M137
