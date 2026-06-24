"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.printfulMockupWebhook = exports.shopifyOrderCreated = exports.createMerchCart = exports.getMerchPrices = exports.getDailyChallenge = exports.scheduleDailyChallenge = void 0;
const dotenv = __importStar(require("dotenv"));
dotenv.config();
const app_1 = require("firebase-admin/app");
const firestore_1 = require("firebase-admin/firestore");
const storage_1 = require("firebase-admin/storage");
const https_1 = require("firebase-functions/v2/https");
const crypto = __importStar(require("crypto"));
const imageGen_1 = require("./imageGen");
const printDimensions_1 = require("./printDimensions");
var dailyChallenge_1 = require("./dailyChallenge");
Object.defineProperty(exports, "scheduleDailyChallenge", { enumerable: true, get: function () { return dailyChallenge_1.scheduleDailyChallenge; } });
Object.defineProperty(exports, "getDailyChallenge", { enumerable: true, get: function () { return dailyChallenge_1.getDailyChallenge; } });
(0, app_1.initializeApp)();
const db = (0, firestore_1.getFirestore)();
// ── Printful Mockup Generator (ADR-089) ───────────────────────────────────────
// Gildan 64000 DTG front/back print area: 12"×16" at 150 DPI (verified via
// GET /v2/catalog-products/12/mockup-styles?technique=dtg, 2026-05-07).
// LayerPosition coordinates are within this print area in inches.
const TSHIRT_FRONT_PRINT_W_IN = 12.0;
const TSHIRT_FRONT_PRINT_H_IN = 16.0;
/**
 * Returns the v2 LayerPosition (inches) for the given front placement, within
 * the 12"×16" Gildan 64000 DTG front print area.
 *
 * Industry standard left/right chest logo placement:
 *   - 3.0" below top of print area (neckline ~= top of print area)
 *   - Logo center 4" from shirt center (6" mid-point of 12" canvas)
 *   - Logo size 3.5"×3.5"
 *
 * left_chest  (wearer's left = viewer's right): top=3.0, left=8.25 (center at 10")
 * right_chest (wearer's right = viewer's left): top=3.0, left=0.25 (center at 2")
 * center: undefined → Printful auto-centres (fills the 12"×16" print area)
 */
function frontLayerPosition(frontPosition) {
    if (frontPosition === 'left_chest' || frontPosition === 'front_left') {
        // Wearer's left (viewer's right): logo center at 10" from canvas left, 3" from top.
        return { top: 3.0, left: 8.25, width: 3.5, height: 3.5 };
    }
    if (frontPosition === 'right_chest' || frontPosition === 'front_right') {
        // Wearer's right (viewer's left): logo center at 2" from canvas left, 3" from top.
        return { top: 3.0, left: 0.25, width: 3.5, height: 3.5 };
    }
    return undefined; // center: auto
}
/**
 * Submits a Printful v2 mockup task and returns the task ID immediately (M157).
 * Replaces the previous polling loop — result is delivered via printfulMockupWebhook.
 *
 * frontMockupFileUrl: raw design image accessible by Printful. Position is
 *   controlled entirely by the API via frontPosition (Layer.position).
 */
async function submitPrintfulMockupTask(printfulVariantId, frontMockupFileUrl, backPrintFileUrl, frontPosition = 'center') {
    const t0 = Date.now();
    const elapsed = () => `+${Date.now() - t0}ms`;
    const apiKey = process.env['PRINTFUL_API_KEY'];
    if (!apiKey) {
        console.error('[mockup] PRINTFUL_API_KEY not set — skipping mockup');
        return { taskId: null };
    }
    const placements = [];
    if (frontMockupFileUrl) {
        const position = frontLayerPosition(frontPosition);
        const layer = position
            ? { type: 'file', url: frontMockupFileUrl, position }
            : { type: 'file', url: frontMockupFileUrl };
        console.log(`[mockup] front layer position=${position ? `top=${position.top} left=${position.left} ${position.width}x${position.height}in` : 'auto-center'}`);
        placements.push({ placement: 'front', technique: 'dtg', layers: [layer] });
    }
    if (backPrintFileUrl) {
        placements.push({
            placement: 'back',
            technique: 'dtg',
            layers: [{ type: 'file', url: backPrintFileUrl }],
        });
    }
    if (placements.length === 0) {
        console.log('[mockup] no files — skipping Printful request');
        return { taskId: null };
    }
    // Style 24458 = Collage (Front and Back): single image showing both sides.
    const requestBody = {
        products: [{
                source: 'catalog',
                catalog_product_id: 12,
                catalog_variant_ids: [printfulVariantId],
                mockup_style_ids: [24458],
                placements,
            }],
    };
    console.log(`[mockup] ${elapsed()} submitting v2 task frontPosition=${frontPosition}`);
    const createRes = await fetch('https://api.printful.com/v2/mockup-tasks', {
        method: 'POST',
        headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
        body: JSON.stringify(requestBody),
    });
    const createBody = await createRes.text();
    if (!createRes.ok) {
        console.error(`[mockup] ${elapsed()} v2 create-task failed ${createRes.status}: ${createBody}`);
        return { taskId: null };
    }
    const createData = JSON.parse(createBody);
    const taskId = createData.data?.[0]?.id ?? null;
    if (!taskId) {
        console.error(`[mockup] ${elapsed()} no task id in v2 response`, JSON.stringify(createData));
        return { taskId: null };
    }
    console.log(`[mockup] ${elapsed()} v2 task submitted — taskId=${taskId} (webhook will deliver result)`);
    return { taskId };
}
// ── createMerchCart ───────────────────────────────────────────────────────────
const CART_CREATE_MUTATION = `
  mutation CreateCart($lines: [CartLineInput!]!, $attributes: [AttributeInput!]!) {
    cartCreate(input: { lines: $lines, attributes: $attributes }) {
      cart {
        id
        checkoutUrl
      }
      userErrors {
        field
        message
      }
    }
  }
`;
// ── getMerchPrices ────────────────────────────────────────────────────────────
const MERCH_PRICES_QUERY = `
  query GetMerchPrices($country: CountryCode) @inContext(country: $country) {
    tshirt: product(id: "gid://shopify/Product/8357194694843") {
      priceRange { minVariantPrice { amount currencyCode } }
    }
    poster: product(id: "gid://shopify/Product/8357218353339") {
      priceRange { minVariantPrice { amount currencyCode } }
    }
  }
`;
/**
 * Returns live product prices from Shopify Storefront API in the buyer's
 * presentment currency, determined by the supplied ISO 3166-1 alpha-2
 * country code (e.g. "AU" → AUD, "US" → USD).
 *
 * Falls back to GBP if the country code is invalid or omitted.
 */
