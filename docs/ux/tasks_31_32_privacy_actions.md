# UX Design — Tasks 31 & 32: Stop Sharing + Account Deletion

**Milestone:** 12
**Date:** 2026-03-16

---

## Navigation context

`docs/ux/navigation.md` already specifies these actions belong in a **Profile tab** with a **Privacy settings** push screen — not the overflow menu. The Profile tab is part of the intended 4-tab structure (Map, Countries, Achievements, Profile). It does not exist yet.

**Recommendation for M12:** Build a minimal Profile tab with a Privacy settings screen as the entry point for both Task 31 (revoke sharing) and Task 32 (delete account). Placing destructive account actions in an overflow menu on the map screen is the wrong information architecture — users expect account management in a Profile or Settings area, not buried in a map action menu. "Clear travel history" should also eventually move here, but that is out of M12 scope.

The Architect should decide whether to build the full Profile tab shell or a minimal Settings screen reachable from the overflow menu. The UX design below specifies both flows assuming a Profile > Privacy settings location.

---

## Scope of this design

1. Flow: Stop sharing (revoke share token)
2. Flow: Delete account
3. Component: Privacy settings screen
4. Component: MapScreen overflow menu changes (interim)
5. All copy for both flows

---

## Component: Privacy settings screen

This is a new push screen, reachable initially from the MapScreen overflow menu item "Settings" (or "Privacy") and ultimately from the Profile tab.

```
Component: Privacy settings screen
States: (this is a static list screen — no loading/empty state)

Content:
  Section header: "Sharing"
    Row: "Manage sharing link"
    → navigates to Sharing settings (see below)

  Section header: "Data"
    Row: "Clear travel history"
    → existing AlertDialog confirm flow (moved here from overflow)

  Section header: "Account"
    Row: "Delete account"       [red text]
    → Delete account confirm flow

Accessibility:
  - Each row: 44 pt minimum height
  - "Delete account" row: red text colour with sufficient contrast (≥ 4.5:1 on white bg)
  - Screen reader label: "Delete account, button, destructive action"
```

---

## Flow 1: Stop sharing (Task 31)

**User goal:** Remove their public map link so it no longer works for anyone.

**Entry point:** Privacy settings screen → "Manage sharing link" row.

```
Flow: Stop sharing
Entry point: Privacy settings → "Manage sharing link"

Step 1 — Sharing status screen

  State A (token exists — sharing is active):
    Header: "Your map is shared"
    Body text: "Anyone with your link can view your visited countries."
    Link preview (read-only text field or tappable row):
      "roavvy.app/share/[first 8 chars of token]…"
      Copy button (Icon: copy, label: "Copy link")
    Primary action: "Share link again"  [secondary button]
    Destructive action: "Remove link"   [red text button, below]

  State B (no token — sharing is inactive):
    Header: "Share your map"
    Body text: "Generate a link anyone can use to view your visited countries. Your name and photos are never included."
    Primary action: "Create sharing link"  [filled button]

Step 2 — Revoke confirmation dialog (from State A → "Remove link")
  Title: "Remove your sharing link?"
  Body:  "Anyone with your link will no longer be able to view your map. You can create a new link at any time."
  Actions:
    "Cancel"       [secondary, left / top]
    "Remove Link"  [destructive red, right / bottom]

Step 3 — Post-revocation
  Screen reverts to State B ("Share your map")
  No SnackBar needed — the screen change is confirmation enough.

Exit: User's public link is revoked; screen shows sharing-inactive state.

Edge cases:
  - Firestore delete fails silently: local token is cleared; screen shows State B.
    The public URL may remain accessible for a short window (cached Firestore reads).
    This is an accepted tradeoff per ADR-030 (fire-and-forget).
    Do NOT surface this failure to the user — the UI outcome (link removed) is correct.
  - User taps "Copy link" then immediately taps "Remove Link": the copy goes to clipboard;
    the link is then revoked. No special handling required.
  - User is offline when revoking: local token clears immediately; Firestore delete is
    queued. Screen shows State B. If Firestore later fails, the document persists —
    an acceptable edge case, not surfaced in UI.
```

---

## Flow 2: Delete account (Task 32)

**User goal:** Permanently remove all their data and account.

**Entry point:** Privacy settings screen → "Delete account" row (red text).

Design principle note: `design_principles.md` says "Deletes are confirmed once, then immediate." However, `navigation.md` explicitly calls for two confirmation dialogs for account deletion. Account deletion is categorically different from content deletion — it is account-level, irreversible, and includes credential destruction. **Two confirmations are correct here.** The second confirmation is a deliberate speed-bump, not a repetition.

