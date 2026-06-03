// T6.1–T6.5 — Firestore security rules tests
//
// Uses @firebase/rules-unit-testing which loads the rules file and runs them
// in a sandboxed environment. Requires the Firebase Emulator to be running:
//
//   firebase emulators:start --only firestore
//
// Run tests:
//   cd test/firestore-rules && npm install && npm test

const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { readFileSync } = require('fs');
const { resolve } = require('path');

const PROJECT_ID = 'roavvy-test';

let testEnv;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync(resolve(__dirname, '../../firestore.rules'), 'utf8'),
      host: 'localhost',
      port: 8080,
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

// ── T6.1 — Authenticated user writes permitted fields only ────────────────────

describe('T6.1 — Authenticated user writes permitted fields only', () => {
  test('authenticated user can write permitted inferred_visits fields', async () => {
    const db = testEnv.authenticatedContext('user-a').firestore();
    await assertSucceeds(
      db
        .collection('users')
        .doc('user-a')
        .collection('inferred_visits')
        .doc('GB')
        .set({
          inferredAt: '2024-06-01T00:00:00.000Z',
          photoCount: 10,
          firstSeen: '2024-03-01T00:00:00.000Z',
          lastSeen: '2024-06-01T00:00:00.000Z',
          syncedAt: '2024-06-01T12:00:00.000Z',
        })
    );
  });

  test('authenticated user can write user_added country', async () => {
    const db = testEnv.authenticatedContext('user-a').firestore();
    await assertSucceeds(
      db
        .collection('users')
        .doc('user-a')
        .collection('user_added')
        .doc('JP')
        .set({ addedAt: '2024-01-15T00:00:00.000Z', syncedAt: '2024-01-15T12:00:00.000Z' })
    );
  });

  test('authenticated user can write to their own share card', async () => {
    const db = testEnv.authenticatedContext('user-a').firestore();
    await assertSucceeds(
      db
        .collection('sharedTravelCards')
        .doc('token-abc')
        .set({ uid: 'user-a', countryCode: 'GB', createdAt: '2024-01-01T00:00:00.000Z' })
    );
  });
});

// ── T6.2 — Unauthenticated user cannot write any document ────────────────────

describe('T6.2 — Unauthenticated user cannot write any document', () => {
  test('unauthenticated write to inferred_visits is rejected', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(
      db
        .collection('users')
        .doc('user-a')
        .collection('inferred_visits')
        .doc('GB')
        .set({ inferredAt: '2024-06-01T00:00:00.000Z', photoCount: 5 })
    );
  });

  test('unauthenticated write to unlocked_achievements is rejected', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(
      db
        .collection('users')
        .doc('user-a')
        .collection('unlocked_achievements')
        .doc('countries_1')
        .set({ unlockedAt: '2024-01-01T00:00:00.000Z' })
    );
  });

  test('unauthenticated write to daily_challenge is rejected', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(
      db.collection('daily_challenge').doc('2024-06-01').set({ clues: [] })
    );
  });

  test('unauthenticated read of daily_challenge is rejected', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(
      db.collection('daily_challenge').doc('2024-06-01').get()
    );
  });

  test('unauthenticated read of sharedTravelCards succeeds (public)', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    // Public read is allowed per ADR-041.
    await assertSucceeds(
      db.collection('sharedTravelCards').doc('public-token').get()
    );
  });
});

// ── T6.3 — Authenticated user cannot access another user's data ──────────────

describe('T6.3 — Cross-user data isolation', () => {
  test("user A cannot write to user B's inferred_visits", async () => {
    const dbA = testEnv.authenticatedContext('user-a').firestore();
    await assertFails(
      dbA
        .collection('users')
        .doc('user-b')
        .collection('inferred_visits')
        .doc('GB')
        .set({ inferredAt: '2024-06-01T00:00:00.000Z', photoCount: 3 })
    );
  });

  test("user A cannot read user B's inferred_visits", async () => {
    const dbA = testEnv.authenticatedContext('user-a').firestore();
    await assertFails(
      dbA
        .collection('users')
        .doc('user-b')
        .collection('inferred_visits')
        .get()
    );
  });

  test("user A cannot write to user B's unlocked_achievements", async () => {
    const dbA = testEnv.authenticatedContext('user-a').firestore();
    await assertFails(
      dbA
        .collection('users')
        .doc('user-b')
        .collection('unlocked_achievements')
        .doc('countries_1')
        .set({ unlockedAt: '2024-01-01T00:00:00.000Z' })
    );
  });
});

