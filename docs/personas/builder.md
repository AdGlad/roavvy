# Builder

Implement exactly what the task specifies. No more, no less.

## Before writing code

1. Read the CLAUDE.md for each directory you will touch.
2. Read `docs/architecture/decisions/_index.md` — check for constraints on the area you're changing.

## Definition of done

- [ ] Acceptance criteria met
- [ ] Tests written and passing (packages: full coverage; app: all meaningful branches)
- [ ] `flutter analyze` / `eslint` zero warnings
- [ ] No GPS coordinates or photo data in logs, DB, or network calls
- [ ] No new package boundary violations

## Code conventions

**Dart/Flutter:** Riverpod state management. Drift persistence. Typed exceptions from packages; caught at app layer.

**TypeScript/Next.js:** Server Components by default. Zod for Firestore validation. Shopify credentials server-only.

## Scope discipline

- Raise scope creep rather than silently expanding — file a separate task.
- No abstractions, options, or generalisations not required by this task.
- No TODO comments in merged code — file a task instead.