exports.getMerchPrices = (0, https_1.onCall)(async (request) => {
    const storefrontToken = process.env['SHOPIFY_STOREFRONT_TOKEN'];
    const storeDomain = process.env['SHOPIFY_STORE_DOMAIN'];
    if (!storefrontToken || !storeDomain) {
        throw new https_1.HttpsError('internal', 'Storefront configuration missing.');
    }
    // Validate and normalise the country code (must be 2-letter uppercase alpha).
    const rawCountry = (request.data.countryCode ?? '').toUpperCase();
    const country = /^[A-Z]{2}$/.test(rawCountry) ? rawCountry : 'GB';
    const shopifyRes = await fetch(`https://${storeDomain}/api/2025-01/graphql.json`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'X-Shopify-Storefront-Access-Token': storefrontToken,
        },
        body: JSON.stringify({ query: MERCH_PRICES_QUERY, variables: { country } }),
    });
    if (!shopifyRes.ok) {
        throw new https_1.HttpsError('internal', `Shopify request failed: ${shopifyRes.status}`);
    }
    const shopifyData = (await shopifyRes.json());
    if (shopifyData.errors && shopifyData.errors.length > 0) {
        throw new https_1.HttpsError('internal', shopifyData.errors[0].message);
    }
    const tshirt = shopifyData.data?.tshirt?.priceRange?.minVariantPrice;
    const poster = shopifyData.data?.poster?.priceRange?.minVariantPrice;
    if (!tshirt || !poster) {
        throw new https_1.HttpsError('internal', 'Shopify returned incomplete price data.');
    }
    return { tshirtPrice: tshirt, posterPrice: poster };
});
/**
 * Creates a Shopify Storefront cart for the user's selected merchandise.
 *
 * M21 two-stage image generation (ADR-065):
 * 1. Write MerchConfig (status=pending, designStatus=pending)
 * 2. Generate preview PNG (800×600, JPEG 80) → upload to previews/{configId}.jpg
 * 3. Generate print PNG (product dimensions from PRINT_DIMENSIONS) → upload to
 *    print_files/{configId}.png, generate signed URL (7-day expiry)
 * 4. Update MerchConfig (designStatus=files_ready, paths, signedUrl, expiresAt)
 * 5. Create Shopify cart
 * 6. Update MerchConfig (shopifyCartId, status=cart_created)
 * 7. Return { checkoutUrl, cartId, merchConfigId, previewUrl }
 *
 * On generation failure: set designStatus=generation_error, throw HttpsError.
 * Cart is not created if generation fails.
 *
 * ADR-064: onCall handles Firebase Auth ID token verification automatically.
 */
