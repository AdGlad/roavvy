# Coding Standards

Standards apply across the whole repo. Platform-specific sections note where conventions differ.

---

## Universal

- **No TODO comments in merged code.** File a task instead.
- **No commented-out code.** Delete it; git history preserves it.
- **No raw strings for country codes.** Use the typed `countryCode` field; never compare freehand strings like `"uk"`.
- **Errors surface at the UI layer only.** Packages throw typed exceptions; repositories catch and re-throw typed domain errors; features catch and convert to UI state.
- **Monetary values in minor units (pence/cents).** Never store or pass floats for money.
- **All dates UTC.** Convert to local time only at the display layer.

---

## Dart / Flutter

### Style
- Follow [Effective Dart](https://dart.dev/effective-dart). `dart format` enforced in CI.
- `flutter_lints` plus any additions in `analysis_options.yaml`. Zero lint warnings in merged code.
- Prefer `final` everywhere; use `var` only when the type is obvious from the right-hand side.

### State Management
- Riverpod. Providers live in the same file or directory as their feature — not in a global `providers/` folder.
- `AsyncNotifier` for async state. `Notifier` for synchronous state. No `StateNotifier`.
- Never expose mutable state directly; expose typed methods that mutate then notify.

### Models
- `freezed` + `json_serializable` in `shared_models`. Run `dart run build_runner build` after changes.
- Immutable value objects. Never mutate a model in place; use `.copyWith()`.

### Error Handling
```dart
// packages: throw typed exceptions
throw CountryResolutionException('coordinates out of range');

// repositories: catch and re-throw as domain errors
throw VisitSaveFailure(cause: e);

// features: convert to UI state, never rethrow to the widget tree
state = AsyncError(VisitSaveFailure(cause: e), st);
```

### Async
- `async`/`await` over raw `Future` chaining.
- CPU-heavy work (scan processing) runs in a background isolate.
- Never `await` inside a `build` method.

---

## TypeScript / Next.js

### Style
- ESLint + Prettier, enforced in CI. Zero lint warnings in merged code.
- `strict: true` in `tsconfig.json`. No `any` without an explanatory comment.
- Named exports preferred over default exports (easier to grep and refactor).

### Server vs Client Components
- Server Components by default. Add `"use client"` only when genuinely needed (interactivity, browser APIs).
- Shopify credentials used only in Server Components or Route Handlers — never in client bundles.
- Firestore reads in Server Components where possible; use listeners only for live data that must update without a page reload.

### Data Validation
- Zod schemas validate all Firestore data on read. Never trust Firestore document shape at runtime.
- Form data validated server-side in Route Handlers, not only client-side.

### Error Handling
- Route Handlers return typed error responses; never let unhandled exceptions reach the Next.js error boundary in production.
- Use `error.tsx` boundaries for segment-level error UI.

---

## Git Conventions

- Branch naming: `feat/short-description`, `fix/short-description`, `chore/short-description`.
- Commit messages: imperative mood, ≤ 72 characters on the subject line. Body explains *why*, not *what*.
- PRs are small and focused. One concern per PR. If a PR touches more than ~400 lines, consider splitting.
- Squash merge to main. Linear history.