// ── T6.4 — Share token: public read, non-owner write rejected ────────────────

describe('T6.4 — Share token access control', () => {
  test('unauthenticated read of share card succeeds (public)', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertSucceeds(
      db.collection('sharedTravelCards').doc('some-token').get()
    );
  });

  test("user A (non-owner) cannot write to user B's share card", async () => {
    const dbA = testEnv.authenticatedContext('user-a').firestore();
    await assertFails(
      dbA
        .collection('sharedTravelCards')
        .doc('token-b')
        .set({ uid: 'user-b', countryCode: 'FR' })
    );
  });

  test('token owner can write their own share card', async () => {
    const db = testEnv.authenticatedContext('user-a').firestore();
    await assertSucceeds(
      db
        .collection('sharedTravelCards')
        .doc('token-a')
        .set({ uid: 'user-a', countryCode: 'GB', createdAt: '2024-01-01T00:00:00.000Z' })
    );
  });
});

// ── T6.5 — Visit sync field guard (ADR-002, privacy constraint) ──────────────

describe('T6.5 — inferred_visits field guard (ADR-002)', () => {
  const BASE_DOC = {
    inferredAt: '2024-06-01T00:00:00.000Z',
    photoCount: 5,
    firstSeen: '2024-03-01T00:00:00.000Z',
    lastSeen: '2024-06-01T00:00:00.000Z',
    syncedAt: '2024-06-01T12:00:00.000Z',
  };

  test('document with only permitted fields is accepted', async () => {
    const db = testEnv.authenticatedContext('user-a').firestore();
    await assertSucceeds(
      db
        .collection('users')
        .doc('user-a')
        .collection('inferred_visits')
        .doc('US')
        .set(BASE_DOC)
    );
  });

  test('document with GPS latitude field is rejected', async () => {
    const db = testEnv.authenticatedContext('user-a').firestore();
    await assertFails(
      db
        .collection('users')
        .doc('user-a')
        .collection('inferred_visits')
        .doc('US')
        .set({ ...BASE_DOC, latitude: 51.5 })
    );
  });

  test('document with GPS longitude field is rejected', async () => {
    const db = testEnv.authenticatedContext('user-a').firestore();
    await assertFails(
      db
        .collection('users')
        .doc('user-a')
        .collection('inferred_visits')
        .doc('US')
        .set({ ...BASE_DOC, longitude: -0.1 })
    );
  });

  test('document with lat field is rejected', async () => {
    const db = testEnv.authenticatedContext('user-a').firestore();
    await assertFails(
      db
        .collection('users')
        .doc('user-a')
        .collection('inferred_visits')
        .doc('US')
        .set({ ...BASE_DOC, lat: 51.5, lng: -0.1 })
    );
  });

  test('document with assetId field is rejected', async () => {
    const db = testEnv.authenticatedContext('user-a').firestore();
    await assertFails(
      db
        .collection('users')
        .doc('user-a')
        .collection('inferred_visits')
        .doc('US')
        .set({ ...BASE_DOC, assetId: 'PHAsset/1234' })
    );
  });

  test('document with localIdentifier field is rejected', async () => {
    const db = testEnv.authenticatedContext('user-a').firestore();
    await assertFails(
      db
        .collection('users')
        .doc('user-a')
        .collection('inferred_visits')
        .doc('US')
        .set({ ...BASE_DOC, localIdentifier: 'ABC-DEF' })
    );
  });

  test('document with filename field is rejected', async () => {
    const db = testEnv.authenticatedContext('user-a').firestore();
    await assertFails(
      db
        .collection('users')
        .doc('user-a')
        .collection('inferred_visits')
        .doc('US')
        .set({ ...BASE_DOC, filename: 'IMG_0001.jpg' })
    );
  });
});