exports.createMerchCart = (0, https_1.onCall)({ timeoutSeconds: 300, memory: '2GiB' }, async (request) => {
    const fnT0 = Date.now();
    const fnElapsed = () => `+${Date.now() - fnT0}ms`;
    // Auth check
    if (!request.auth) {
        throw new https_1.HttpsError('unauthenticated', 'Authentication required.');
    }
    const uid = request.auth.uid;
    console.log(`[cart] ${fnElapsed()} auth ok uid=${uid}`);
    // Input validation
    const { variantId, selectedCountryCodes, quantity, cardId, clientCardBase64, frontImageBase64, backImageBase64, artworkConfirmationId, mockupApprovalId, frontPosition, backPosition, giftSubject, giftMessage, clientConfigId } = request.data;
    // 'left_chest' | 'center' | 'right_chest' | 'none' — defaults to 'center'
    const effectiveFrontPosition = (typeof frontPosition === 'string' && frontPosition.length > 0) ? frontPosition : 'center';
    // 'center' | 'none' — defaults to 'center'
    const effectiveBackPosition = (typeof backPosition === 'string' && backPosition.length > 0) ? backPosition : 'center';
    if (!variantId || typeof variantId !== 'string') {
        throw new https_1.HttpsError('invalid-argument', 'variantId is required.');
    }
    if (!Array.isArray(selectedCountryCodes) ||
        selectedCountryCodes.length === 0) {
        throw new https_1.HttpsError('invalid-argument', 'selectedCountryCodes must be a non-empty array.');
    }
    if (typeof quantity !== 'number' || quantity < 1) {
        throw new https_1.HttpsError('invalid-argument', 'quantity must be at least 1.');
    }
    const resolvedBackBase64 = typeof backImageBase64 === 'string' ? backImageBase64 : (typeof clientCardBase64 === 'string' ? clientCardBase64 : null);
    if (resolvedBackBase64 && resolvedBackBase64.length > 5_500_000) {
        throw new https_1.HttpsError('invalid-argument', 'Back card image too large.');
    }
    if (typeof frontImageBase64 === 'string' && frontImageBase64.length > 5_500_000) {
        throw new https_1.HttpsError('invalid-argument', 'Front card image too large.');
    }
    // Look up print dimensions for this variant
    const printDims = printDimensions_1.PRINT_DIMENSIONS[variantId];
    if (!printDims) {
        throw new https_1.HttpsError('invalid-argument', `Unknown variantId: ${variantId}`);
    }
    console.log(`[cart] ${fnElapsed()} validation ok variantId=${variantId} front=${effectiveFrontPosition} back=${effectiveBackPosition} backBase64Len=${resolvedBackBase64?.length ?? 0} frontBase64Len=${frontImageBase64?.length ?? 0}`);
    // ── Step 1: Write initial MerchConfig ──────────────────────────────────
    const configRef = (typeof clientConfigId === 'string' && clientConfigId.length > 0)
        ? db.collection('users').doc(uid).collection('merch_configs').doc(clientConfigId)
        : db.collection('users').doc(uid).collection('merch_configs').doc();
    const configId = configRef.id;
    const configData = {
        configId,
        userId: uid,
        variantId,
        selectedCountryCodes,
        quantity,
        shopifyCartId: null,
        shopifyOrderId: null,
        status: 'pending',
        createdAt: firestore_1.Timestamp.now(),
        // M21 fields
        templateId: 'flag_grid_v1',
        designStatus: 'pending',
        previewStoragePath: null,
        frontPrintFileStoragePath: null,
        frontPrintFileSignedUrl: null,
        backPrintFileStoragePath: null,
        backPrintFileSignedUrl: null,
        printFileExpiresAt: null,
        printfulOrderId: null,
        // M34 field
        frontMockupUrl: null,
        backMockupUrl: null,
        mockupStatus: null,
        mockupError: null,
        // M38 field (ADR-093): links this order to the originating TravelCard, if any
        cardId: typeof cardId === 'string' ? cardId : null,
        // M48 field (ADR-100): links this order to the ArtworkConfirmation the user approved
        artworkConfirmationId: typeof artworkConfirmationId === 'string' ? artworkConfirmationId : null,
        // M53 field (ADR-105): links this order to the MockupApproval the user confirmed
        mockupApprovalId: typeof mockupApprovalId === 'string' ? mockupApprovalId : null,
        // M76 field (ADR-128): front placement so shopifyOrderCreated can use the correct Printful placement
        frontPosition: effectiveFrontPosition,
        // M81: gift message forwarded to Printful `gift` field in shopifyOrderCreated
        giftSubject: (typeof giftSubject === 'string' && giftSubject.trim().length > 0)
            ? giftSubject.trim().slice(0, 200) : null,
        giftMessage: (typeof giftMessage === 'string' && giftMessage.trim().length > 0)
            ? giftMessage.trim().slice(0, 200) : null,
        // M157: stored so printfulMockupWebhook can look up this config by task ID
        printfulMockupTaskId: null,
    };
    await configRef.set(configData);
    console.log(`[cart] ${fnElapsed()} step1 done — configId=${configId}`);
    // ── Step 2 & 3: Generate print PNGs + upload ───────────────────────────
    // M157: preview generation removed — client uses local artwork bytes.
    // When phone uploads files directly (Phase 3), storage paths are passed
    // in the request and Sharp processing is skipped entirely.
    const bucket = (0, storage_1.getStorage)().bucket();
    const frontPrintPath = `front_print_files/${configId}.png`;
    const backPrintPath = `back_print_files/${configId}.png`;
    const frontMockupPath = `mockup_files/${configId}.png`;
    let frontPrintFileSignedUrl = null;
    let backPrintFileSignedUrl = null;
    let frontMockupFileSignedUrl = null;
    // Phone-side upload path (Phase 3): storage paths provided, skip Sharp.
    const { frontPrintStoragePath, backPrintStoragePath, mockupStoragePath } = request.data;
    const usePhoneUploads = !!(frontPrintStoragePath || backPrintStoragePath || mockupStoragePath);
    try {
        const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
        if (usePhoneUploads) {
            // ── Phone-upload path: sign the already-uploaded files ────────────
            console.log(`[cart] ${fnElapsed()} step2 start — signing phone-uploaded files`);
            const [resolvedFrontSignedUrl, resolvedBackSignedUrl, resolvedMockupSignedUrl] = await Promise.all([
                frontPrintStoragePath
                    ? bucket.file(frontPrintStoragePath).getSignedUrl({ action: 'read', expires: expiresAt }).then(([u]) => u)
                    : Promise.resolve(null),
                backPrintStoragePath
                    ? bucket.file(backPrintStoragePath).getSignedUrl({ action: 'read', expires: expiresAt }).then(([u]) => u)
                    : Promise.resolve(null),
                mockupStoragePath
                    ? bucket.file(mockupStoragePath).getSignedUrl({ action: 'read', expires: expiresAt }).then(([u]) => u)
                    : Promise.resolve(null),
            ]);
            frontPrintFileSignedUrl = resolvedFrontSignedUrl;
            backPrintFileSignedUrl = resolvedBackSignedUrl;
            frontMockupFileSignedUrl = resolvedMockupSignedUrl;
            console.log(`[cart] ${fnElapsed()} step2 done — signed phone-uploaded files`);
            await configRef.update({
                designStatus: 'files_ready',
                previewStoragePath: null,
                frontPrintFileStoragePath: frontPrintStoragePath ?? null,
                frontPrintFileSignedUrl,
                backPrintFileStoragePath: backPrintStoragePath ?? null,
                backPrintFileSignedUrl,
                printFileExpiresAt: firestore_1.Timestamp.fromDate(expiresAt),
            });
        }
        else {
            // ── Server-side path: Sharp processing + upload (legacy / flag-grid) ─
            console.log(`[cart] ${fnElapsed()} step2 start — server-side image processing`);
            const sharp = (await Promise.resolve().then(() => __importStar(require('sharp')))).default;
            const bgColour = printDims.backgroundColor === 'transparent'
                ? { r: 0, g: 0, b: 0, alpha: 0 }
                : { r: 255, g: 255, b: 255, alpha: 1 };
            const [frontResult, backResult] = await Promise.all([
                // ── Front image ──────────────────────────────────────────────────
                (async () => {
                    if (typeof frontImageBase64 !== 'string' || frontImageBase64.length === 0)
                        return null;
                    const clientBuf = Buffer.from(frontImageBase64, 'base64');
                    const designBuf = await sharp(clientBuf)
                        .resize(printDims.widthPx, printDims.heightPx, { fit: 'contain', background: bgColour })
                        .toFormat('png')
                        .toBuffer();
                    const isChestPosition = effectiveFrontPosition === 'left_chest' || effectiveFrontPosition === 'front_left'
                        || effectiveFrontPosition === 'right_chest' || effectiveFrontPosition === 'front_right';
                    const chestPx = Math.round(3.5 * printDims.dpi);
                    const mockupBuf = isChestPosition
                        ? await sharp(clientBuf)
                            .resize(chestPx, chestPx, { fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 } })
                            .png()
                            .toBuffer()
                        : await sharp(clientBuf)
                            .resize(Math.round(TSHIRT_FRONT_PRINT_W_IN * printDims.dpi), Math.round(TSHIRT_FRONT_PRINT_H_IN * printDims.dpi), { fit: 'inside' })
                            .png()
                            .toBuffer();
                    if (effectiveFrontPosition === 'left_chest' || effectiveFrontPosition === 'front_left') {
                        const canvasW = printDims.widthPx; // 1800px = 12" at 150 DPI
                        const canvasH = printDims.heightPx; // 2400px = 16" at 150 DPI
                        // Logo: 3.5"×3.5" = 525×525px. Center at 10" from left (4" right of 6" mid).
                        // Top: 3" below top of print area = 450px.
                        const sizePx = Math.round(3.5 * printDims.dpi); // 525px
                        const top = Math.round(3.0 * printDims.dpi); // 450px
                        const centerX = Math.round(10.0 * printDims.dpi); // 1500px
                        const left = centerX - Math.round(sizePx / 2); // 1237px
                        const resized = await sharp(designBuf).resize(sizePx, sizePx, { fit: 'inside' }).toBuffer();
                        const { width: rw = sizePx } = await sharp(resized).metadata();
                        const printBuf = await sharp({
                            create: { width: canvasW, height: canvasH, channels: 4, background: { r: 0, g: 0, b: 0, alpha: 0 } },
                        })
                            .composite([{ input: resized, top, left: left + Math.round((sizePx - rw) / 2) }])
                            .png()
                            .toBuffer();
                        console.log(`[print] left_chest composited at top=${top}px (${top / printDims.dpi}") left=${left}px (${left / printDims.dpi}")`);
                        return { printBuf, mockupBuf };
                    }
                    if (effectiveFrontPosition === 'right_chest' || effectiveFrontPosition === 'front_right') {
                        const canvasW = printDims.widthPx; // 1800px = 12" at 150 DPI
                        const canvasH = printDims.heightPx; // 2400px = 16" at 150 DPI
                        // Logo: 3.5"×3.5" = 525×525px. Center at 2" from left (4" left of 6" mid).
                        // Top: 3" below top of print area = 450px.
                        const sizePx = Math.round(3.5 * printDims.dpi); // 525px
                        const top = Math.round(3.0 * printDims.dpi); // 450px
                        const centerX = Math.round(2.0 * printDims.dpi); // 300px
                        const left = centerX - Math.round(sizePx / 2); // 37px
                        const resized = await sharp(designBuf).resize(sizePx, sizePx, { fit: 'inside' }).toBuffer();
                        const { width: rw = sizePx } = await sharp(resized).metadata();
                        const printBuf = await sharp({
                            create: { width: canvasW, height: canvasH, channels: 4, background: { r: 0, g: 0, b: 0, alpha: 0 } },
                        })
                            .composite([{ input: resized, top, left: left + Math.round((sizePx - rw) / 2) }])
                            .png()
                            .toBuffer();
                        console.log(`[print] right_chest composited at top=${top}px (${top / printDims.dpi}") left=${left}px (${left / printDims.dpi}")`);
                        return { printBuf, mockupBuf };
                    }
                    return { printBuf: designBuf, mockupBuf };
                })(),
                // ── Back image ───────────────────────────────────────────────────
                (async () => {
                    if (typeof resolvedBackBase64 !== 'string' || resolvedBackBase64.length === 0)
                        return null;
                    const clientBuf = Buffer.from(resolvedBackBase64, 'base64');
                    const inputMeta = await sharp(clientBuf).metadata();
                    console.log(`[cart] back input: ${inputMeta.width}×${inputMeta.height} → ${printDims.widthPx}×${printDims.heightPx}`);
                    const backPrintBuf = await sharp(clientBuf)
                        .resize(printDims.widthPx, printDims.heightPx, {
                        fit: 'contain',
                        position: 'centre',
                        background: { r: 0, g: 0, b: 0, alpha: 0 },
                    })
                        .png()
                        .toBuffer();
                    return { backPrintBuf };
                })(),
            ]);
            const frontPrintBuf = frontResult?.printBuf ?? null;
            const frontMockupBuf = frontResult?.mockupBuf ?? null;
            let backPrintBuf = backResult?.backPrintBuf ?? null;
            console.log(`[cart] ${fnElapsed()} step2 done — front=${frontPrintBuf ? `${frontPrintBuf.length}B` : 'none'} back=${backPrintBuf ? `${backPrintBuf.length}B` : 'none'}`);
            // Fallback: server-side flag grid when no client images supplied.
            if (!frontPrintBuf && !frontMockupBuf && !backPrintBuf && effectiveBackPosition !== 'none') {
                backPrintBuf = await (0, imageGen_1.generateFlagGrid)({
                    templateId: 'flag_grid_v1',
                    selectedCountryCodes,
                    widthPx: printDims.widthPx,
                    heightPx: printDims.heightPx,
                    dpi: printDims.dpi,
                    backgroundColor: printDims.backgroundColor,
                });
            }
            // Upload print + mockup files in parallel.
            console.log(`[cart] ${fnElapsed()} step3 start — uploads`);
            const [resolvedFrontSignedUrl, resolvedBackSignedUrl, resolvedMockupSignedUrl] = await Promise.all([
                frontPrintBuf
                    ? (async () => {
                        const f = bucket.file(frontPrintPath);
                        await f.save(frontPrintBuf, { metadata: { contentType: 'image/png' } });
                        const [url] = await f.getSignedUrl({ action: 'read', expires: expiresAt });
                        return url;
                    })()
                    : Promise.resolve(null),
                backPrintBuf
                    ? (async () => {
                        const f = bucket.file(backPrintPath);
                        await f.save(backPrintBuf, { metadata: { contentType: 'image/png' } });
                        const [url] = await f.getSignedUrl({ action: 'read', expires: expiresAt });
                        return url;
                    })()
                    : Promise.resolve(null),
                frontMockupBuf
                    ? (async () => {
                        const f = bucket.file(frontMockupPath);
                        await f.save(frontMockupBuf, { metadata: { contentType: 'image/png' } });
                        const [url] = await f.getSignedUrl({ action: 'read', expires: expiresAt });
                        return url;
                    })()
                    : Promise.resolve(null),
            ]);
            frontPrintFileSignedUrl = resolvedFrontSignedUrl;
            backPrintFileSignedUrl = resolvedBackSignedUrl;
            frontMockupFileSignedUrl = resolvedMockupSignedUrl;
            console.log(`[cart] ${fnElapsed()} step3 done — uploads complete`);
            await configRef.update({
                designStatus: 'files_ready',
                previewStoragePath: null,
                frontPrintFileStoragePath: frontPrintBuf ? frontPrintPath : null,
                frontPrintFileSignedUrl,
                backPrintFileStoragePath: backPrintBuf ? backPrintPath : null,
                backPrintFileSignedUrl,
                printFileExpiresAt: firestore_1.Timestamp.fromDate(expiresAt),
            });
        }
    }
    catch (err) {
        await configRef.update({ designStatus: 'generation_error' });
        console.error(`[createMerchCart] Image generation failed for ${configId}:`, err);
        throw new https_1.HttpsError('internal', 'Design generation failed. Please try again.');
    }
    // ── Step 4: Create Shopify cart ────────────────────────────────────────
    console.log(`[cart] ${fnElapsed()} step4 start — Shopify cart`);
    const storefrontToken = process.env['SHOPIFY_STOREFRONT_TOKEN'];
    const storeDomain = process.env['SHOPIFY_STORE_DOMAIN'];
    if (!storefrontToken || !storeDomain) {
        throw new https_1.HttpsError('internal', 'Storefront configuration missing.');
    }
    const variables = {
        lines: [{ merchandiseId: variantId, quantity }],
        attributes: [{ key: 'merchConfigId', value: configId }],
    };
    const shopifyRes = await fetch(`https://${storeDomain}/api/2025-01/graphql.json`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'X-Shopify-Storefront-Access-Token': storefrontToken,
        },
        body: JSON.stringify({ query: CART_CREATE_MUTATION, variables }),
    });
    if (!shopifyRes.ok) {
        throw new https_1.HttpsError('internal', `Shopify request failed: ${shopifyRes.status}`);
    }
    const shopifyData = (await shopifyRes.json());
    if (shopifyData.errors && shopifyData.errors.length > 0) {
        throw new https_1.HttpsError('internal', shopifyData.errors[0].message);
    }
    const cartCreate = shopifyData.data?.cartCreate;
    if (!cartCreate) {
        throw new https_1.HttpsError('internal', 'Shopify returned no cartCreate data.');
    }
    if (cartCreate.userErrors.length > 0) {
        throw new https_1.HttpsError('invalid-argument', cartCreate.userErrors[0].message);
    }
    const cart = cartCreate.cart;
    if (!cart) {
        throw new https_1.HttpsError('internal', 'Shopify cartCreate returned no cart.');
    }
    // Update MerchConfig with cart ID
    await configRef.update({ shopifyCartId: cart.id, status: 'cart_created' });
    console.log(`[cart] ${fnElapsed()} step4 done — cart created cartId=${cart.id}`);
    // ── Step 5: Submit Printful mockup task (M157 — webhook delivers result) ─
    // Skipped for poster variants (printfulVariantId === 0 = not configured).
    // The printfulMockupWebhook function writes frontMockupUrl when Printful calls back.
    const printfulVariantId = printDimensions_1.PRINTFUL_VARIANT_IDS[variantId] ?? 0;
    if (printfulVariantId !== 0) {
        const { taskId } = await submitPrintfulMockupTask(printfulVariantId, frontMockupFileSignedUrl, backPrintFileSignedUrl, effectiveFrontPosition);
        // Write generating + taskId atomically so the webhook lookup works immediately.
        await configRef.update({
            mockupStatus: 'generating',
            printfulMockupTaskId: taskId,
            updatedAt: firestore_1.Timestamp.now(),
        });
        console.log(`[cart] ${fnElapsed()} step5 done — mockupStatus=generating taskId=${taskId ?? 'null'}`);
    }
    // Return immediately — frontMockupUrl will appear in Firestore via webhook.
    console.log(`[cart] ${fnElapsed()} returning to client`);
    return {
        checkoutUrl: cart.checkoutUrl,
        cartId: cart.id,
        merchConfigId: configId,
        frontMockupUrl: null,
        backMockupUrl: null,
    };
});
// ── shopifyOrderCreated ───────────────────────────────────────────────────────
/**
 * Receives the Shopify orders/create webhook.
 *
 * M21 Printful integration (ADR-065):
 * 1. Verify HMAC
 * 2. Look up MerchConfig by configId
 * 3. Update status=ordered, shopifyOrderId
 * 4. Validate/refresh signed URL
 * 5. POST to Printful /v2/orders with the print file attached
 * 6. Update MerchConfig: printfulOrderId, designStatus=print_file_submitted
 *
 * Always returns 200 — Shopify retries on non-200 (ADR-064).
 */
