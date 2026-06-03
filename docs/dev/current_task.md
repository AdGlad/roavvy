# Current Task

**Milestone:** T6 — Backend Emulator Tests
**Status:** Complete — 2026-06-03

Delivered:
- firestore.rules: replaced wildcard with specific subcollection rules; inferred_visits has field allowlist (ADR-002)
- firebase.json: emulator config added (auth:9099, firestore:8080, functions:5001)
- test/emulator/emulator_test_setup.dart: emulator connection helpers
- test/emulator/auth_flows_test.dart: T6.6–T6.8 (18 tests passing)
- test/emulator/cloud_functions_test.dart: T6.9–T6.10 client-side (5 tests passing)
- test/firestore-rules/firestore.rules.test.js: T6.1–T6.5 Node.js rules tests (run: npm test in test/firestore-rules/)
- apps/functions/src/__tests__/createMerchCart.test.ts: T6.9–T6.10 TS tests (6 tests, run: npm test in apps/functions)
- Total: 1294 Flutter tests + 25 Functions tests passing

## Next milestone: T7 (see backlog)
