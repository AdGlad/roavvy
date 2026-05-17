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
exports.shopifyOrderCreated = exports.createMerchCart = void 0;
const dotenv = __importStar(require("dotenv"));
dotenv.config();
const app_1 = require("firebase-admin/app");
const firestore_1 = require("firebase-admin/firestore");
const storage_1 = require("firebase-admin/storage");
const https_1 = require("firebase-functions/v2/https");
const crypto = __importStar(require("crypto"));
const imageGen_1 = require("./imageGen");
const printDimensions_1 = require("./printDimensions");
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
 * left_chest (wearer's left = viewer's right): top=1.12, left=6.96, 3.5"×3.5"
 * right_chest (wearer's right = viewer's left): top=1.12, left=1.56, 3.5"×3.5"
 * center: undefined → Printful auto-centres (fills the 12"×16" print area)
 */
function frontLayerPosition(frontPosition) {
    if (frontPosition === 'left_chest' || frontPosition === 'front_left') {
        // Wearer's left chest (viewer's right): ~58% across, ~7% down the print area.
        return { top: 1.12, left: 6.96, width: 3.5, height: 3.5 };
    }
    if (frontPosition === 'right_chest' || frontPosition === 'front_right') {
        // Wearer's right chest (viewer's left): ~13% across, ~7% down the print area.
        return { top: 1.12, left: 1.56, width: 3.5, height: 3.5 };
    }
    return undefined; // center: auto
}
/**
 * Generates photorealistic front and back t-shirt mockups using the Printful v2
 * Mockup API (/v2/mockup-tasks). Uses Layer.position (inches) to place the design
 * within the print area — no image compositing required.
 *
 * frontMockupFileUrl: raw design image (no compositing). Position is controlled
 *   entirely by the API via frontPosition.
 *
 * Returns separate frontMockupUrl and backMockupUrl.
 */