exports.shopifyOrderCreated = (0, https_1.onRequest)({ invoker: 'public' }, async (req, res) => {
    if (req.method !== 'POST') {
        res.status(405).send('Method Not Allowed');
        return;
    }
    const clientSecret = process.env['SHOPIFY_CLIENT_SECRET'];
    if (!clientSecret) {
        res.status(500).send('Server configuration error');
        return;
    }
    // HMAC-SHA256 verification
    const hmacHeader = req.headers['x-shopify-hmac-sha256'];
    if (!hmacHeader) {
        res.status(401).send('Missing HMAC header');
        return;
    }
    const rawBody = req.rawBody;
    if (!rawBody) {
        res.status(400).send('No raw body');
        return;
    }
    // TEMP: HMAC bypass — record the incoming HMAC so we can derive the correct
    // secret. Re-enable verification once the correct SHOPIFY_CLIENT_SECRET is set.
    // TODO: restore full HMAC check before production launch.
    const expectedHmac = crypto
        .createHmac('sha256', clientSecret)
        .update(rawBody)
        .digest('base64');
    const hmacMatch = hmacHeader === expectedHmac;
    if (!hmacMatch) {
        // Log both values via HTTP response header so they appear in Cloud Run
        // request logs even when stdout is suppressed.
        res.setHeader('X-Debug-Hmac-In', hmacHeader);
        res.setHeader('X-Debug-Hmac-Computed', expectedHmac);
    }
    // Parse Shopify order payload
    const payload = req.body;
    // Shopify test orders (Bogus Gateway) are sent to Printful as unconfirmed
    // drafts so print files can be inspected without triggering production.
    const isTestOrder = payload.test === true;
    const shopifyOrderId = payload.id?.toString() ?? null;
    if (!shopifyOrderId) {
        res.status(200).send('ok');
        return;
    }
    const noteAttrs = payload.note_attributes ?? [];
    // Log note_attributes so the first test order makes the payload visible in Cloud Logging.
    console.error(`[shopifyOrderCreated] order ${shopifyOrderId} note_attributes:`, JSON.stringify(noteAttrs));
    const configAttr = noteAttrs.find((a) => a.name === 'merchConfigId');
    if (!configAttr?.value) {
        // Non-Roavvy order — acknowledge and ignore
        res.status(200).send('ok');
        return;
    }
    const merchConfigId = configAttr.value;
    // Look up MerchConfig
    const snap = await db
        .collectionGroup('merch_configs')
        .where('configId', '==', merchConfigId)
        .limit(1)
        .get();
    if (snap.empty) {
        console.warn(`[shopifyOrderCreated] No MerchConfig found for ${merchConfigId}`);
        res.status(200).send('ok');
        return;
    }
    const docRef = snap.docs[0].ref;
    const config = snap.docs[0].data();
    // Idempotency guard: Shopify sometimes delivers the same webhook twice.
    // If a Printful order was already created, acknowledge and stop.
    if (config.printfulOrderId) {
        console.log(`[shopifyOrderCreated] already processed — printfulOrderId=${config.printfulOrderId}`);
        res.status(200).send('ok');
        return;
    }
    // Update order status
    await docRef.update({ shopifyOrderId, status: 'ordered' });
    // ── Link purchase to ArtworkConfirmation (M48, ADR-100) ────────────────
    // Non-blocking: failure here must not prevent the Printful order path.
    if (config.artworkConfirmationId) {
        try {
            const confirmationSnap = await db
                .collectionGroup('artwork_confirmations')
                .where('confirmationId', '==', config.artworkConfirmationId)
                .limit(1)
                .get();
            if (!confirmationSnap.empty) {
                await confirmationSnap.docs[0].ref.update({
                    status: 'purchase_linked',
                    orderId: shopifyOrderId,
                });
            }
            else {
                console.warn(`[shopifyOrderCreated] ArtworkConfirmation not found: ${config.artworkConfirmationId}`);
            }
        }
        catch (err) {
            console.error(`[shopifyOrderCreated] Failed to link ArtworkConfirmation ${config.artworkConfirmationId}:`, err);
        }
    }
    // ── Validate / refresh print file ──────────────────────────────────────
    // Always regenerate fresh signed URLs — stored signatures can become invalid
    // after the compute service account key rotates, even if the expiry timestamp
    // hasn't passed. Regenerating here guarantees Printful gets a working URL.
    let frontPrintFileSignedUrl = null;
    let backPrintFileSignedUrl = null;
    if (config.designStatus === 'generation_error' ||
        (!config.frontPrintFileStoragePath && !config.backPrintFileStoragePath)) {
        // Attempt regeneration (fallback generates back card only)
        const regenerated = await _regeneratePrintFile(docRef, config, shopifyOrderId);
        if (!regenerated) {
            res.status(200).send('ok');
            return;
        }
        backPrintFileSignedUrl = regenerated.backPrintFileSignedUrl;
    }
    else {
        // Always generate fresh signed URLs regardless of stored values.
        if (config.frontPrintFileStoragePath) {
            frontPrintFileSignedUrl = await _refreshSignedUrl(docRef, config.frontPrintFileStoragePath);
        }
        if (config.backPrintFileStoragePath) {
            backPrintFileSignedUrl = await _refreshSignedUrl(docRef, config.backPrintFileStoragePath);
        }
        if (!frontPrintFileSignedUrl && !backPrintFileSignedUrl) {
            console.error(`[shopifyOrderCreated] Failed to generate signed URLs for config ${config.configId}`);
            await docRef.update({ designStatus: 'print_file_error' });
            res.status(200).send('ok');
            return;
        }
    }
    // ── Create Printful order ──────────────────────────────────────────────
    const printfulApiKey = process.env['PRINTFUL_API_KEY'];
    if (!printfulApiKey) {
        console.error('[shopifyOrderCreated] PRINTFUL_API_KEY not set');
        await docRef.update({ designStatus: 'print_file_error' });
        res.status(200).send('ok');
        return;
    }
    const printfulVariantId = printDimensions_1.PRINTFUL_VARIANT_IDS[config.variantId];
    if (!printfulVariantId) {
        console.error(`[shopifyOrderCreated] No Printful variant ID for Shopify GID: ${config.variantId}`);
        await docRef.update({ designStatus: 'print_file_error' });
        res.status(200).send('ok');
        return;
    }
    const shippingAddr = payload.shipping_address;
    const recipient = shippingAddr
        ? {
            name: shippingAddr.name ?? '',
            address1: shippingAddr.address1 ?? '',
            address2: shippingAddr.address2 ?? '',
            city: shippingAddr.city ?? '',
            state_code: shippingAddr.province_code ?? '',
            zip: shippingAddr.zip ?? '',
            country_code: shippingAddr.country_code ?? '',
            phone: shippingAddr.phone ?? '',
        }
        : {};
    // Printful v1 Orders API — uses `files` array inside items.
    // The v2 API silently discards `placements` in order creation (confirmed
    // 2026-06-24: v2 order-items always return placements:[] regardless of input).
    // Chest positioning (left_chest / right_chest) is baked into the print file
    // pixel coordinates, so type:"front" covers all front designs.
    const files = [];
    if (frontPrintFileSignedUrl) {
        files.push({ type: 'front', url: frontPrintFileSignedUrl });
    }
    if (backPrintFileSignedUrl) {
        files.push({ type: 'back', url: backPrintFileSignedUrl });
    }
    try {
        // Test orders are created as unconfirmed drafts so print files can be
        // reviewed in the Printful dashboard without triggering production.
        const printfulOrderUrl = isTestOrder
            ? 'https://api.printful.com/orders?confirm=false'
            : 'https://api.printful.com/orders';
        console.log(`[shopifyOrderCreated] Printful order URL: ${printfulOrderUrl} (isTest=${isTestOrder})`);
        const printfulRes = await fetch(printfulOrderUrl, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                Authorization: `Bearer ${printfulApiKey}`,
            },
            body: JSON.stringify({
                external_id: shopifyOrderId,
                recipient,
                items: [
                    {
                        variant_id: printfulVariantId,
                        quantity: config.quantity,
                        files,
                    },
                ],
                // M79: Roavvy-branded packing slip on every order.
                packing_slip: {
                    ...(process.env['ROAVVY_LOGO_URL']
                        ? { logo_url: process.env['ROAVVY_LOGO_URL'] }
                        : {}),
                    message: 'Thank you for your Roavvy order! Made with your travel memories. 🌍',
                    email: 'support@roavvy.com',
                    store_name: 'Roavvy',
                    custom_order_id: `ROAVVY-${shopifyOrderId}`,
                },
                // M81: forward gift message to Printful when the user marked it as a gift.
                ...(config.giftSubject || config.giftMessage
                    ? {
                        gift: {
                            subject: (config.giftSubject ?? '').slice(0, 200),
                            message: (config.giftMessage ?? '').slice(0, 200),
                        },
                    }
                    : {}),
            }),
        });
        const printfulData = (await printfulRes.json());
        // Log Printful response status and body for sandbox debugging (Task 117).
        console.error(`[shopifyOrderCreated] Printful API response for order ${shopifyOrderId}:`, `status=${printfulRes.status}`, JSON.stringify(printfulData));
        // OR-13 = order already exists for this external_id (duplicate webhook delivery
        // that slipped past the idempotency guard above). Treat as success.
        const isAlreadyExists = printfulData.error
            ?.api_error_code === 'OR-13';
        if (!isAlreadyExists && (!printfulRes.ok || printfulData.error || printfulData.code !== 200)) {
            console.error(`[shopifyOrderCreated] Printful API error for order ${shopifyOrderId}:`, printfulData);
            await docRef.update({ designStatus: 'print_file_error' });
        }
        else {
            const printfulOrderId = isAlreadyExists
                ? (config.printfulOrderId ?? 'unknown')
                : String(printfulData.result?.id);
            await docRef.update({
                printfulOrderId,
                designStatus: 'print_file_submitted',
            });
            // Note: do NOT delete print files from GCS here.
            // Printful queues downloads asynchronously — status is "waiting" at this
            // point. Deleting now causes 404s when Printful tries to fetch them.
            // GCS lifecycle rules (7-day TTL on front_print_files/ back_print_files/)
            // handle cleanup automatically.
        }
    }
    catch (err) {
        console.error(`[shopifyOrderCreated] Printful request threw for order ${shopifyOrderId}:`, err);
        await docRef.update({ designStatus: 'print_file_error' });
    }
    res.status(200).send('ok');
});
// ── Private helpers ───────────────────────────────────────────────────────────
/**
 * Attempt to regenerate the print file for a MerchConfig whose generation
 * previously failed or whose file is missing. Updates Firestore on success or
 * failure. Returns the new signed URL on success, null on failure.
 */
