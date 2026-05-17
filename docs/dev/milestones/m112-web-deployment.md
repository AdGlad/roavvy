# Milestone 112: Roavvy Web & Landing Page

## Goal
Deploy the Roavvy website at `www.roavvy.com` using Firebase Hosting, providing a public landing page and a web-compatible version of the authenticated app experience.

## Tasks
1. [x] **Research & Strategy**
   - [x] Audit dependencies for web compatibility (e.g., `drift`, `photo_manager`).
   - [x] Define routing strategy (`/` landing, `/app` authenticated).
   - [x] Draft ADR-153: Web Deployment & Routing Strategy.
2. [x] **Flutter Web Configuration**
   - [x] Enable web support: `flutter create --platforms web .`.
   - [x] Configure `firebase_options.dart` with web credentials.
   - [x] Fix/guard mobile-only code paths (`photo_manager`, `notification_service`).
3. [x] **Navigation & Routing**
   - [x] Implement `go_router` or similar for URL-based navigation.
   - [x] Route `/` to `LandingPage`.
   - [x] Route `/app` to `MainShell` (authenticated).
   - [x] Implement auth guard for `/app`.
4. [x] **Public Landing Page**
   - [x] Build `LandingPage` widget with hero, features, privacy, and CTAs.
   - [x] Ensure responsive design.
5. [x] **Firebase Hosting**
   - [x] Configure `firebase.json` with hosting settings and rewrites.
   - [x] Build and deploy: `flutter build web` -> `firebase deploy`.
6. [x] **Domain & Final Polish**
   - [x] Prepare DNS record documentation for `www.roavvy.com`.
   - [x] Final quality checks on web and mobile.

## Acceptance Criteria
- `www.roavvy.com` serves the landing page to public users.
- Users can sign in/up and access their map/achievements/merch on web.
- Photo scanning on web shows a friendly "Mobile App Only" message.
- Mobile app remains fully functional.
- Direct navigation to `/app` (after login) works and persists on refresh.

## Acceptance Criteria
- `www.roavvy.com` serves the landing page to public users.
- Users can sign in/up and access their map/achievements/merch on web.
- Photo scanning on web shows a friendly "Mobile App Only" message.
- Mobile app remains fully functional.
- Direct navigation to `/app` (after login) works and persists on refresh.