async function generatePrintfulMockup(printfulVariantId, frontMockupFileUrl, backPrintFileUrl, frontPosition = 'center') {
    const t0 = Date.now();
    const elapsed = () => `+${Date.now() - t0}ms`;
    const apiKey = process.env['PRINTFUL_API_KEY'];
    if (!apiKey) {
        console.error('[mockup] PRINTFUL_API_KEY not set — skipping mockup');
        return { frontMockupUrl: null, backMockupUrl: null };
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
        // No position needed — image is 3:4 matching the print area, Printful
        // auto-fills it. The transparent top gap is baked into the image so the
        // artwork content appears lower on the shirt.
        placements.push({
            placement: 'back',
            technique: 'dtg',
            layers: [{ type: 'file', url: backPrintFileUrl }],
        });
    }
    if (placements.length === 0) {
        console.log('[mockup] no files — skipping Printful request');
        return { frontMockupUrl: null, backMockupUrl: null };
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
    console.log(`[mockup] ${elapsed()} submitting v2 task frontPosition=${frontPosition} body=${JSON.stringify(requestBody)}`);
    const createRes = await fetch('https://api.printful.com/v2/mockup-tasks', {
        method: 'POST',
        headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
        body: JSON.stringify(requestBody),
    });
    const createBody = await createRes.text();
    if (!createRes.ok) {
        console.error(`[mockup] ${elapsed()} v2 create-task failed ${createRes.status}: ${createBody}`);
        return { frontMockupUrl: null, backMockupUrl: null };
    }
    console.log(`[mockup] ${elapsed()} v2 create-task response: ${createBody}`);
    const createData = JSON.parse(createBody);
    const taskId = createData.data?.[0]?.id;
    if (!taskId) {
        console.error(`[mockup] ${elapsed()} no task id in v2 response`, JSON.stringify(createData));
        return { frontMockupUrl: null, backMockupUrl: null };
    }
    console.log(`[mockup] ${elapsed()} v2 task submitted — taskId=${taskId}, polling...`);
    const maxAttempts = 25;
    const intervalMs = 3000;
    let frontMockupUrl = null;
    let backMockupUrl = null;
    for (let i = 0; i < maxAttempts; i++) {
        await new Promise((resolve) => setTimeout(resolve, intervalMs));
        const pollRes = await fetch(`https://api.printful.com/v2/mockup-tasks?id=${taskId}`, { headers: { Authorization: `Bearer ${apiKey}` } });
        if (!pollRes.ok) {
            console.error(`[mockup] ${elapsed()} poll[${i}] failed ${pollRes.status}`);
            return { frontMockupUrl: null, backMockupUrl: null };
        }
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const pollData = (await pollRes.json());
        const task = pollData.data?.[0];
        const status = task?.status;
        console.log(`[mockup] ${elapsed()} poll[${i}] status=${status ?? 'unknown'}`);
        if (status === 'completed') {
            // Log items (placement statuses) to detect Printful-side position errors.
            // eslint-disable-next-line @typescript-eslint/no-explicit-any
            const items = task?.items ?? [];
            for (const item of items) {
                for (const pl of item?.placements ?? []) {
                    console.log(`[mockup] ${elapsed()} item placement=${pl.placement} status=${pl.status} explanation=${pl.status_explanation ?? 'ok'}`);
                }
            }
            // Style 24458 is a collage (front+back in one image). Take the first
            // non-null mockup_url regardless of placement — it is the collage image.
            for (const variantMockup of task?.catalog_variant_mockups ?? []) {
                for (const m of variantMockup.mockups ?? []) {
                    const url = m?.mockup_url ?? null;
                    const placement = m?.placement ?? '';
                    console.log(`[mockup] ${elapsed()} mockup placement=${placement} url=${url ? '✓' : 'null'}`);
                    if (url && !frontMockupUrl)
                        frontMockupUrl = url;
                }
            }
            console.log(`[mockup] ${elapsed()} completed — collage=${frontMockupUrl ? '✓' : 'null'}`);
            return { frontMockupUrl, backMockupUrl };
        }
        if (status === 'failed') {
            console.error(`[mockup] ${elapsed()} v2 task failed: ${JSON.stringify(task)}`);
            return { frontMockupUrl: null, backMockupUrl: null };
        }
    }
    console.error(`[mockup] ${elapsed()} timed out after ${maxAttempts} polls for taskId=${taskId}`);
    return { frontMockupUrl, backMockupUrl };
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
    const { variantId, selectedCountryCodes, quantity, cardId, clientCardBase64, frontImageBase64, backImageBase64, artworkConfirmationId, mockupApprovalId, frontPosition, backPosition } = request.data;
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
    const configRef = db
        .collection('users')
        .doc(uid)
        .collection('merch_configs')
        .doc();
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
    };
    await configRef.set(configData);
    console.log(`[cart] ${fnElapsed()} step1 done — configId=${configId}`);
    // ── Step 2 & 3: Generate preview + print PNGs ──────────────────────────
    const bucket = (0, storage_1.getStorage)().bucket();
    const previewPath = `previews/${configId}.jpg`;
    const frontPrintPath = `front_print_files/${configId}.png`;
    const backPrintPath = `back_print_files/${configId}.png`;
    const frontMockupPath = `mockup_files/${configId}.png`;
    let previewUrl;
    let frontPrintFileSignedUrl = null;
    let backPrintFileSignedUrl = null;
    let frontMockupFileSignedUrl = null;
    try {
        console.log(`[cart] ${fnElapsed()} step2 start — image processing`);
        const sharp = (await Promise.resolve().then(() => __importStar(require('sharp')))).default;
        const bgColour = printDims.backgroundColor === 'transparent'
            ? { r: 0, g: 0, b: 0, alpha: 0 }
            : { r: 255, g: 255, b: 255, alpha: 1 };
        // Process front and back images in parallel — they are independent.
        // Front returns { printBuf, mockupBuf }: printBuf is the composited print file
        // for ordering; mockupBuf is the raw design sent to Printful v2 with position params.
        const [frontResult, backResult] = await Promise.all([
            // ── Front image ────────────────────────────────────────────────────
            (async () => {
                if (typeof frontImageBase64 !== 'string' || frontImageBase64.length === 0)
                    return null;
                const clientBuf = Buffer.from(frontImageBase64, 'base64');
                const designBuf = await sharp(clientBuf)
                    .resize(printDims.widthPx, printDims.heightPx, { fit: 'contain', background: bgColour })
                    .toFormat('png')
                    .toBuffer();
                // mockupBuf: image for Printful v2 mockup API (no compositing).
                // Printful v2 requires the file's aspect ratio to match the Layer.position
                // ratio within 2%. Chest positions are 3.5"×3.5" (1:1 square); center has
                // no position so ratio is unconstrained.
                const isChestPosition = effectiveFrontPosition === 'left_chest' || effectiveFrontPosition === 'front_left'
                    || effectiveFrontPosition === 'right_chest' || effectiveFrontPosition === 'front_right';
                const chestPx = Math.round(3.5 * printDims.dpi); // 525px at 150 DPI
                const mockupBuf = isChestPosition
                    ? await sharp(clientBuf)
                        // Pad to square so ratio matches 3.5"×3.5" position box (± 2%).
                        .resize(chestPx, chestPx, { fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 } })
                        .png()
                        .toBuffer()
                    : await sharp(clientBuf)
                        .resize(Math.round(TSHIRT_FRONT_PRINT_W_IN * printDims.dpi), // 1800px
                    Math.round(TSHIRT_FRONT_PRINT_H_IN * printDims.dpi), // 2400px
                    { fit: 'inside' })
                        .png()
                        .toBuffer();
                if (effectiveFrontPosition === 'left_chest' || effectiveFrontPosition === 'front_left') {
                    // printBuf: composited canvas for DTG ordering (position baked in).
                    const canvasW = printDims.widthPx;
                    const canvasH = printDims.heightPx;
                    const maxW = Math.round(canvasW * 0.29);
                    const maxH = Math.round(canvasH * 0.30);
                    const top = Math.round(canvasH * 0.07);
                    const left = Math.round(canvasW * 0.58);
                    const resized = await sharp(designBuf).resize(maxW, maxH, { fit: 'inside' }).toBuffer();
                    const { width: rw = maxW } = await sharp(resized).metadata();
                    const printBuf = await sharp({
                        create: { width: canvasW, height: canvasH, channels: 4, background: { r: 0, g: 0, b: 0, alpha: 0 } },
                    })
                        .composite([{ input: resized, top, left: left + Math.round((maxW - rw) / 2) }])
                        .png()
                        .toBuffer();
                    console.log(`[print] left_chest print file composited at top=${top} left=${left}; mockup uses v2 position params`);
                    return { printBuf, mockupBuf };
                }
                if (effectiveFrontPosition === 'right_chest' || effectiveFrontPosition === 'front_right') {
                    const canvasW = printDims.widthPx;
                    const canvasH = printDims.heightPx;
                    const maxW = Math.round(canvasW * 0.29);
                    const maxH = Math.round(canvasH * 0.30);
                    const top = Math.round(canvasH * 0.07);
                    const left = Math.round(canvasW * 0.13);
                    const resized = await sharp(designBuf).resize(maxW, maxH, { fit: 'inside' }).toBuffer();
                    const { width: rw = maxW } = await sharp(resized).metadata();
                    const printBuf = await sharp({
                        create: { width: canvasW, height: canvasH, channels: 4, background: { r: 0, g: 0, b: 0, alpha: 0 } },
                    })
                        .composite([{ input: resized, top, left: left + Math.round((maxW - rw) / 2) }])
                        .png()
                        .toBuffer();
                    console.log(`[print] right_chest print file composited at top=${top} left=${left}; mockup uses v2 position params`);
                    return { printBuf, mockupBuf };
                }
                return { printBuf: designBuf, mockupBuf };
            })(),
            // ── Back image (also generates preview JPEG) ───────────────────────
            (async () => {
                if (typeof resolvedBackBase64 !== 'string' || resolvedBackBase64.length === 0)
                    return null;
                const clientBuf = Buffer.from(resolvedBackBase64, 'base64');
                const inputMeta = await sharp(clientBuf).metadata();
                console.log(`[cart] back input: ${inputMeta.width}×${inputMeta.height} → print canvas: ${printDims.widthPx}×${printDims.heightPx}`);
                // Resize to preview and print dimensions in parallel from the same input.
                // Explicit position:'centre' ensures consistent centring across Sharp versions.
                const [previewJpeg, backPrintBuf] = await Promise.all([
                    sharp(clientBuf)
                        .resize(800, 600, { fit: 'contain', position: 'centre', background: { r: 255, g: 255, b: 255, alpha: 1 } })
                        .toFormat('jpeg', { quality: 80 })
                        .toBuffer(),
                    // Scale back artwork to fill the full print canvas (same approach
                    // as front/center). fit:'contain' scales to fill the full canvas
                    // with letterboxing on transparent background.
                    sharp(clientBuf)
                        .resize(printDims.widthPx, printDims.heightPx, {
                        fit: 'contain',
                        position: 'centre',
                        background: { r: 0, g: 0, b: 0, alpha: 0 },
                    })
                        .png()
                        .toBuffer()
                        .then(buf => {
                        console.log(`[cart] back: input=${inputMeta.width}×${inputMeta.height} → contain ${printDims.widthPx}×${printDims.heightPx}`);
                        return buf;
                    }),
                ]);
                return { backPrintBuf, previewJpeg };
            })(),
        ]);
        const frontPrintBuf = frontResult?.printBuf ?? null;
        const frontMockupBuf = frontResult?.mockupBuf ?? null;
        let backPrintBuf = backResult?.backPrintBuf ?? null;
        let previewJpeg = backResult?.previewJpeg ?? null;
        console.log(`[cart] ${fnElapsed()} step2 done — image processing (front=${frontPrintBuf ? `${frontPrintBuf.length}B` : 'none'} back=${backPrintBuf ? `${backPrintBuf.length}B` : 'none'})`);
        // Fallback: server-side flag grid when no client images supplied.
        if (!frontPrintBuf && !frontMockupBuf && !backPrintBuf && effectiveBackPosition !== 'none') {
            const previewPng = await (0, imageGen_1.generateFlagGrid)({
                templateId: 'flag_grid_v1',
                selectedCountryCodes,
                widthPx: 800,
                heightPx: 600,
                dpi: 96,
                backgroundColor: 'white',
            });
            previewJpeg = await sharp(previewPng).toFormat('jpeg', { quality: 80 }).toBuffer();
            backPrintBuf = await (0, imageGen_1.generateFlagGrid)({
                templateId: 'flag_grid_v1',
                selectedCountryCodes,
                widthPx: printDims.widthPx,
                heightPx: printDims.heightPx,
                dpi: printDims.dpi,
                backgroundColor: printDims.backgroundColor,
            });
        }
        // Edge case: no back image — generate preview from front design.
        if (!previewJpeg && frontPrintBuf) {
            previewJpeg = await sharp(frontPrintBuf)
                .resize(800, 600, { fit: 'contain', background: { r: 255, g: 255, b: 255, alpha: 1 } })
                .toFormat('jpeg', { quality: 80 })
                .toBuffer();
        }
        // Upload preview + print files in parallel.
        console.log(`[cart] ${fnElapsed()} step3 start — uploads`);
        const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
        const [uploadedPreviewUrl, resolvedFrontSignedUrl, resolvedBackSignedUrl, resolvedMockupSignedUrl] = await Promise.all([
            (async () => {
                const f = bucket.file(previewPath);
                await f.save(previewJpeg, { metadata: { contentType: 'image/jpeg' }, public: true });
                return f.publicUrl();
            })(),
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
        previewUrl = uploadedPreviewUrl;
        frontPrintFileSignedUrl = resolvedFrontSignedUrl;
        backPrintFileSignedUrl = resolvedBackSignedUrl;
        frontMockupFileSignedUrl = resolvedMockupSignedUrl;
        console.log(`[cart] ${fnElapsed()} step3 done — uploads complete`);
        // Update MerchConfig: files_ready
        await configRef.update({
            designStatus: 'files_ready',
            previewStoragePath: previewPath,
            frontPrintFileStoragePath: frontPrintBuf ? frontPrintPath : null,
            frontPrintFileSignedUrl,
            backPrintFileStoragePath: backPrintBuf ? backPrintPath : null,
            backPrintFileSignedUrl,
            printFileExpiresAt: firestore_1.Timestamp.fromDate(expiresAt),
        });
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
    // ── Step 5: Generate Printful mockup (background — does not block response) ─
    // The promise updates Firestore when complete; the client polls for the URL.
    // Skipped for poster variants (printfulVariantId === 0 = not configured).
    const printfulVariantId = printDimensions_1.PRINTFUL_VARIANT_IDS[variantId] ?? 0;
    if (printfulVariantId !== 0) {
        // Write 'generating' before returning so the client listener sees it on
        // the first snapshot after attaching (avoids a null → null → ready jump).
        await configRef.update({ mockupStatus: 'generating', updatedAt: firestore_1.Timestamp.now() });
        console.log(`[cart] ${fnElapsed()} mockupStatus=generating written for ${configId}`);
        void generatePrintfulMockup(printfulVariantId, frontMockupFileSignedUrl, // raw design — Printful v2 positions via Layer.position
        backPrintFileSignedUrl, effectiveFrontPosition)
            .then(async ({ frontMockupUrl, backMockupUrl }) => {
            // Always write — even when both URLs are null (timeout inside generatePrintfulMockup).
            // The status distinguishes "ready with URLs" from "timed out without URLs".
            const status = (frontMockupUrl || backMockupUrl) ? 'ready' : 'timeout';
            console.log(`[createMerchCart] Background mockup ${status} for ${configId}: front=${frontMockupUrl ? '✓' : 'null'} back=${backMockupUrl ? '✓' : 'null'}`);
            await configRef.update({
                frontMockupUrl: frontMockupUrl ?? null,
                backMockupUrl: backMockupUrl ?? null,
                mockupStatus: status,
                updatedAt: firestore_1.Timestamp.now(),
            });
            console.log(`[createMerchCart] mockupStatus=${status} written to Firestore for ${configId}`);
        })
            .catch(async (err) => {
            const msg = err instanceof Error ? err.message : String(err);
            console.error(`[createMerchCart] Background mockup failed for ${configId}:`, err);
            await configRef.update({
                mockupStatus: 'failed',
                mockupError: msg,
                updatedAt: firestore_1.Timestamp.now(),
            });
        });
    }
    // Return immediately — mockup URL will appear in Firestore when ready.
    console.log(`[cart] ${fnElapsed()} returning to client (mockup generating in background)`);
    return {
        checkoutUrl: cart.checkoutUrl,
        cartId: cart.id,
        merchConfigId: configId,
        previewUrl,
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
    const expectedHmac = crypto
        .createHmac('sha256', clientSecret)
        .update(rawBody)
        .digest('base64');
    const hmacHeaderBuf = Buffer.from(hmacHeader, 'base64');
    const expectedBuf = Buffer.from(expectedHmac, 'base64');
    if (hmacHeaderBuf.length !== expectedBuf.length ||
        !crypto.timingSafeEqual(hmacHeaderBuf, expectedBuf)) {
        res.status(401).send('HMAC verification failed');
        return;
    }
    // Parse Shopify order payload
    const payload = req.body;
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
    let frontPrintFileSignedUrl = config.frontPrintFileSignedUrl;
    let backPrintFileSignedUrl = config.backPrintFileSignedUrl;
    if (config.designStatus === 'generation_error' ||
        (!config.frontPrintFileStoragePath && !config.backPrintFileStoragePath) ||
        (!frontPrintFileSignedUrl && !backPrintFileSignedUrl)) {
        // Attempt regeneration (fallback generates back card only)
        const regenerated = await _regeneratePrintFile(docRef, config, shopifyOrderId);
        if (!regenerated) {
            res.status(200).send('ok');
            return;
        }
        backPrintFileSignedUrl = regenerated.backPrintFileSignedUrl;
    }
    else if (config.printFileExpiresAt) {
        // Refresh signed URL if expiring within 1 hour
        const expiresMs = config.printFileExpiresAt.toDate().getTime();
        const oneHourMs = 60 * 60 * 1000;
        if (expiresMs - Date.now() < oneHourMs) {
            if (config.frontPrintFileStoragePath) {
                frontPrintFileSignedUrl = await _refreshSignedUrl(docRef, config.frontPrintFileStoragePath);
            }
            if (config.backPrintFileStoragePath) {
                backPrintFileSignedUrl = await _refreshSignedUrl(docRef, config.backPrintFileStoragePath);
            }
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
    const files = [];
    if (frontPrintFileSignedUrl) {
        // M76 (ADR-128): use named 'left_chest' placement for left-chest orders so the
        // production print matches the mockup. Pre-M76 configs have frontPosition=null,
        // which falls through to 'default' (center front) — safe backwards-compatible default.
        // NOTE: 'placement' field verified against Printful v2 Orders API 2026-04-23.
        if (config.frontPosition === 'left_chest' || config.frontPosition === 'front_left') {
            files.push({ url: frontPrintFileSignedUrl, placement: 'left_chest' });
        }
        else {
            files.push({ url: frontPrintFileSignedUrl, type: 'default' }); // Printful 'default' = front
        }
    }
    if (backPrintFileSignedUrl) {
        // Image is 3:4 matching the 12×16 in print area. Transparent top gap
        // is baked into the image so Printful auto-fills full-bleed.
        files.push({ url: backPrintFileSignedUrl, type: 'back' });
    }
    try {
        const printfulRes = await fetch('https://api.printful.com/v2/orders', {
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
            }),
        });
        const printfulData = (await printfulRes.json());
        // Log Printful response status and body for sandbox debugging (Task 117).
        console.error(`[shopifyOrderCreated] Printful API response for order ${shopifyOrderId}:`, `status=${printfulRes.status}`, JSON.stringify(printfulData));
        if (!printfulRes.ok || printfulData.error) {
            console.error(`[shopifyOrderCreated] Printful API error for order ${shopifyOrderId}:`, printfulData);
            await docRef.update({ designStatus: 'print_file_error' });
        }
        else {
            await docRef.update({
                printfulOrderId: String(printfulData.id),
                designStatus: 'print_file_submitted',
            });
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
//# sourceMappingURL=index.js.map