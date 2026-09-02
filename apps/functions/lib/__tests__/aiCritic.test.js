"use strict";
// M202 — AI design critic (critiqueDesigns): request shape, data policy
// (thumbnails not photos), cache-key logic, and response parsing.
//
// Pure helpers are unit-tested directly; the onCall handler itself needs an
// emulator, so we assert the contract shape the client/server agree on.
Object.defineProperty(exports, "__esModule", { value: true });
// firebase-functions/onCall is mocked to return the raw handler (mirrors the
// createMerchCart test style) so importing the module has no side effects.
jest.mock('firebase-functions/v2/https', () => ({
    onCall: jest.fn((_opts, fn) => fn),
}));
jest.mock('firebase-admin/firestore', () => ({
    getFirestore: jest.fn(),
    Timestamp: { now: jest.fn(() => ({ toMillis: () => 0 })) },
}));
// The model client is never constructed in these tests (no cache miss path is
// exercised), but mock it so the import graph loads cleanly under Jest.
jest.mock('@google/genai', () => ({ GoogleGenAI: jest.fn() }));
const aiCritic_1 = require("../aiCritic");
const validInput = {
    paramsHash: 'grid|allTime|FR,DE|packedRow|none||3|balanced|0.200|entryExit|l|medium|Black|0',
    thumbnailBase64: 'iVBORw0KGgoAAAANS', // truncated PNG header (thumbnail only)
    template: 'grid',
    countryCount: 2,
    shirtColour: 'Black',
};
describe('critiqueDesigns — request shape & data policy', () => {
    test('a valid input carries a thumbnail + genome metadata, never a photo', () => {
        expect((0, aiCritic_1.isValidCritiqueInput)(validInput)).toBe(true);
        // Data policy (§16.6): thumbnail only — the contract has no photo/GPS field.
        expect(validInput).toHaveProperty('thumbnailBase64');
        expect(validInput).not.toHaveProperty('photo');
        expect(validInput).not.toHaveProperty('photoBase64');
        expect(validInput).not.toHaveProperty('imageAssetId');
        expect(validInput).not.toHaveProperty('latitude');
        expect(validInput).not.toHaveProperty('longitude');
    });
    test('rejects an input missing the thumbnail (nothing to critique)', () => {
        const noThumb = { ...validInput, thumbnailBase64: '' };
        expect((0, aiCritic_1.isValidCritiqueInput)(noThumb)).toBe(false);
    });
    test('rejects non-object / malformed inputs', () => {
        expect((0, aiCritic_1.isValidCritiqueInput)(null)).toBe(false);
        expect((0, aiCritic_1.isValidCritiqueInput)('nope')).toBe(false);
        expect((0, aiCritic_1.isValidCritiqueInput)({ paramsHash: 'x' })).toBe(false);
        expect((0, aiCritic_1.isValidCritiqueInput)({ ...validInput, countryCount: '2' })).toBe(false);
    });
});
describe('cache-key logic', () => {
    test('keys off the params-hash and pins the model version', () => {
        const key = (0, aiCritic_1.cacheKey)(validInput.paramsHash);
        expect(key.startsWith(validInput.paramsHash)).toBe(true);
        expect(key).toContain('__');
        expect(key).toMatch(/critic-v\d+$/); // model/prompt version tag
    });
    test('distinct designs → distinct cache keys; same design → stable key', () => {
        expect((0, aiCritic_1.cacheKey)('hash-a')).not.toBe((0, aiCritic_1.cacheKey)('hash-b'));
        expect((0, aiCritic_1.cacheKey)('hash-a')).toBe((0, aiCritic_1.cacheKey)('hash-a'));
    });
});
describe('parseCritique — tolerant model-reply parsing', () => {
    test('parses a well-formed JSON array into an index→verdict map', () => {
        const text = JSON.stringify([
            { index: 0, score: 0.9, hints: ['more whitespace'] },
            { index: 1, score: 0.4, hints: [] },
        ]);
        const map = (0, aiCritic_1.parseCritique)(text, 2);
        expect(map.get(0)?.aestheticScore).toBe(0.9);
        expect(map.get(0)?.hints).toEqual(['more whitespace']);
        expect(map.get(1)?.aestheticScore).toBe(0.4);
    });
    test('strips markdown fences before parsing', () => {
        const text = '```json\n[{"index":0,"score":0.75}]\n```';
        expect((0, aiCritic_1.parseCritique)(text, 1).get(0)?.aestheticScore).toBe(0.75);
    });
    test('clamps out-of-range scores and drops out-of-range indices', () => {
        const text = JSON.stringify([
            { index: 0, score: 1.8 },
            { index: 5, score: 0.5 }, // index >= count → dropped
        ]);
        const map = (0, aiCritic_1.parseCritique)(text, 1);
        expect(map.get(0)?.aestheticScore).toBe(1);
        expect(map.has(5)).toBe(false);
    });
    test('returns an empty map on malformed JSON (never throws)', () => {
        expect((0, aiCritic_1.parseCritique)('not json at all', 3).size).toBe(0);
        expect((0, aiCritic_1.parseCritique)('{"not":"an array"}', 3).size).toBe(0);
    });
});
describe('neutral fallback', () => {
    test('neutralResult is a no-op re-rank signal (0.5, no hints)', () => {
        expect((0, aiCritic_1.neutralResult)(2)).toEqual({ index: 2, aestheticScore: 0.5, hints: [] });
    });
    test('clamp01 maps non-finite to neutral 0.5', () => {
        expect((0, aiCritic_1.clamp01)(Number.NaN)).toBe(0.5);
        expect((0, aiCritic_1.clamp01)(-1)).toBe(0);
        expect((0, aiCritic_1.clamp01)(2)).toBe(1);
        expect((0, aiCritic_1.clamp01)(0.3)).toBe(0.3);
    });
});
//# sourceMappingURL=aiCritic.test.js.map