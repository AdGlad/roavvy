// M187 / ADR-180 — server-side commerce kill switch.
//
// createMerchCart and getMerchPrices must refuse with failed-precondition,
// before any network or Firestore work, unless COMMERCE_ENABLED is true.

const mockCollection = jest.fn();
jest.mock('firebase-admin/app', () => ({ initializeApp: jest.fn() }));
jest.mock('firebase-admin/firestore', () => ({
  getFirestore: jest.fn(() => ({ collection: mockCollection })),
  Timestamp: { now: jest.fn() },
}));
jest.mock('firebase-admin/storage', () => ({ getStorage: jest.fn() }));
jest.mock('firebase-functions/v2/https', () => ({
  onCall: jest.fn((a: unknown, b?: Function) => b ?? a),
  onRequest: jest.fn((a: unknown, b?: Function) => b ?? a),
  HttpsError: class HttpsError extends Error {
    constructor(public code: string, message: string) { super(message); }
  },
}));
jest.mock(
  'flag-icons/package.json',
  () => ({ name: 'flag-icons', version: '0.0.0-mock' }),
  { virtual: true }
);
jest.mock('fs');
jest.mock('../imageGen', () => ({ generateFlagGrid: jest.fn() }));
jest.mock('dotenv', () => ({ config: jest.fn() }));
jest.mock('../dailyChallenge', () => ({
  scheduleDailyChallenge: jest.fn(),
  getDailyChallenge: jest.fn(),
}));

const mockFetch = jest.fn();
global.fetch = mockFetch;

import { assertCommerceEnabled } from '../commerceGate';
import { createMerchCart, getMerchPrices } from '../index';

type Handler = (req: unknown) => Promise<unknown>;
const call = (fn: unknown, data: unknown) =>
  (fn as Handler)({ data, auth: { uid: 'u1' } });

describe('COMMERCE_ENABLED off', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    process.env['COMMERCE_ENABLED'] = 'false';
  });

  test('assertCommerceEnabled throws failed-precondition', () => {
    expect(() => assertCommerceEnabled()).toThrow(
      expect.objectContaining({ code: 'failed-precondition' }),
    );
  });

  test('getMerchPrices refuses before calling Shopify', async () => {
    await expect(call(getMerchPrices, { countryCode: 'GB' })).rejects
      .toMatchObject({ code: 'failed-precondition' });
    expect(mockFetch).not.toHaveBeenCalled();
  });

  test('createMerchCart refuses before any Firestore or network work', async () => {
    await expect(call(createMerchCart, { variantId: '1' })).rejects
      .toMatchObject({ code: 'failed-precondition' });
    expect(mockFetch).not.toHaveBeenCalled();
    expect(mockCollection).not.toHaveBeenCalled();
  });
});

describe('COMMERCE_ENABLED on', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    process.env['COMMERCE_ENABLED'] = 'true';
  });

  test('assertCommerceEnabled passes', () => {
    expect(() => assertCommerceEnabled()).not.toThrow();
  });

  test('getMerchPrices gets past the gate', async () => {
    // No storefront config in tests, so it fails later, with a different code.
    delete process.env['SHOPIFY_STOREFRONT_TOKEN'];
    await expect(call(getMerchPrices, { countryCode: 'GB' })).rejects
      .toMatchObject({ code: 'internal' });
  });
});

describe('COMMERCE_ENABLED unset', () => {
  test('defaults to off', () => {
    delete process.env['COMMERCE_ENABLED'];
    expect(() => assertCommerceEnabled()).toThrow(
      expect.objectContaining({ code: 'failed-precondition' }),
    );
  });
});
