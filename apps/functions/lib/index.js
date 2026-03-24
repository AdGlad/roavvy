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
/**
 * Calls the Printful v2 Mockup API and polls until a front-placement mockup
 * is ready. Returns the mockup image URL or null on timeout / error.
 *
 * Non-blocking: the caller catches errors and proceeds with null.
 * Max wait: 10 attempts × 2s = 20 s.
 */
async function generatePrintfulMockup(printfulVariantId, printFileUrl) {
    const apiKey = process.env['PRINTFUL_API_KEY'];
    if (!apiKey) {
        console.error('[mockup] PRINTFUL_API_KEY not set — skipping mockup');
        return null;
    }
    // Submit task
    const createRes = await fetch('https://api.printful.com/v2/mockup-tasks', {
        method: 'POST',
        headers: {
            Authorization: `Bearer ${apiKey}`,
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({
            variant_ids: [printfulVariantId],
            files: [{ placement: 'front', url: printFileUrl }],
            format: 'jpg',
        }),
    });
    if (!createRes.ok) {
        const body = await createRes.text();
        console.error(`[mockup] Create task failed ${createRes.status}: ${body}`);
        return null;
    }
    const createData = (await createRes.json());
    const taskKey = createData.data?.task_key;
    if (!taskKey) {
        console.error('[mockup] No task_key in create response');
        return null;
    }
    // Poll for result
    const maxAttempts = 10;
    const intervalMs = 2000;
    for (let i = 0; i < maxAttempts; i++) {
        await new Promise((resolve) => setTimeout(resolve, intervalMs));
        const pollRes = await fetch(`https://api.printful.com/v2/mockup-tasks/${taskKey}`, { headers: { Authorization: `Bearer ${apiKey}` } });
        if (!pollRes.ok) {
            console.error(`[mockup] Poll failed ${pollRes.status}`);
            return null;
        }
        const pollData = (await pollRes.json());
        const status = pollData.data?.status;
        if (status === 'completed') {
            const mockup = pollData.data?.mockups?.find((m) => m.placement === 'front');
            if (!mockup) {
                console.error('[mockup] Completed but no front placement in result');
                return null;
            }
            return mockup.mockup_url;
        }
        if (status === 'error') {
            console.error('[mockup] Printful reported error status for task', taskKey);
            return null;
        }
        // status === 'waiting' — continue polling
    }
    console.error('[mockup] Timeout waiting for Printful mockup task', taskKey);
    return null;
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
    const { variantId, selectedCountryCodes, quantity } = request.data;
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
        printFileStoragePath: null,
        printFileSignedUrl: null,
        printFileExpiresAt: null,
        printfulOrderId: null,
        // M34 field
        mockupUrl: null,
    };
    await configRef.set(configData);
    // ── Step 2 & 3: Generate preview + print PNGs ──────────────────────────
    const bucket = (0, storage_1.getStorage)().bucket();
    const previewPath = `previews/${configId}.jpg`;
    const printPath = `print_files/${configId}.png`;
    let previewUrl;
    let printFileSignedUrl;
    try {
        // Preview PNG (web-optimised: 800×600 @ 96 DPI, JPEG 80)
        const previewBuf = await (0, imageGen_1.generateFlagGrid)({
            templateId: 'flag_grid_v1',
            selectedCountryCodes,
            widthPx: 800,
            heightPx: 600,
            dpi: 96,
            backgroundColor: 'white',
        });
        // Convert PNG → JPEG at quality 80 (sharp is already imported in imageGen)
        // The generateFlagGrid returns PNG; we re-encode here to JPEG for preview
        const sharp = (await Promise.resolve().then(() => __importStar(require('sharp')))).default;
        const previewJpeg = await sharp(previewBuf)
            .toFormat('jpeg', { quality: 80 })
            .toBuffer();
        // Print PNG (full resolution at product dimensions)
        const printBuf = await (0, imageGen_1.generateFlagGrid)({
            templateId: 'flag_grid_v1',
            selectedCountryCodes,
            widthPx: printDims.widthPx,
            heightPx: printDims.heightPx,
            dpi: printDims.dpi,
            backgroundColor: printDims.backgroundColor,
        });
        // Upload preview (public read)
        const previewFile = bucket.file(previewPath);
        await previewFile.save(previewJpeg, {
            metadata: { contentType: 'image/jpeg' },
            public: true,
        });
        previewUrl = previewFile.publicUrl();
        // Upload print file (private — signed URL only)
        const printFile = bucket.file(printPath);
        await printFile.save(printBuf, {
            metadata: { contentType: 'image/png' },
        });
        // Generate 7-day signed URL
        const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
        const [signedUrl] = await printFile.getSignedUrl({
            action: 'read',
            expires: expiresAt,
        });
        printFileSignedUrl = signedUrl;
        // Update MerchConfig: files_ready
        await configRef.update({
            designStatus: 'files_ready',
            previewStoragePath: previewPath,
            printFileStoragePath: printPath,
            printFileSignedUrl,
            printFileExpiresAt: firestore_1.Timestamp.fromDate(expiresAt),
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
    // ── Step 5: Generate Printful mockup (non-blocking) ────────────────────
    // Skip for poster variants (printfulVariantId === 0 = not configured).
    let mockupUrl = null;
    const printfulVariantId = printDimensions_1.PRINTFUL_VARIANT_IDS[variantId] ?? 0;
    if (printfulVariantId !== 0) {
        try {
            mockupUrl = await generatePrintfulMockup(printfulVariantId, printFileSignedUrl);
        }
        catch (err) {
            // Mockup failure must never block checkout.
            console.error(`[createMerchCart] Mockup generation threw for ${configId}:`, err);
        }
    }
    if (mockupUrl) {
        await configRef.update({ mockupUrl });
    }
    return {
        checkoutUrl: cart.checkoutUrl,
        cartId: cart.id,
        merchConfigId: configId,
        previewUrl,
        mockupUrl,
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
                        files: [{ url: printFileSignedUrl, type: 'default' }],
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