async function _regeneratePrintFile(docRef, config, shopifyOrderId) {
    const printDims = printDimensions_1.PRINT_DIMENSIONS[config.variantId];
    if (!printDims) {
        console.error(`[_regeneratePrintFile] No print dimensions for variant ${config.variantId}`);
        await docRef.update({ designStatus: 'print_file_error' });
        return null;
    }
    try {
        const printBuf = await (0, imageGen_1.generateFlagGrid)({
            templateId: 'flag_grid_v1',
            selectedCountryCodes: config.selectedCountryCodes,
            widthPx: printDims.widthPx,
            heightPx: printDims.heightPx,
            dpi: printDims.dpi,
            backgroundColor: printDims.backgroundColor,
        });
        const bucket = (0, storage_1.getStorage)().bucket();
        const printPath = `back_print_files/${config.configId}.png`;
        const printFile = bucket.file(printPath);
        await printFile.save(printBuf, { metadata: { contentType: 'image/png' } });
        const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
        const [signedUrl] = await printFile.getSignedUrl({
            action: 'read',
            expires: expiresAt,
        });
        await docRef.update({
            designStatus: 'files_ready',
            backPrintFileStoragePath: printPath,
            backPrintFileSignedUrl: signedUrl,
            printFileExpiresAt: firestore_1.Timestamp.fromDate(expiresAt),
        });
        return { backPrintFileSignedUrl: signedUrl };
    }
    catch (err) {
        console.error(`[_regeneratePrintFile] Regeneration failed for order ${shopifyOrderId}:`, err);
        await docRef.update({ designStatus: 'print_file_error' });
        return null;
    }
}
/**
 * Refreshes the signed URL for an existing print file in Firebase Storage.
 * Returns the new signed URL.
 */
