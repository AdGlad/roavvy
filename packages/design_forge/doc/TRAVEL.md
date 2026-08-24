# Travel-data model

The foundational input for data-driven designs (passport, timeline, journey,
word cloud). Pure Dart in `design_forge` (`src/travel/trip.dart`), so the iPhone
app passes its trips straight in. First step toward replacing the mobile card
engine with the Studio.

## Types

- **`Trip`** — mirrors the app's `TripRecord`: `countryCode`, `startedOn`,
  `endedOn`, `photoCount`. `durationDays` (inclusive), JSON round-trip.
- **`DateRange`** — inclusive window (either bound nullable). `DateRange.all`,
  `DateRange.years(from, to)`, `overlaps(trip)`. Drives the "select a date range"
  studio option.
- **`TravelHistory`** — read-only view over trips (sorted): `countryCodes`
  (first-visited order), `visitCounts` (word-cloud sizing), `forCountry`,
  `mostRecentFor`, `inRange`, `span`.

## Wired into generation

`DesignContext` now carries `trips` + `dateRange` alongside `flagCodes`:

```dart
DesignContext.fromTrips(trips, dateRange: DateRange.years(2023, 2024));
```

- `flagCodes` still drives grid/heart/etc. (all selected flags).
- Passport designs read **real trip dates**: `LabShowcaseGenerator` uses
  `history.mostRecentFor(cc)` for a single stamp and one `cc|entry|exit` segment
  **per real trip** for the passport page (multiple trips → multiple stamp
  pairs), falling back to a synthesised date only when a country has no trip.

## Lab

The Design Lab adds a **Trips** year-range slider (2018–2026). macOS has no real
travel history, so the Lab synthesises a deterministic trip set per country
(`_simulatedTrips`); the slider filters which trips feed the designs. On mobile,
pass the user's real `TripRecord`s in instead — no engine changes needed.

An optional **"Auto-select countries visited in range"** toggle makes the Trips
slider **populate the flag selection**: moving the slider (with the toggle on)
sets the selected flag chips to the countries that have a trip in the window
(from a deterministic simulated "visited countries" roster). Off = manual flag
selection, with trips still filtered so passport/timeline show real dates. When
on and nothing was visited in the window, the Lab shows "No countries visited …".

## Data-driven templates (built on this model)

`RecipeContent.entries` (`RecipeEntry` = code + label + start/end + weight)
carries the per-country travel data so these designs are self-contained. New
`DesignFamily` render paths in `design_forge_render/src/stages/data_layouts.dart`
(dispatched from `CompositionStage`):

- **timeline** — chronological dated trip list with a spine + node dots, flag
  chips, country name + `MMM yyyy` date range (one row per trip).
- **journeys** — flag "stops" (circular chips) along a winding dotted route.
- **wordCloud** — country names sized by visit frequency (`weight`) and
  **spiral-packed** into a dense oval (Archimedean spiral + overlap test +
  shrink-to-fit), like the mobile `word_cloud` package — not a same-size list.
  Coloured by each flag's dominant colour.

Four more data-driven genres (mobile-proven), same `DataLayouts` mechanism:

- **badge** — circular explorer emblem: double ring + tick marks, an arc of flag
  chips, big country count + scope label. `meta: {count, scope}`.
- **frontRibbon** — a medal-bar block of rounded flag "ribbons" (front-chest).
- **achievements** — a star medallion with a hero flag + milestone title
  (`_milestone(count)`) + subtitle. `meta: {milestone, sub}`.
- **stats** — travel-story infographic: countries / continents / % of world +
  trips + flag strip. `meta: {count, trips, continents, worldPct}`.

Label/stat values are baked into `RecipeContent.meta` (self-contained). The Lab
computes continents via `FlagSource.continentOfCountry()` (from the
`<continent>_countries.json` files) and passes `countryContinents` to the
generator.

## Genre-first navigation (`LabGenre`)

The Lab's primary selector is a **Genre** dropdown — the *subject* the design is
about — with **Style** and **Effects** as cross-cutting *finishes*:

| Genre | Emits |
|---|---|
| **Flags** | flag hero + geometric/symbolic/outdoor/prop clip shapes (style-driven; the other genres' subjects are filtered out) |
| **Passport** | real entry/exit stamps + passport page |
| **Animals & Nature** | animal + plant silhouettes |
| **Landmarks** | landmark silhouettes |
| **Maps** | country + continent outlines |
| **Travel Log** | timeline / journeys / word cloud (data) |
| **Typography** | text |
| **Milestones** | badge / front ribbon / achievements / stats (data) |

`LabGenre` (in `lab_styles.dart`) owns each genre's subject rotation / family
set; `LabShowcaseGenerator(genre:, template:)` uses the genre's subjects with the
style's finish. Data genres show a **Type** sub-dropdown (Mixed = rotate the
genre's families, or pin one). `kNonFlagArchetypes` keeps the Flags genre clean.

Inspecting a data-driven design in the editor preserves its family + entries +
meta (`RecipeDraft`/`toRecipe`), so the preview matches the grid instead of
collapsing to a single flag; a colour grade stays editable.

The Lab exposes a **Template** dropdown (Showcase / Timeline / Journeys / Word
cloud); the **Trips** year-range slider filters which trips feed them. Note: in
headless tests text renders as Ahem boxes; the macOS Lab shows real letters.

## Still to come

Title/footer/background layers; badge/frontRibbon templates; per-stamp controls;
wiring real trips in the mobile app. See the mobile-vs-studio gap analysis.
