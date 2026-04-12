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
const firebase_functions_1 = require("firebase-functions");
const crypto = __importStar(require("crypto"));
const imageGen_1 = require("./imageGen");
const printDimensions_1 = require("./printDimensions");
(0, app_1.initializeApp)();
const db = (0, firestore_1.getFirestore)();
// ── Printful Mockup Generator (ADR-089) ───────────────────────────────────────
/**
 * Calls the Printful v2 Mockup API with BOTH front and back placements in a
 * single request and polls until both mockups are ready.
 * Returns { frontMockupUrl, backMockupUrl } — either may be null on error.
 *
 * Non-blocking: the caller catches errors and proceeds with nulls.
 * Max wait: 10 attempts × 2s = 20 s.
 */
async function generateDualPlacementMockups(printfulVariantId, frontFileUrl, backFileUrl) {
    const apiKey = process.env['PRINTFUL_API_KEY'];
    if (!apiKey) {
        console.error('[mockup] PRINTFUL_API_KEY not set — skipping mockup');
        return { frontMockupUrl: null, backMockupUrl: null };
    }
    // Submit task with both placements in a single request.
    // v2 request shape verified 2026-04-12:
    // - catalog_variant_ids is an ARRAY (singular catalog_variant_id is silently ignored)
    // - products[].source = "catalog", catalog_product_id = 12 (Gildan 64000)
    // - placements[].technique = "dtg"
    // NOTE: Do NOT pass mockup_style_ids — it restricts which variants Printful
    // will generate mockups for, causing it to fall back to variant 473 (White/S)
    // when the requested variant (e.g. Black/L=536) isn't supported by those styles.
    const createRes = await fetch('https://api.printful.com/v2/mockup-tasks', {
        method: 'POST',
        headers: {
            Authorization: `Bearer ${apiKey}`,
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({
            products: [
                {
                    source: 'catalog',
                    catalog_product_id: 12, // Gildan 64000 Unisex Softstyle T-Shirt with Tear Away
                    catalog_variant_ids: [printfulVariantId], // must be array — singular field ignored
                    placements: [
                        ...(frontFileUrl ? [{ placement: 'front', technique: 'dtg', layers: [{ type: 'file', url: frontFileUrl }] }] : []),
                        { placement: 'back', technique: 'dtg', layers: [{ type: 'file', url: backFileUrl }] },
                    ],
                },
            ],
        }),
    });
    if (!createRes.ok) {
        const body = await createRes.text();
        console.error(`[mockup] Create task failed ${createRes.status}: ${body}`);
        return { frontMockupUrl: null, backMockupUrl: null };
    }
    const createData = (await createRes.json());
    const taskId = createData.data?.[0]?.id;
    if (!taskId) {
        console.error('[mockup] No task id in create response', JSON.stringify(createData));
        return { frontMockupUrl: null, backMockupUrl: null };
    }
    // Diagnostic: fetch and log available mockup styles for product 12.
    // Used to identify back-view style IDs (back mockup shows front-facing image
    // by default because Printful uses a front-view template for all placements).
    try {
        const stylesRes = await fetch('https://api.printful.com/v2/catalog-products/12/mockup-styles', {
            headers: { Authorization: `Bearer ${apiKey}` },
        });
        if (stylesRes.ok) {
            // eslint-disable-next-line @typescript-eslint/no-explicit-any
            const stylesData = (await stylesRes.json());
            firebase_functions_1.logger.info('product12_mockup_styles', {
                // eslint-disable-next-line @typescript-eslint/no-explicit-any
                styles: (stylesData.data ?? []).map((s) => ({
                    id: s.id, name: s.name, placement: s.placement,
                })),
            });
        }
    }
    catch { /* non-blocking diagnostic */ }
    // Poll for result. Poll URL: GET /v2/mockup-tasks?id={taskId}
    // Black/grey variants take longer on Printful's end — use 25×3s = 75 s max.
    const maxAttempts = 25;
    const intervalMs = 3000;
    for (let i = 0; i < maxAttempts; i++) {
        await new Promise((resolve) => setTimeout(resolve, intervalMs));
        const pollRes = await fetch(`https://api.printful.com/v2/mockup-tasks?id=${taskId}`, { headers: { Authorization: `Bearer ${apiKey}` } });
        if (!pollRes.ok) {
            console.error(`[mockup] Poll failed ${pollRes.status}`);
            return { frontMockupUrl: null, backMockupUrl: null };
        }
        const pollData = (await pollRes.json());
        const task = pollData.data?.[0];
        const status = task?.status;
        if (status === 'completed') {
            // Prefer the mockup for the exact variant requested; fall back to first.
            // Coerce catalog_variant_id to Number because the Printful API may return
            // it as a string, causing strict === to fail (BUG-001).
            const variantMockups = task?.catalog_variant_mockups ?? [];
            const matched = variantMockups.find((vm) => Number(vm.catalog_variant_id) === printfulVariantId) ??
                variantMockups[0];
            // eslint-disable-next-line @typescript-eslint/no-explicit-any
            const matchedRaw = matched;
            // Printful v2 API may use either `mockups` or `placements` as the array
            // field name inside catalog_variant_mockups entries. Try both.
            // eslint-disable-next-line @typescript-eslint/no-explicit-any
            const mockupItems = (Array.isArray(matchedRaw?.mockups) ? matchedRaw.mockups : null) ??
                (Array.isArray(matchedRaw?.placements) ? matchedRaw.placements : null) ??
                [];
            const frontMockup = mockupItems.find((m) => m.placement === 'front');
            const backMockup = mockupItems.find((m) => m.placement === 'back');
            const resolvedFront = frontMockup?.mockup_url ?? frontMockup?.url ?? null;
            const resolvedBack = backMockup?.mockup_url ?? backMockup?.url ?? null;
            firebase_functions_1.logger.info('mockup_variant_match', {
                requestedVariantId: printfulVariantId,
                foundVariantId: matched?.catalog_variant_id ?? null,
                allVariantIds: variantMockups.map((v) => ({
                    id: v.catalog_variant_id,
                    type: typeof v.catalog_variant_id,
                })),
                matchedKeys: matchedRaw ? Object.keys(matchedRaw) : null,
                mockupItemsCount: mockupItems.length,
                mockupItemPlacements: mockupItems.map((m) => m?.placement ?? Object.keys(m ?? {})),
                mockupItemKeys: mockupItems.map((m) => Object.keys(m ?? {})),
                resolvedFrontUrl: resolvedFront,
                resolvedBackUrl: resolvedBack,
            });
            return {
                frontMockupUrl: resolvedFront,
                backMockupUrl: resolvedBack,
            };
        }
        if (status === 'failed') {
            console.error('[mockup] Printful reported failed status for task', taskId);
            return { frontMockupUrl: null, backMockupUrl: null };
        }
        // status === 'pending' — continue polling
    }
    console.error('[mockup] Timeout waiting for Printful mockup task', taskId);
    return { frontMockupUrl: null, backMockupUrl: null };
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
    // Auth check
    if (!request.auth) {
        throw new https_1.HttpsError('unauthenticated', 'Authentication required.');
    }
    const uid = request.auth.uid;
    // Input validation
    const { variantId, selectedCountryCodes, quantity, cardId, clientCardBase64, frontCardBase64, backCardBase64, artworkConfirmationId, mockupApprovalId } = request.data;
    // Legacy clientCardBase64 is treated as an alias for backCardBase64.
    const backBase64 = backCardBase64 ?? clientCardBase64;
    const frontBase64 = frontCardBase64;
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
    if (typeof backBase64 === 'string' && backBase64.length > 5_500_000) {
        throw new https_1.HttpsError('invalid-argument', 'Card image too large.');
    }
    if (typeof frontBase64 === 'string' && frontBase64.length > 5_500_000) {
        throw new https_1.HttpsError('invalid-argument', 'Front ribbon image too large.');
    }
    // Look up print dimensions for this variant
    const printDims = printDimensions_1.PRINT_DIMENSIONS[variantId];
    if (!printDims) {
        throw new https_1.HttpsError('invalid-argument', `Unknown variantId: ${variantId}`);
    }
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
        // deprecated single-file fields — kept for old document compat
        printFileStoragePath: null,
        printFileSignedUrl: null,
        printFileExpiresAt: null,
        printfulOrderId: null,
        // deprecated mockupUrl — kept for old code compat
        mockupUrl: null,
        // M38 field (ADR-093): links this order to the originating TravelCard, if any
        cardId: typeof cardId === 'string' ? cardId : null,
        // deprecated placement field — kept for old document compat (M63: always both for t-shirts)
        placement: 'front',
        // M48 field (ADR-100): links this order to the ArtworkConfirmation the user approved
        artworkConfirmationId: typeof artworkConfirmationId === 'string' ? artworkConfirmationId : null,
        // M53 field (ADR-105): links this order to the MockupApproval the user confirmed
        mockupApprovalId: typeof mockupApprovalId === 'string' ? mockupApprovalId : null,
        // M63 fields: dual-placement print files
        frontPrintFileStoragePath: null,
        frontPrintFileSignedUrl: null,
        frontPrintFileExpiresAt: null,
        backPrintFileStoragePath: null,
        backPrintFileSignedUrl: null,
        backPrintFileExpiresAt: null,
        frontMockupUrl: null,
        backMockupUrl: null,
    };
    await configRef.set(configData);
    // ── Step 2 & 3: Generate preview + print PNGs ──────────────────────────
    const bucket = (0, storage_1.getStorage)().bucket();
    const previewPath = `previews/${configId}.jpg`;
    const backPath = `print_files/${configId}_back.png`;
    let previewUrl;
    let backSignedUrl;
    let backExpiresAt;
    let frontPrintBuf = null;
    let frontSignedUrl = null;
    let frontExpiresAt = null;
    let frontPath = null;
    // Front ribbon left-chest position on 4500×5400 DTG canvas (150 DPI).
    // Calibrated 2026-04-12 to match the local mockup spec (product_mockup_specs.dart):
    //   local front print area: left=0.55, top=0.25, width=0.18, height=0.25 (800×1066 image)
    //   => DTG canvas center x ≈ (0.55 + 0.18/2) × 4500 = 2880 px
    //   => DTG canvas top    y ≈ 0.25 × 5400 = 1350 px
    // Ribbon width doubled to 1200 px (8 in) per user calibration.
    // Left edge = center − width/2 = 2880 − 600 = 2280 px.
    const RIBBON_WIDTH_PX = 1200;
    const RIBBON_OFFSET_LEFT_PX = 3000; // wearer's left chest (viewer's right)
    const RIBBON_OFFSET_TOP_PX = 1350; // ~9 in from top edge
    try {
        const sharp = (await Promise.resolve().then(() => __importStar(require('sharp')))).default;
        let previewJpeg;
        let backPrintBuf;
        if (typeof backBase64 === 'string' && backBase64.length > 0) {
            // Use the client-rendered card image (passport, heart, or grid) so the
            // t-shirt mockup matches what the user designed rather than always the
            // flag grid.
            const clientBuf = Buffer.from(backBase64, 'base64');
            const bgColour = printDims.backgroundColor === 'transparent'
                ? { r: 0, g: 0, b: 0, alpha: 0 }
                : { r: 255, g: 255, b: 255, alpha: 1 };
            previewJpeg = await sharp(clientBuf)
                .resize(800, 600, { fit: 'contain', background: { r: 255, g: 255, b: 255, alpha: 1 } })
                .toFormat('jpeg', { quality: 80 })
                .toBuffer();
            backPrintBuf = await sharp(clientBuf)
                .resize(printDims.widthPx, printDims.heightPx, { fit: 'contain', background: bgColour })
                .toFormat('png')
                .toBuffer();
        }
        else {
            // Server-side flag grid generation (fallback when no client image provided)
            const previewPng = await (0, imageGen_1.generateFlagGrid)({
                templateId: 'flag_grid_v1',
                selectedCountryCodes,
                widthPx: 800,
                heightPx: 600,
                dpi: 96,
                backgroundColor: 'white',
            });
            previewJpeg = await sharp(previewPng)
                .toFormat('jpeg', { quality: 80 })
                .toBuffer();
            backPrintBuf = await (0, imageGen_1.generateFlagGrid)({
                templateId: 'flag_grid_v1',
                selectedCountryCodes,
                widthPx: printDims.widthPx,
                heightPx: printDims.heightPx,
                dpi: printDims.dpi,
                backgroundColor: printDims.backgroundColor,
            });
        }
        // Generate front print file from frontBase64 (only for t-shirts with a front ribbon)
        if (typeof frontBase64 === 'string' && frontBase64.length > 0 && printDims.widthPx > 0) {
            const ribbonBuf = Buffer.from(frontBase64, 'base64');
            const resizedRibbon = await sharp(ribbonBuf)
                .resize(RIBBON_WIDTH_PX, null, { fit: 'inside' })
                .png()
                .toBuffer();
            frontPrintBuf = await sharp({
                create: {
                    width: printDims.widthPx,
                    height: printDims.heightPx,
                    channels: 4,
                    background: { r: 0, g: 0, b: 0, alpha: 0 },
                },
            })
                .composite([{ input: resizedRibbon, left: RIBBON_OFFSET_LEFT_PX, top: RIBBON_OFFSET_TOP_PX }])
                .png()
                .toBuffer();
        }
        // Upload preview (public read)
        const previewFile = bucket.file(previewPath);
        await previewFile.save(previewJpeg, {
            metadata: { contentType: 'image/jpeg' },
            public: true,
        });
        previewUrl = previewFile.publicUrl();
        // Upload back print file (private — signed URL only)
        const backFile = bucket.file(backPath);
        await backFile.save(backPrintBuf, {
            metadata: { contentType: 'image/png' },
        });
        // Generate 7-day signed URL for back file
        backExpiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
        const [backUrl] = await backFile.getSignedUrl({
            action: 'read',
            expires: backExpiresAt,
        });
        backSignedUrl = backUrl;
        // Upload front print file if generated
        if (frontPrintBuf) {
            frontPath = `print_files/${configId}_front.png`;
            const frontFile = bucket.file(frontPath);
            await frontFile.save(frontPrintBuf, {
                metadata: { contentType: 'image/png' },
            });
            frontExpiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
            const [fUrl] = await frontFile.getSignedUrl({
                action: 'read',
                expires: frontExpiresAt,
            });
            frontSignedUrl = fUrl;
        }
        // Update MerchConfig: files_ready
        await configRef.update({
            designStatus: 'files_ready',
            previewStoragePath: previewPath,
            backPrintFileStoragePath: backPath,
            backPrintFileSignedUrl: backSignedUrl,
            backPrintFileExpiresAt: firestore_1.Timestamp.fromDate(backExpiresAt),
            // front fields only if front file was generated
            ...(frontPrintBuf && frontPath && frontSignedUrl && frontExpiresAt ? {
                frontPrintFileStoragePath: frontPath,
                frontPrintFileSignedUrl: frontSignedUrl,
                frontPrintFileExpiresAt: firestore_1.Timestamp.fromDate(frontExpiresAt),
            } : {}),
            // deprecated back fields — keep pointing to back file so old webhook code still works
            printFileStoragePath: backPath,
            printFileSignedUrl: backSignedUrl,
            printFileExpiresAt: firestore_1.Timestamp.fromDate(backExpiresAt),
        });
    }
    catch (err) {
        await configRef.update({ designStatus: 'generation_error' });
        console.error(`[createMerchCart] Image generation failed for ${configId}:`, err);
        throw new https_1.HttpsError('internal', 'Design generation failed. Please try again.');
    }
    // ── Step 4: Create Shopify cart ────────────────────────────────────────
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
    // ── Step 5: Generate Printful mockups (non-blocking) ───────────────────
    // Skip for poster variants (printfulVariantId === 0 = not configured).
    let frontMockupUrl = null;
    let backMockupUrl = null;
    const printfulVariantId = printDimensions_1.PRINTFUL_VARIANT_IDS[variantId] ?? 0;
    if (printfulVariantId !== 0 && backSignedUrl) {
        try {
            const mockups = await generateDualPlacementMockups(printfulVariantId, frontSignedUrl, // null if no front print file — omits front placement from request
            backSignedUrl);
            frontMockupUrl = mockups.frontMockupUrl;
            backMockupUrl = mockups.backMockupUrl;
        }
        catch (err) {
            // Mockup failure must never block checkout.
            console.error(`[createMerchCart] Mockup generation threw for ${configId}:`, err);
        }
    }
    await configRef.update({
        frontMockupUrl: frontMockupUrl ?? null,
        backMockupUrl: backMockupUrl ?? null,
        mockupUrl: backMockupUrl ?? null, // deprecated field for old code compat
    });
    return {
        checkoutUrl: cart.checkoutUrl,
        cartId: cart.id,
        merchConfigId: configId,
        previewUrl,
        mockupUrl: backMockupUrl ?? null, // deprecated
        frontMockupUrl: frontMockupUrl ?? null,
        backMockupUrl: backMockupUrl ?? null,
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
    let printFileSignedUrl = config.printFileSignedUrl;
    if (config.designStatus === 'generation_error' ||
        !config.printFileStoragePath ||
        !printFileSignedUrl) {
        // Attempt regeneration
        printFileSignedUrl = await _regeneratePrintFile(docRef, config, shopifyOrderId);
        if (!printFileSignedUrl) {
            res.status(200).send('ok');
            return;
        }
    }
    else if (config.printFileExpiresAt) {
        // Refresh signed URL if expiring within 1 hour
        const expiresMs = config.printFileExpiresAt.toDate().getTime();
        const oneHourMs = 60 * 60 * 1000;
        if (expiresMs - Date.now() < oneHourMs) {
            printFileSignedUrl = await _refreshSignedUrl(docRef, config.printFileStoragePath);
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
    // Determine which files to send to Printful
    const isSingleFileOrder = !config.frontPrintFileStoragePath;
    let printfulFiles;
    if (isSingleFileOrder) {
        // Backward compat: old single-file order
        printfulFiles = [{ url: printFileSignedUrl, type: 'default' }];
    }
    else {
        // New dual-file order
        let frontSignedUrlForOrder = config.frontPrintFileSignedUrl;
        // Refresh front URL if expiring within 1 hour
        if (config.frontPrintFileExpiresAt) {
            const expiresMs = config.frontPrintFileExpiresAt.toDate().getTime();
            if (expiresMs - Date.now() < 60 * 60 * 1000) {
                frontSignedUrlForOrder = await _refreshSignedUrl(docRef, config.frontPrintFileStoragePath);
            }
        }
        if (!frontSignedUrlForOrder) {
            // Front URL missing despite storage path being set — fall back to single-file.
            console.warn(`[shopifyOrderCreated] frontPrintFileSignedUrl missing for ${merchConfigId} — falling back to single-file order`);
            printfulFiles = [{ url: printFileSignedUrl, type: 'default' }];
        }
        else {
            printfulFiles = [
                { url: frontSignedUrlForOrder, type: 'front' },
                { url: printFileSignedUrl, type: 'back' },
            ];
        }
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
                        files: printfulFiles,
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
        const printPath = `print_files/${config.configId}.png`;
        const printFile = bucket.file(printPath);
        await printFile.save(printBuf, { metadata: { contentType: 'image/png' } });
        const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
        const [signedUrl] = await printFile.getSignedUrl({
            action: 'read',
            expires: expiresAt,
        });
        await docRef.update({
            designStatus: 'files_ready',
            printFileStoragePath: printPath,
            printFileSignedUrl: signedUrl,
            printFileExpiresAt: firestore_1.Timestamp.fromDate(expiresAt),
        });
        return signedUrl;
    }
    catch (err) {
        console.error(`[_regeneratePrintFile] Regeneration failed for order ${shopifyOrderId}:`, err);
        await docRef.update({ designStatus: 'print_file_error' });
        return null;
    }
}
/**
 * Refreshes the signed URL for an existing print file in Firebase Storage.
 * Updates Firestore with the new URL and expiry. Returns the new signed URL.
 */
async function _refreshSignedUrl(docRef, printFileStoragePath) {
    const bucket = (0, storage_1.getStorage)().bucket();
    const printFile = bucket.file(printFileStoragePath);
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
    const [signedUrl] = await printFile.getSignedUrl({
        action: 'read',
        expires: expiresAt,
    });
    await docRef.update({
        printFileSignedUrl: signedUrl,
        printFileExpiresAt: firestore_1.Timestamp.fromDate(expiresAt),
    });
    return signedUrl;
}
//# sourceMappingURL=index.js.map