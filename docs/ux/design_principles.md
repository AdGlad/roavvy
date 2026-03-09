# Design Principles

These principles guide every UX and UI decision in Roavvy. When two options feel equally valid, apply these to break the tie.

---

## 1. Discovery over data entry

Roavvy's core job is to reveal what the user has already done, not ask them to record it. Screens should show, not ask. The map is the hero — not a form.

**In practice:**
- Default to showing auto-detected results. Manual entry is a correction tool, not the primary input.
- Avoid empty states that feel like forms waiting to be filled. An empty map is a prompt to scan, not a blank spreadsheet.

---

## 2. Privacy is a feature, not a footnote

We make a strong claim — photos never leave the device — and the UI should communicate it clearly and early. Users who understand this claim are more likely to grant photo access and more likely to trust the app.

**In practice:**
- The permission rationale screen leads with what we *don't* do ("Your photos never leave your device") before asking.
- Settings has a dedicated Privacy section, not just buried toggles.
- The sharing card preview explains what it does and doesn't include before the user shares.

---

## 3. Offline states feel normal, not broken

The app works fully offline. Sync failures, loading spinners from slow networks, and "coming soon when connected" states should feel calm and deliberate — not like errors.

**In practice:**
- Never show a loading spinner for data that is already in the local DB.
- Sync status is shown only when relevant (e.g. pending changes exist). Not as a permanent status bar indicator.
- If the shop is unavailable offline, say so matter-of-factly and move on.

---

## 4. Edits are fast and forgiving

A wrong auto-detection shouldn't be frustrating to fix. Editing a visit should take fewer than 5 taps from the map.

**In practice:**
- Country detail sheet is reachable with one tap from the map.
- Edit and Delete are primary actions on the detail sheet, not buried in menus.
- Deletes are confirmed once, then immediate. No multi-step deletion flows.

---

## 5. Delight is earned

Animations and celebrations (the map reveal, achievement unlocks) feel meaningful because they mark genuine moments — not because they happen constantly.

**In practice:**
- The map reveal animation plays once: on first scan completion. Not on every app launch.
- Achievement unlock animations are reserved for actual first-unlocks. Viewing achievements later is calm.
- Micro-animations exist where they clarify state transitions (e.g. a country highlighting as it's added). They don't exist for decoration.

---

## 6. Accessible by default

Accessibility is not an afterthought. WCAG 2.1 AA is the minimum.

**In practice:**
- Minimum touch target: 44 × 44 pt for all interactive elements.
- Country names read as full names by VoiceOver, not ISO codes.
- The map has a list-based alternative view — a visual map alone is not sufficient.
- Colour is never the only differentiator between states (e.g. visited vs. unvisited countries use both colour and a distinct visual treatment).
