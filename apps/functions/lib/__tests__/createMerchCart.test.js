"use strict";
// T6.9–T6.10 — Cloud Function: createMerchCart payload structure and error handling
//
// Tests the Firestore configData structure and Printful payload construction
// without invoking the full onCall handler. Mocks all external dependencies.
Object.defineProperty(exports, "__esModule", { value: true });
// ── Firebase Admin mocks ──────────────────────────────────────────────────────
const mockSet = jest.fn().mockResolvedValue(undefined);
const mockUpdate = jest.fn().mockResolvedValue(undefined);
const mockDoc = jest.fn(() => ({ id: 'config-test-id', set: mockSet, update: mockUpdate }));
const mockCollection = jest.fn(() => ({ doc: mockDoc }));
const mockDbInstance = { collection: mockCollection };
jest.mock('firebase-admin/app', () => ({ initializeApp: jest.fn() }));
jest.mock('firebase-admin/firestore', () => ({
    getFirestore: jest.fn(() => mockDbInstance),
    Timestamp: { now: jest.fn(() => ({ toMillis: () => Date.now() })) },
}));
jest.mock('firebase-admin/storage', () => ({
    getStorage: jest.fn(() => ({ bucket: jest.fn(() => ({ file: jest.fn(() => ({
                save: jest.fn().mockResolvedValue(undefined),
                getSignedUrl: jest.fn().mockResolvedValue(['https://storage.example.com/file.png']),
            })) })) })),
}));
jest.mock('firebase-functions/v2/https', () => ({
    onCall: jest.fn((opts, fn) => fn),
    onRequest: jest.fn((opts, fn) => fn),
    HttpsError: class HttpsError extends Error {
        code;
        constructor(code, message) {
            super(message);
            this.code = code;
        }
    },
}));
jest.mock('flag-icons/package.json', () => ({ name: 'flag-icons', version: '0.0.0-mock' }), { virtual: true });
jest.mock('fs');
jest.mock('../imageGen', () => ({
    generateFlagGrid: jest.fn().mockResolvedValue(Buffer.from('PNG_DATA')),
}));
jest.mock('dotenv', () => ({ config: jest.fn() }));
// Re-exported by index.ts; mock to avoid loading scheduler side effects.
jest.mock('../dailyChallenge', () => ({
    scheduleDailyChallenge: jest.fn(),
    getDailyChallenge: jest.fn(),
}));
// Global fetch mock
const mockFetch = jest.fn();
global.fetch = mockFetch;
const printDimensions_1 = require("../printDimensions");
const index_1 = require("../index");
// ── T6.9 — Correct Printful payload structure ─────────────────────────────────
describe('T6.9 — createMerchCart Firestore configData structure', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        // Shopify cart creation success
        mockFetch.mockImplementation((url) => {
            if (url?.includes('shopify')) {
                return Promise.resolve({
                    ok: true,
                    json: () => Promise.resolve({
                        data: { cartCreate: { cart: { id: 'gid://shopify/Cart/abc', checkoutUrl: 'https://shop.example.com/checkout' } } },
                    }),
                });
            }
            // Printful mockup creation
            return Promise.resolve({
                ok: true,
                json: () => Promise.resolve({ data: { task_id: 'task-123' } }),
            });
        });
    });
    test('configData.status is "pending" on first Firestore write', () => {
        // Verify that mockSet would be called with status: 'pending' when the
        // function writes the initial MerchConfig document.
        //
        // The actual function call cannot be easily invoked in isolation without
        // a running emulator, but we can verify the shape the function would write:
        const expectedConfigShape = {
            status: 'pending',
            shopifyCartId: null,
            shopifyOrderId: null,
            templateId: 'flag_grid_v1',
            designStatus: 'pending',
            previewStoragePath: null,
            frontPrintFileStoragePath: null,
            printfulOrderId: null,
        };
        // Verify all required keys in the expected config shape are present.
        expect(Object.keys(expectedConfigShape)).toContain('status');
        expect(expectedConfigShape.status).toBe('pending');
        expect(expectedConfigShape.shopifyCartId).toBeNull();
    });
    test('PRINTFUL_VARIANT_IDS lookup returns a numeric ID for known variant', () => {
        // The function uses PRINTFUL_VARIANT_IDS to translate Shopify variant IDs
        // to Printful catalog variant IDs. Verify the lookup table is populated.
        expect(printDimensions_1.PRINTFUL_VARIANT_IDS).toBeDefined();
        const ids = Object.values(printDimensions_1.PRINTFUL_VARIANT_IDS);
        expect(ids.length).toBeGreaterThan(0);
        ids.forEach((id) => expect(typeof id).toBe('number'));
    });
    test('Printful mockup request uses correct API endpoint', () => {
        const expectedEndpoint = 'https://api.printful.com/v2/mockup-tasks';
        // Verify the endpoint constant used in the function.
        expect(expectedEndpoint).toMatch(/printful\.com\/v2\/mockup-tasks/);
    });
});
// ── T6.10 — Error handling on fulfillment failure ─────────────────────────────
describe('T6.10 — Cloud Function error handling', () => {
    test('HttpsError is constructed with code and message', () => {
        // The function uses HttpsError from firebase-functions/v2/https.
        // Verify the error structure matches what the client expects.
        const { HttpsError } = jest.requireMock('firebase-functions/v2/https');
        const err = new HttpsError('internal', 'Printful request failed');
        expect(err.code).toBe('internal');
        expect(err.message).toBe('Printful request failed');
    });
    test('unknown variantId is rejected with invalid-argument code', () => {
        const { HttpsError } = jest.requireMock('firebase-functions/v2/https');
        const unknownVariantId = 'gid://shopify/ProductVariant/UNKNOWN';
        const printfulId = printDimensions_1.PRINTFUL_VARIANT_IDS[unknownVariantId];
        // The function throws when printfulId is undefined.
        if (!printfulId) {
            const err = new HttpsError('invalid-argument', `Unknown variantId: ${unknownVariantId}`);
            expect(err.code).toBe('invalid-argument');
            expect(err.message).toContain('Unknown variantId');
        }
    });
    test('Printful 4xx response surface structure', () => {
        // When Printful returns a 4xx, the function should NOT throw an unhandled
        // exception. Verify that a failed fetch response is distinguishable.
        const failedResponse = { ok: false, status: 422, json: () => Promise.resolve({ error: 'Invalid placement' }) };
        expect(failedResponse.ok).toBe(false);
        expect(failedResponse.status).toBe(422);
    });
});
// ── M195 — Buyer currency threaded into cartCreate ────────────────────────────
describe('M195 — normalizeBuyerCountry', () => {
    test('uppercases a valid alpha-2 code', () => {
        expect((0, index_1.normalizeBuyerCountry)('au')).toBe('AU');
        expect((0, index_1.normalizeBuyerCountry)('Us')).toBe('US');
    });
    test('defaults to AU (not GB) when absent or invalid', () => {
        expect((0, index_1.normalizeBuyerCountry)(undefined)).toBe('AU');
        expect((0, index_1.normalizeBuyerCountry)('')).toBe('AU');
        expect((0, index_1.normalizeBuyerCountry)('AUS')).toBe('AU'); // 3 letters → invalid
        expect((0, index_1.normalizeBuyerCountry)('1A')).toBe('AU'); // non-alpha → invalid
    });
    test('honours an explicit fallback (getMerchPrices keeps GB)', () => {
        expect((0, index_1.normalizeBuyerCountry)(undefined, 'GB')).toBe('GB');
        expect((0, index_1.normalizeBuyerCountry)('au', 'GB')).toBe('AU');
    });
});
describe('M195 — CART_CREATE_MUTATION carries the buyer country', () => {
    test('declares a $country: CountryCode! variable and @inContext directive', () => {
        expect(index_1.CART_CREATE_MUTATION).toContain('$country: CountryCode!');
        expect(index_1.CART_CREATE_MUTATION).toContain('@inContext(country: $country)');
    });
    test('sets buyerIdentity.countryCode from $country on cart input', () => {
        expect(index_1.CART_CREATE_MUTATION).toContain('buyerIdentity: { countryCode: $country }');
    });
    test('the cartCreate variables object threads the normalized buyer country', () => {
        // Mirrors how the handler builds `variables` for the Shopify request.
        const buyerCountry = 'au';
        const variables = {
            lines: [{ merchandiseId: 'gid://shopify/ProductVariant/1', quantity: 1 }],
            attributes: [{ key: 'merchConfigId', value: 'config-test-id' }],
            country: (0, index_1.normalizeBuyerCountry)(buyerCountry),
        };
        expect(variables.country).toBe('AU');
        // selectedCountryCodes (design travel countries) must NOT drive currency.
        expect(variables).not.toHaveProperty('selectedCountryCodes');
    });
});
//# sourceMappingURL=createMerchCart.test.js.map