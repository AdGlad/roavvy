"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.critiqueDesigns = void 0;
exports.clamp01 = clamp01;
exports.cacheKey = cacheKey;
exports.neutralResult = neutralResult;
exports.isValidCritiqueInput = isValidCritiqueInput;
exports.parseCritique = parseCritique;
const firestore_1 = require("firebase-admin/firestore");
const https_1 = require("firebase-functions/v2/https");
const genai_1 = require("@google/genai");
// ── Config ──────────────────────────────────────────────────────────────────
/** Vision-capable Gemini model (same family already used by dailyChallenge). */
const GEMINI_MODEL = 'gemini-2.5-flash';
/**
 * Cache/version tag. Bumped when the model or prompt changes so stale critiques
 * are naturally superseded (architecture §10: "AI critique … invalidation:
 * model change"). Forms part of the params-hash cache key.
 */
const MODEL_VERSION = 'gemini-2.5-flash-critic-v1';
/** Hard cap on designs critiqued per call (architecture §16: exactly 3). */
const MAX_DESIGNS = 3;
/**
 * Strict server-side model timeout. The client enforces its own (tighter)
 * budget; this is a backstop so a hung model call never holds the function
 * open. On timeout we return neutral scores (a no-op re-rank).
 */
const MODEL_TIMEOUT_MS = 6000;
/** Firestore collection holding cached critiques (small docs, keyed by hash). */
const CACHE_COLLECTION = 'design_critiques';
// ── Pure helpers (exported for unit tests) ────────────────────────────────────
/** Clamps a number into [0, 1]; non-finite → 0.5 (neutral). */
function clamp01(n) {
    if (!Number.isFinite(n))
        return 0.5;
    return Math.min(1, Math.max(0, n));
}
/**
 * Cache key for a design: its stable `DesignParams.contentHash` plus the model
 * version, so a model/prompt change transparently invalidates old entries.
 */
function cacheKey(paramsHash) {
    return `${paramsHash}__${MODEL_VERSION}`;
}
/** Neutral verdict — scores 0.5 with no hints so re-ranking is a no-op. */
function neutralResult(index) {
    return { index, aestheticScore: 0.5, hints: [] };
}
/**
 * Validates one design input. Enforces the data policy by construction: only a
 * base64 thumbnail + genome metadata are accepted — there is no photo/GPS field
 * in [DesignCritiqueInput], and inputs missing the thumbnail are rejected.
 */
function isValidCritiqueInput(d) {
    if (!d || typeof d !== 'object')
        return false;
    const o = d;
    return (typeof o.paramsHash === 'string' &&
        o.paramsHash.length > 0 &&
        typeof o.thumbnailBase64 === 'string' &&
        o.thumbnailBase64.length > 0 &&
        typeof o.template === 'string' &&
        typeof o.countryCount === 'number' &&
        typeof o.shirtColour === 'string');
}
/**
 * Parses the model's JSON reply into a map of LOCAL design index → verdict.
 * Tolerant: strips markdown fences, skips malformed entries, clamps scores, and
 * keeps only string hints. Returns an empty map on any parse failure (caller
 * neutral-fills), so a bad model response can never throw.
 */
function parseCritique(text, count) {
    const out = new Map();
    const cleaned = text
        .replace(/^```(?:json)?\n?/m, '')
        .replace(/\n?```$/m, '')
        .trim();
    let parsed;
    try {
        parsed = JSON.parse(cleaned);
    }
    catch {
        return out;
    }
    if (!Array.isArray(parsed))
        return out;
    for (const item of parsed) {
        if (!item || typeof item !== 'object')
            continue;
        const o = item;
        const idx = o.index;
        const score = typeof o.score === 'number' ? o.score : o.aestheticScore;
        if (typeof idx !== 'number' || idx < 0 || idx >= count)
            continue;
        if (typeof score !== 'number')
            continue;
        const hints = Array.isArray(o.hints)
            ? o.hints.filter((h) => typeof h === 'string').slice(0, 3)
            : [];
        out.set(idx, { index: idx, aestheticScore: clamp01(score), hints });
    }
    return out;
}
/** Rejects a promise after [ms] with a `timeout` error. */
function withTimeout(p, ms) {
    return Promise.race([
        p,
        new Promise((_, reject) => setTimeout(() => reject(new Error('critique timeout')), ms)),
    ]);
}
// ── Model call ────────────────────────────────────────────────────────────────
/**
 * Builds the multimodal request: one instruction block followed by, per design,
 * a metadata line then its thumbnail image. NO photos — only rendered design
 * thumbnails and genome metadata are ever attached.
 */
