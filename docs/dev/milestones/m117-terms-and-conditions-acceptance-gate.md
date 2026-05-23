# M117 — Terms & Conditions Acceptance Gate

**Status:** Complete (2026-05-23)

## Goal

Display and require acceptance of Roavvy's Terms & Conditions before a user can access the app. Acceptance is persisted per-device via SharedPreferences. Existing users see the gate on first launch after the update. Users can re-read T&Cs from Settings → Privacy & Account at any time.

## Scope in

- `lib/features/legal/terms_service.dart` — SharedPreferences persistence; version-gated acceptance check; `clear()` for account deletion
- `lib/features/legal/terms_screen.dart` — Full T&C text (15 sections); two modes: `requireAccept` (onboarding gate) and read-only (settings)
- `lib/app.dart` — `_OnboardingGate`: watches `termsAcceptedProvider`; auto-pushes `TermsScreen(requireAccept: true)` before onboarding
- `lib/core/providers.dart` — `termsAcceptedProvider` (FutureProvider<bool>)
- `lib/features/settings/privacy_account_screen.dart` — "Terms & Conditions" tile in Legal section
- `lib/features/account/account_deletion_service.dart` — calls `TermsService.clear()` on account deletion

## Scope out

- Server-side T&C version enforcement (client-side only)
- Separate Privacy Policy screen (linked externally)
- Web T&C acceptance flow

## Acceptance Criteria

- [x] New users see T&C screen before onboarding flow
- [x] Cannot proceed without ticking the checkbox and tapping "Accept & Continue"
- [x] Existing users (pre-M117) see T&C gate on first launch after update
- [x] T&C version stored in SharedPreferences; bumping `kCurrentTermsVersion` re-gates all users
- [x] Read-only access from Settings → Privacy & Account → Terms & Conditions
- [x] T&C acceptance cleared on account deletion (forces re-accept on new account)
- [x] `flutter analyze` passes with no new errors

## ADR

ADR-162: Terms & Conditions acceptance gated in `_OnboardingGate` via `termsAcceptedProvider`. Acceptance persisted locally via `TermsService` / SharedPreferences. Version string (`kCurrentTermsVersion`) controls re-prompting. T&C screen has two modes: `requireAccept=true` for the gate, `requireAccept=false` for settings read-only view. Acceptance cleared on account deletion.
