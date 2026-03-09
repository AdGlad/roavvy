# Onboarding

## Goal

Get the user to their first scan result as quickly as possible. Every screen before the map reveal is friction. Minimise it.

The onboarding flow runs once: on first launch after install. It is not re-shown after the user has granted permission and completed a scan.

---

## Screen Flow

```
Screen 1: Hook
Screen 2: Permission rationale
  ↓
iOS permission prompt (system)
  ├── Denied → Screen 3a: Denied state
  └── Granted → Scan in progress → Map reveal
```

---

## Screen 1 — Hook

**Purpose:** Establish what Roavvy does and create a reason to continue.

**Copy (draft):**
> **Your photos already know where you've been.**
> Roavvy reads the GPS data from your existing photos to build your personal travel map. No logging. No check-ins. Just scan.

**Visual:** Animated world map with countries lighting up.

**CTA:** `Get Started` — full-width button, primary style.

**No "Skip" option.** This screen is one tap. There is nothing to skip.

---

## Screen 2 — Permission Rationale

**Purpose:** Build trust before the system permission prompt appears. The user should tap "Allow" on the iOS prompt without hesitation.

**Copy (draft):**
> **Your photos stay on your device.**
> Roavvy reads *when* and *where* your photos were taken — nothing else. Your photos are never uploaded, never stored on our servers, and never shared.

Supporting detail (smaller text):
> We read GPS metadata and capture dates only. We never access the photo itself.

**Visual:** Simple diagram — phone → location pin. Not a photo.

**CTA:** `Scan My Photos` — triggers the iOS permission prompt.

**Secondary:** `Not now` — text link, de-emphasised. Takes the user to the app with an empty map and a prompt to scan when ready.

**Do not:** promise anything in this copy that the app does not technically enforce. The privacy model must be exactly as described.

---

## iOS Permission Prompt

This is the system-generated dialog. We do not control its appearance.

The `NSPhotoLibraryUsageDescription` (Info.plist) must read:

> Roavvy reads the location and date from your photos to build your travel map. Your photos are never uploaded or shared.

This must accurately reflect what the app does. App Store review will reject usage strings that misrepresent access.

---

## Screen 3a — Permission Denied

**Purpose:** Explain the situation without guilt or pressure. Give the user a clear path forward.

**Copy (draft):**
> **Photo access needed to scan**
> Roavvy needs access to your photo library to detect which countries you've visited. You can change this in Settings.

**CTA:** `Open Settings` — deep-links to the app's Settings page.

**Secondary:** `Continue without scanning` — enters the app with an empty map; the user can add countries manually or grant access later.

---

## Returning to Onboarding

Users who tapped "Not now" or "Continue without scanning" see a persistent prompt on the empty map screen:

> **Ready to discover your countries?** [Scan My Photos]

This prompt disappears after the first successful scan.

---

## What Onboarding Does Not Include

- Account creation — anonymous auth is silent. Sign-in is optional and surfaced later.
- Feature tours or carousels — the map reveal after the first scan is the tutorial.
- Push notification opt-in — deferred until Phase 5; shown only after the user has seen value.
- Rating prompts — never in onboarding; shown after a meaningful moment (e.g. first achievement).
