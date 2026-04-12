# Roavvy — Project Context & Guidelines

Roavvy is a privacy-first travel discovery platform that scans a user's photo library on-device to detect visited countries. It builds a world travel map, tracks achievements, and enables sharing without ever uploading the user's photos.

## Project Overview

- **Core Mission:** Turn photos into a travel record while maintaining absolute privacy (GPS data is resolved on-device and discarded).
- **Architecture:** Monorepo with a Flutter (iOS-first) mobile app, a Next.js web app, and Firebase backend.
- **Privacy Perimeter:** Coordinate resolution happens in `packages/country_lookup` (offline, zero-network).

## Repository Structure

- `apps/mobile_flutter/`: Main app (Flutter + Swift PhotoKit bridge).
- `apps/web_nextjs/`: Web viewer, public sharing pages, and merchandise (Next.js 14+).
- `apps/functions/`: Firebase Functions (image generation, Shopify integration).
- `packages/shared_models/`: Canonical domain models (Dart).
- `packages/country_lookup/`: Offline GPS-to-ISO-code resolution (Dart).
- `packages/region_lookup/`: Offline GPS-to-Admin1-region resolution (Dart).
- `docs/`: Comprehensive architecture (ADRs), engineering, and product docs.

## Building and Running

### Mobile (Flutter)
- **Setup:** `cd apps/mobile_flutter && flutter pub get`
- **Run:** `flutter run` (Requires an iOS device/simulator for PhotoKit features)
- **Test:** `flutter test`
- **Build Runner:** `dart run build_runner build` (for Drift/Freezed)

### Web (Next.js)
- **Setup:** `cd apps/web_nextjs && npm install`
- **Dev:** `npm run dev`
- **Test:** `npm run test`
- **Build:** `npm run build`

### Backend (Firebase Functions)
- **Setup:** `cd apps/functions && npm install`
- **Build:** `npm run build`
- **Serve (Emulators):** `firebase emulators:start`
- **Deploy:** `firebase deploy --only functions`

### Packages
- **Shared Models:** `cd packages/shared_models && dart pub get && dart run build_runner build`
- **Country Lookup:** `cd packages/country_lookup && dart pub get`

## Development Conventions

### Persona Workflow (Mandatory)
All development follows the workflow defined in `CLAUDE.md`:
1.  **Planner:** Scopes the task in `docs/dev/current_task.md`.
2.  **Architect:** Validates the plan and writes ADRs in `docs/architecture/decisions.md`.
3.  **Builder:** Implements the feature with tests.
4.  **Reviewer:** Final validation for privacy and code quality.

### Coding Standards
- **No TODOs or Commented Code:** File a task instead; let git handle history.
- **Dates:** Always use **UTC**; convert to local time only for display.
- **Country Codes:** Always use **ISO 3166-1 alpha-2** (e.g., `GB`, `US`).
- **State Management:** Riverpod (Flutter) and Server Components (Next.js).
- **Error Handling:** Surface errors at the UI layer only; throw typed exceptions in packages/repositories.

### Testing Strategy
- **Unit Tests:** Mandatory for all public functions in packages and repository methods in apps.
- **Widget/Component Tests:** Required for non-trivial UI states (loading, error, progress).
- **Privacy Tests:** Must verify that GPS coordinates and asset IDs are never stored or synced.

## Key References
- `docs/architecture/decisions.md`: All Architecture Decision Records (ADRs).
- `docs/dev/current_state.md`: Current implementation status and milestones.
- `docs/engineering/coding_standards.md`: Detailed style guides for Dart and TypeScript.
- `docs/engineering/testing_strategy.md`: Comprehensive test requirements.
