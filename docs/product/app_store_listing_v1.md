# App Store listing — Roavvy v1.0 (free launch)

**Milestone:** M188 (#118) · **ADR:** 180 · **Status:** Draft, awaiting owner sign-off

v1.0 ships with commerce off: no T-shirts, prints, cart, checkout or orders. Nothing in this
listing may mention or show them (App Review guideline 2.3). Paste the fields into App Store
Connect by hand.

---

## Name and subtitle

- **Name (30):** Roavvy
- **Subtitle (30):** Your travel map, from photos *(28)*

## Promotional text (170)

> Scan your photo library and watch every country you've visited light up on your own world
> map. Free, with no purchases, and your photos never leave your phone.

## Description

> Roavvy turns the photos you already have into a living map of everywhere you've been.
>
> SCAN ONCE, SEE EVERYTHING
> Roavvy reads the location and date stored in your photos and works out which countries you
> visited and when. The scan runs entirely on your iPhone. Your photos are never uploaded.
>
> YOUR WORLD MAP
> Every country you've been to lights up. Add or remove countries by hand at any time.
>
> TRIPS AND MEMORIES
> See your trips on a timeline, rediscover journeys you'd forgotten, and get a gentle reminder
> on the anniversary of a trip.
>
> ACHIEVEMENTS
> Earn badges for countries, continents and UNESCO World Heritage Sites as your map grows.
>
> DAILY UNESCO CHALLENGE
> A new World Heritage puzzle every day. Keep your streak going.
>
> TRAVEL REPLAY
> Watch your travels play back year by year on a spinning globe.
>
> TRAVEL CARDS
> Turn your countries into a shareable card: flags, passport stamps or a timeline. Share it
> anywhere.
>
> PRIVATE BY DESIGN
> Photo scanning happens on your device. Only the list of countries and dates is synced, so
> your map is safe if you change phones. Delete your account and data at any time in Settings.
>
> Roavvy is free. There are no purchases, subscriptions or ads.

**Owner to confirm** that each feature named above is in the v1.0 build and not hidden behind
a dev flag: memory reminders, travel replay, travel cards (flags, passport stamps, timeline).

## Keywords (100, comma-separated, no spaces)

```
travel,map,countries,visited,tracker,world,photos,passport,trips,unesco,scratch,journal,globe
```
*(93)*

## What's New (v1.0)

> The first release of Roavvy. Scan your photos, map your countries, and share your travels.

## Screenshots

- Take every screenshot from a **commerce-off build** (the default; no `ROAVVY_COMMERCE`
  define): no Shop tab, no print or T-shirt buttons, no merch cards.
- Suggested set (6.9" and 6.5"): map, scan result, achievements, daily challenge, travel replay,
  travel card.
- Do **not** reuse `apps/web_marketing/public/images/screenshots/merchandise.jpg`.

## Categories and age rating

- **Primary:** Travel · **Secondary:** Lifestyle
- **Age rating:** answer "None" to every content question. Expected result 4+. Location and
  user accounts don't affect the rating. The Terms set a minimum age of 13 for the account,
  which is stricter than the rating; App Review accepts this.

## App Privacy ("nutrition labels")

No **Purchases** or **Financial Info** category: v1.0 collects neither.

| Data type | Collected | Linked to user | Tracking | Purpose |
|---|---|---|---|---|
| Contact Info: Email address | Yes, if the user signs in with email, Apple or Google | Yes | No | App functionality |
| Contact Info: Name | Only if the sign-in provider shares it — **owner to verify** | Yes | No | App functionality |
| Identifiers: User ID | Yes (Firebase Auth UID, anonymous included) | Yes | No | App functionality |
| Location: Coarse location | Yes: visited country codes and dates, synced to Firestore | Yes | No | App functionality |
| Diagnostics: Crash data | Yes (Firebase Crashlytics) | **Owner to verify** whether a user ID is attached | No | App functionality |
| Photos or videos | **No.** The scan reads metadata on-device only | — | — | — |
| Precise location | **Owner to verify** that the UNESCO "nearby" feature uses device location on-device only and never sends it | — | — | — |
| User Content: Other | **Owner to verify** what `firebase_storage` uploads (for example shared card images) | | | |

## App Review notes

> All features in this version are free. There are no in-app purchases, subscriptions,
> physical goods or payments of any kind.
>
> To try the app without travel photos, add countries by hand using Review & Edit on the
> scan screen.
>
> Photo access is used only to read the GPS location and date embedded in photos, on the
> device, to work out which countries the user has visited. Photos are never uploaded.
> Location access (optional) is used only to show nearby UNESCO World Heritage Sites.

## Links

- Privacy Policy: https://www.roavvy.com/privacy
- Terms: https://www.roavvy.com/terms
- Support: https://www.roavvy.com/support

Deploy the M188 website changes before submitting, so the hosted Privacy Policy and Terms match
the app.
