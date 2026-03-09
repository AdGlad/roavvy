# User Flows

High-level flows for the primary user journeys. Detailed screen specs live in `docs/ux/`.

---

## 1. First Launch & Scan

```
App launch (first time)
    │
    ▼
Onboarding screen
  "Your photos already know where you've been."
  [Get Started]
    │
    ▼
Permission rationale screen
  "Roavvy reads when and where your photos were taken.
   Your photos never leave your device."
  [Scan My Photos]  [Not now]
    │ [Scan My Photos]
    ▼
iOS photo permission prompt
    ├── Denied ──► "You can change this in Settings." [Open Settings]
    └── Granted (full or limited)
          │
          ▼
        Scan in progress
          Progress bar + country count updating live
          │
          ▼
        Scan complete → Map reveal animation
          Visited countries light up
          "You've been to N countries."
```

**Key constraint:** permission is requested only when the user taps "Scan My Photos", not on launch.

---

## 2. Returning Scan (Incremental)

```
User opens app (subsequent launch)
    │
    ▼
Home / Map screen (loads from local DB instantly)
  [Scan for new photos] button visible if > 30 days since last scan
    │ [Scan for new photos]
    ▼
Incremental scan runs (fetches photos since lastScanDate)
    │
    ├── New countries found ──► toast + map updates
    └── Nothing new ──► "No new countries since your last scan."
```

---

## 3. Edit a Visit

```
Map screen → tap a country
    │
    ▼
Country detail sheet
  Country name, flag, first visited, last visited, source (auto/manual)
  [Edit]  [Delete]
    │ [Edit]
    ▼
Edit visit screen
  Date pickers for firstSeen / lastSeen
  Source changes to "manual" on save
  [Save]  [Cancel]
    │ [Save]
    ▼
Country detail sheet (updated)
  Map updates to reflect edit
```

---

## 4. Add a Country Manually

```
Map screen → [+ Add Country]
    │
    ▼
Country picker
  Search or browse list
  Select country
    │
    ▼
Add visit screen
  Date pickers (optional — defaults to "unknown")
  Source: manual
  [Add]  [Cancel]
    │ [Add]
    ▼
Map updates; country highlighted; achievement check runs
```

---

## 5. Generate a Sharing Card

```
Map screen → [Share]
    │
    ▼
Sharing preview screen
  Shows: map snapshot, country count, country list
  "This card shows only your country list — no photos, no personal info."
  [Share]  [Cancel]
    │ [Share]
    ▼
Card created; iOS share sheet opens
  Options: copy link, Messages, Instagram, etc.
    │
    ▼
Recipient opens /share/[token] in browser
  Sees: map, country count, country list
  No user identity visible
```

---

## 6. Delete Travel History

```
Settings → Privacy → Delete Travel History
    │
    ▼
Confirmation dialog
  "This will permanently delete all your visited countries and achievements.
   This cannot be undone."
  [Delete]  [Cancel]
    │ [Delete]
    ▼
Local DB cleared
Firestore data purged
Map resets to empty state
```

---

## 7. Shop / Merchandise (web)

```
Open sharing card URL (or navigate to shop from app)
    │
    ▼
Shop landing page
  Featured products: travel poster, mug, tote
    │ [Personalise]
    ▼
Product personalisation
  Map rendered with user's country set
  Preview shown
  [Add to Cart]
    │
    ▼
Cart → Shopify checkout (hosted)
```