function buildContents(designs) {
    const instructions = `You are an expert graphic design art director reviewing printed t-shirt ` +
        `designs made from a traveller's visited countries. You are shown ${designs.length} ` +
        `design thumbnail(s), each already composited on its shirt colour. Judge each ` +
        `on graphic-design merit: balance, contrast, visual hierarchy, whitespace, ` +
        `colour harmony, alignment, and legibility at print size. Reward clean, ` +
        `confident, printable designs; penalise cramped, muddy, or low-contrast ones.\n\n` +
        `Return ONLY a JSON array (no markdown, no prose), one object per design:\n` +
        `[{"index":0,"score":0.0-1.0,"hints":["short nudge","short nudge"]}, ...]\n` +
        `- score: aesthetic quality in [0,1].\n` +
        `- hints: 0-2 SHORT genome-level nudges from this set exactly when useful: ` +
        `"more whitespace", "less busy", "warmer palette", "cooler palette", ` +
        `"stronger contrast", "bigger focal point", "portrait orientation". Omit if none.`;
    const parts = [{ text: instructions }];
    designs.forEach((d, i) => {
        parts.push({
            text: `Design ${i}: template=${d.template}, countries=${d.countryCount}, shirt=${d.shirtColour}`,
        });
        parts.push({
            inlineData: { mimeType: 'image/png', data: d.thumbnailBase64 },
        });
    });
    return [{ role: 'user', parts }];
}
/**
 * Single batched vision call over the (cache-missed) designs. Returns a map of
 * LOCAL index → verdict on success, or null on any error/timeout (caller then
 * neutral-fills and skips caching so the cache is never poisoned).
 */
async function critiqueBatch(designs, projectId) {
    try {
        const ai = new genai_1.GoogleGenAI({
            vertexai: true,
            project: projectId,
            location: 'us-central1',
        });
        const response = await withTimeout(ai.models.generateContent({
            model: GEMINI_MODEL,
            contents: buildContents(designs),
        }), MODEL_TIMEOUT_MS);
        return parseCritique(response.text ?? '', designs.length);
    }
    catch (err) {
        console.error('[aiCritic] critique failed — returning neutral:', err);
        return null;
    }
}
// ── Callable ──────────────────────────────────────────────────────────────────
/**
 * `critiqueDesigns` — the optional cloud "AI art director" (architecture §6.4).
 *
 * Takes up to 3 design thumbnails + genome metadata (NO photos, NO PII), and
 * returns a per-design aesthetic score in [0,1] plus optional short nudge hints.
 * Results are cached per params-hash in Firestore so repeat critiques are free.
 * On model error or timeout it returns neutral (0.5) results, so the caller's
 * heuristic ordering is preserved — the critic can never degrade the result.
 */
exports.critiqueDesigns = (0, https_1.onCall)({ timeoutSeconds: 30, memory: '512MiB' }, async (request) => {
    const raw = Array.isArray(request.data?.designs) ? request.data.designs : [];
    const designs = raw.slice(0, MAX_DESIGNS).filter(isValidCritiqueInput);
    if (designs.length === 0)
        return { results: [] };
    const db = (0, firestore_1.getFirestore)();
    const verdicts = new Map();
    // 1. Cache lookup per params-hash (a hit is free).
    const misses = [];
    await Promise.all(designs.map(async (d, i) => {
        try {
            const snap = await db
                .collection(CACHE_COLLECTION)
                .doc(cacheKey(d.paramsHash))
                .get();
            if (snap.exists) {
                const data = snap.data();
                verdicts.set(i, {
                    index: i,
                    aestheticScore: clamp01(Number(data.aestheticScore)),
                    hints: Array.isArray(data.hints) ? data.hints : [],
                });
                return;
            }
        }
        catch (err) {
            console.error('[aiCritic] cache read failed:', err);
        }
        misses.push({ design: d, index: i });
    }));
    // 2. One batched model call for the misses; cache genuine verdicts only.
    if (misses.length > 0) {
        const projectId = process.env.GCLOUD_PROJECT ?? process.env.GCP_PROJECT ?? '';
        const batch = await critiqueBatch(misses.map((m) => m.design), projectId);
        const writes = [];
        misses.forEach((miss, localIdx) => {
            const fresh = batch?.get(localIdx);
            if (fresh) {
                verdicts.set(miss.index, { ...fresh, index: miss.index });
                writes.push(db
                    .collection(CACHE_COLLECTION)
                    .doc(cacheKey(miss.design.paramsHash))
                    .set({
                    aestheticScore: fresh.aestheticScore,
                    hints: fresh.hints,
                    model: MODEL_VERSION,
                    createdAt: firestore_1.Timestamp.now(),
                })
                    .catch((err) => console.error('[aiCritic] cache write failed:', err)));
            }
            else {
                verdicts.set(miss.index, neutralResult(miss.index));
            }
        });
        await Promise.all(writes);
    }
    const results = designs.map((_, i) => verdicts.get(i) ?? neutralResult(i));
    return { results };
});
//# sourceMappingURL=aiCritic.js.map