```
Flow: Delete account
Entry point: Privacy settings → "Delete account"

Step 1 — First confirmation dialog
  Title: "Delete your account?"
  Body:  "This will permanently delete:
          · Your entire travel history
          · Your achievements
          · Your public sharing link (if any)

          This cannot be undone."
  Actions:
    "Cancel"                  [secondary]
    "Continue to delete…"     [destructive red — note: not the final confirm yet]

Step 2 — Second confirmation dialog (after "Continue to delete…")
  Title: "Are you sure?"
  Body:  "Your account and all data will be permanently deleted. There is no way to recover it."
  Actions:
    "Cancel"          [secondary]
    "Delete Account"  [destructive red — final confirm]

Step 3 — Deletion in progress
  The second dialog is replaced by a non-dismissable loading dialog:
    ActivityIndicator (circular)
    Text: "Deleting your account…"
  (User cannot dismiss or navigate away during deletion)

Step 4A — Success
  Loading dialog dismisses automatically.
  authStateProvider emits null → RoavvyApp navigates to SignInScreen.
  No SnackBar or success message: the navigation to SignInScreen is self-explanatory.

Step 4B — Requires recent sign-in (Apple Sign In users only)
  Loading dialog dismisses.
  Show AlertDialog:
    Title: "Sign in required"
    Body:  "For security, Apple requires you to sign in again before deleting your account.
            Sign in with Apple, then return to delete your account."
    Action: "OK"
  No data is deleted. The user's account is intact.

Step 4C — Unknown error
  Loading dialog dismisses.
  SnackBar (bottom of screen):
    "Something went wrong. Please try again."
  No data is deleted (see ordering note below).

Exit A: Account and all data deleted; user sees SignInScreen.
Exit B/C: Nothing deleted; user is back on Privacy settings.

Edge cases:
  - Anonymous user: re-auth is not required for anonymous account deletion.
    Step 4B should not occur. If it does (unexpected Firebase behaviour), show Step 4C copy.
  - User force-quits during Step 3: data deletion may be partial.
    On next launch, if auth state is null, the app treats the user as new.
    If auth state is non-null (deletion was incomplete), the user can try again.
    This is an acceptable edge case — no special recovery flow needed for M12.
  - User has no visits, no share token: deletion proceeds identically —
    Firestore deletes are no-ops; local clearAll() is a no-op. No special state needed.
```

**Data deletion ordering (UX-relevant constraint):**
The auth token must remain valid while Firestore data is being deleted. Therefore the implementation must delete Firestore data *before* calling `auth.delete()`. This means if `auth.delete()` later fails with `requires-recent-login`, **the user's Firestore data will already be gone**. From a UX perspective: the user wanted to delete; their data is gone; only the credential cleanup failed. The error message in Step 4B should not say "nothing was deleted" — instead say "sign in again to complete account deletion." The Architect must flag this ordering in the ADR.

---

## MapScreen overflow menu — interim state (M12)

Until the Profile tab exists, add a single item to the overflow menu that navigates to Privacy settings:

```
Overflow menu order (updated):
  1. Sign in with Apple / Signed in with Apple ✓   [auth state dependent]
  2. Share travel card                              [!anonymous && hasVisits]
  3. Share my map link / Stop sharing               [replaced by link in Privacy settings — REMOVED from overflow]
  4. Clear travel history                           [hasVisits — kept here for M12; migrate later]
  5. Privacy & account                              [always visible — NEW; navigates to Privacy settings screen]
  6. Sign out                                       [always visible]
```

Items 3 ("Share my map link" / "Stop sharing") are **removed from the overflow menu** — sharing management moves entirely to Privacy settings. This simplifies the overflow menu and puts sharing management alongside revocation in one place.

---

## Copy reference

| Context | String |
|---|---|
| Overflow item | "Privacy & account" |
| Privacy settings — section header | "Sharing" |
| Privacy settings — sharing row | "Manage sharing link" |
| Privacy settings — section header | "Data" |
| Privacy settings — section header | "Account" |
| Privacy settings — account row | "Delete account" |
| Sharing status — active header | "Your map is shared" |
| Sharing status — active body | "Anyone with your link can view your visited countries." |
| Sharing status — inactive header | "Share your map" |
| Sharing status — inactive body | "Generate a link anyone can use to view your visited countries. Your name and photos are never included." |
| Sharing status — primary CTA (inactive) | "Create sharing link" |
| Sharing status — destructive action | "Remove Link" |
| Revoke dialog — title | "Remove your sharing link?" |
| Revoke dialog — body | "Anyone with your link will no longer be able to view your map. You can create a new link at any time." |
| Revoke dialog — confirm | "Remove Link" |
| Delete account — dialog 1 title | "Delete your account?" |
| Delete account — dialog 1 body | "This will permanently delete:\n· Your entire travel history\n· Your achievements\n· Your public sharing link (if any)\n\nThis cannot be undone." |
| Delete account — dialog 1 confirm | "Continue to delete…" |
| Delete account — dialog 2 title | "Are you sure?" |
| Delete account — dialog 2 body | "Your account and all data will be permanently deleted. There is no way to recover it." |
| Delete account — dialog 2 confirm | "Delete Account" |
| Delete account — loading | "Deleting your account…" |
| Delete account — re-auth title | "Sign in required" |
| Delete account — re-auth body | "For security, Apple requires you to sign in again before deleting your account. Sign in with Apple, then return to delete your account." |
| Delete account — unknown error | "Something went wrong. Please try again." |

---

## Accessibility

- All list rows: minimum 44 pt height; tap target spans full row width
- Destructive buttons ("Remove Link", "Delete Account"): red text; additionally labelled with `Semantics(label: '…, destructive action')` for VoiceOver
- Loading dialog: not dismissable; VoiceOver announces "Deleting your account, please wait"
- Privacy settings screen: standard `Semantics` list navigation; section headers announced as headings
- Two-confirmation flow: VoiceOver reads full dialog body before buttons — no information hidden behind an interaction

---

## Open questions for Architect

1. **Profile tab scope:** Should M12 add the full Profile tab shell (4-tab nav) or a lightweight push screen reachable from the overflow? Recommend the former — the navigation doc describes it and adding it now avoids a future migration of destructive actions.
2. **Auth deletion ordering:** ADR must document that Firestore data is deleted before `auth.delete()`. The copy for Step 4B must not promise "nothing was deleted" — it cannot guarantee that for Apple Sign In users if an unexpected early error occurred.
3. **Achievement subcollection path:** The Builder must confirm the Firestore path for `unlocked_achievements` (from Task 24) so account deletion can include it.