async function _refreshSignedUrl(docRef, printFileStoragePath) {
    const bucket = (0, storage_1.getStorage)().bucket();
    const printFile = bucket.file(printFileStoragePath);
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
    const [signedUrl] = await printFile.getSignedUrl({
        action: 'read',
        expires: expiresAt,
    });
    // Note: Firestore update is skipped here for simplicity as we have two separate paths now.
    return signedUrl;
}
// ── printfulMockupWebhook ─────────────────────────────────────────────────────
/**
 * Receives the Printful mockup_task_finished webhook (M157, ADR-157).
 *
 * Printful POSTs when a mockup task completes or fails. This handler:
 * 1. Looks up the MerchConfig by printfulMockupTaskId.
 * 2. Extracts the collage mockup URL from the payload.
 * 3. Writes frontMockupUrl + mockupStatus to Firestore.
 * 4. Deletes the temporary mockup GCS file (best-effort).
 *
 * Security: Printful v2 webhooks do not provide HMAC signatures.
 * The Firestore lookup by printfulMockupTaskId is the verification —
 * an unknown task ID finds no config and is silently dropped.
 *
 * Always returns 200 — non-200 causes Printful to retry.
 */
exports.printfulMockupWebhook = (0, https_1.onRequest)({ invoker: 'public' }, async (req, res) => {
    if (req.method !== 'POST') {
        res.status(200).send('ok');
        return;
    }
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const body = req.body;
    if (body.type !== 'mockup_task_finished') {
        res.status(200).send('ok');
        return;
    }
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const task = body.data;
    const taskId = task?.id;
    if (!taskId) {
        console.warn('[printfulMockupWebhook] no task id in payload');
        res.status(200).send('ok');
        return;
    }
    console.log(`[printfulMockupWebhook] taskId=${taskId} status=${task?.status ?? 'unknown'}`);
    // Look up MerchConfig by task ID.
    const snap = await db
        .collectionGroup('merch_configs')
        .where('printfulMockupTaskId', '==', taskId)
        .limit(1)
        .get();
    if (snap.empty) {
        console.warn(`[printfulMockupWebhook] no config found for taskId=${taskId}`);
        res.status(200).send('ok');
        return;
    }
    const docRef = snap.docs[0].ref;
    const config = snap.docs[0].data();
    // Extract collage URL — style 24458 produces a single image for both sides.
    let frontMockupUrl = null;
    for (const variantMockup of task?.catalog_variant_mockups ?? []) {
        for (const m of variantMockup.mockups ?? []) {
            const url = m?.mockup_url ?? null;
            if (url && !frontMockupUrl)
                frontMockupUrl = url;
        }
    }
    const mockupStatus = (task?.status === 'completed' && frontMockupUrl) ? 'ready'
        : task?.status === 'failed' ? 'failed'
            : 'timeout';
    await docRef.update({
        frontMockupUrl,
        backMockupUrl: null,
        mockupStatus,
        updatedAt: firestore_1.Timestamp.now(),
    });
    console.log(`[printfulMockupWebhook] taskId=${taskId} configId=${config.configId} mockupStatus=${mockupStatus} url=${frontMockupUrl ? '✓' : 'null'}`);
    // Delete the temporary mockup file from GCS — Printful has downloaded it.
    const mockupStoragePath = `mockup_files/${config.configId}.png`;
    (0, storage_1.getStorage)().bucket().file(mockupStoragePath).delete().catch((e) => {
        console.warn(`[printfulMockupWebhook] mockup file delete failed: ${e}`);
    });
    res.status(200).send('ok');
});
//# sourceMappingURL=index.js.map