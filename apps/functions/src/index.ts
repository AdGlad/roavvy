import * as dotenv from 'dotenv';
dotenv.config();

import { initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { onCall, HttpsError, onRequest } from 'firebase-functions/v2/https';
import * as crypto from 'crypto';
import type {
  MerchConfig,
  CreateMerchCartRequest,
  CreateMerchCartResponse,
  ShopifyCartCreateResponse,
} from './types';
import { generateFlagGrid } from './imageGen';
import { PRINT_DIMENSIONS, PRINTFUL_VARIANT_IDS } from './printDimensions';

initializeApp();
const db = getFirestore();

// ── Printful Mockup Generator (ADR-089) ───────────────────────────────────────

/**
 * Calls the Printful v2 Mockup API and polls until the requested placement
 * mockup is ready. Returns the mockup image URL or null on timeout / error.
 *
 * Non-blocking: the caller catches errors and proceeds with null.
 * Max wait: 10 attempts × 2s = 20 s.
 */
async function generatePrintfulMockup(
  printfulVariantId: number,
  frontPrintFileUrl: string | null,
  backPrintFileUrl: string | null
): Promise<{ frontMockupUrl: string | null; backMockupUrl: string | null }> {
  const apiKey = process.env['PRINTFUL_API_KEY'];
  if (!apiKey) {
    console.error('[mockup] PRINTFUL_API_KEY not set — skipping mockup');
    return { frontMockupUrl: null, backMockupUrl: null };
  }

  const placements = [];
  if (frontPrintFileUrl) {
    placements.push({
      placement: 'front',
      technique: 'dtg',
      layers: [{ type: 'file', url: frontPrintFileUrl }],
    });
  }
  if (backPrintFileUrl) {
    placements.push({
      placement: 'back',
      technique: 'dtg',
      layers: [{ type: 'file', url: backPrintFileUrl }],
    });
  }

  if (placements.length === 0) {
    return { frontMockupUrl: null, backMockupUrl: null };
  }

  // Submit task.
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
          catalog_product_id: 12, // Gildan 64000 Unisex Softstyle T-Shirt
          catalog_variant_id: printfulVariantId,
          placements,
        },
      ],
    }),
  });

  if (!createRes.ok) {
    const body = await createRes.text();
    console.error(`[mockup] Create task failed ${createRes.status}: ${body}`);
    return { frontMockupUrl: null, backMockupUrl: null };
  }

  const createData = (await createRes.json()) as {
    data?: Array<{ id?: number; status?: string }>;
  };
  const taskId = createData.data?.[0]?.id;
  if (!taskId) {
    console.error('[mockup] No task id in create response', JSON.stringify(createData));
    return { frontMockupUrl: null, backMockupUrl: null };
  }

  // Poll for result. Poll URL: GET /v2/mockup-tasks?id={taskId}
  const maxAttempts = 10;
  const intervalMs = 2000;

  for (let i = 0; i < maxAttempts; i++) {
    await new Promise((resolve) => setTimeout(resolve, intervalMs));

    const pollRes = await fetch(
      `https://api.printful.com/v2/mockup-tasks?id=${taskId}`,
      { headers: { Authorization: `Bearer ${apiKey}` } }
    );

    if (!pollRes.ok) {
      console.error(`[mockup] Poll failed ${pollRes.status}`);
      return { frontMockupUrl: null, backMockupUrl: null };
    }

    const pollData = (await pollRes.json()) as {
      data?: Array<{
        status?: string;
        catalog_variant_mockups?: Array<{
          catalog_variant_id: number;
          mockups: Array<{ placement: string; mockup_url: string }>;
        }>;
      }>;
    };

    const task = pollData.data?.[0];
    const status = task?.status;

    if (status === 'completed') {
      const variantMockups = task?.catalog_variant_mockups ?? [];
      const matched =
        variantMockups.find((vm) => Number(vm.catalog_variant_id) === printfulVariantId) ??
        variantMockups[0];
      
      const frontMockupUrl = matched?.mockups.find((m) => m.placement === 'front')?.mockup_url ?? null;
      const backMockupUrl = matched?.mockups.find((m) => m.placement === 'back')?.mockup_url ?? null;
      return { frontMockupUrl, backMockupUrl };
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
export const createMerchCart = onCall<
  CreateMerchCartRequest,
  Promise<CreateMerchCartResponse>
>(
  { timeoutSeconds: 300, memory: '2GiB' },
  async (request) => {
    // Auth check
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required.');
    }
    const uid = request.auth.uid;

    // Input validation
    const { variantId, selectedCountryCodes, quantity, cardId, clientCardBase64, frontImageBase64, backImageBase64, artworkConfirmationId, mockupApprovalId } = request.data;
    if (!variantId || typeof variantId !== 'string') {
      throw new HttpsError('invalid-argument', 'variantId is required.');
    }
    if (
      !Array.isArray(selectedCountryCodes) ||
      selectedCountryCodes.length === 0
    ) {
      throw new HttpsError(
        'invalid-argument',
        'selectedCountryCodes must be a non-empty array.'
      );
    }
    if (typeof quantity !== 'number' || quantity < 1) {
      throw new HttpsError('invalid-argument', 'quantity must be at least 1.');
    }
    const resolvedBackBase64 = typeof backImageBase64 === 'string' ? backImageBase64 : (typeof clientCardBase64 === 'string' ? clientCardBase64 : null);
    if (resolvedBackBase64 && resolvedBackBase64.length > 5_500_000) {
      throw new HttpsError('invalid-argument', 'Back card image too large.');
    }
    if (typeof frontImageBase64 === 'string' && frontImageBase64.length > 5_500_000) {
      throw new HttpsError('invalid-argument', 'Front card image too large.');
    }

    // Look up print dimensions for this variant
    const printDims = PRINT_DIMENSIONS[variantId];
    if (!printDims) {
      throw new HttpsError(
        'invalid-argument',
        `Unknown variantId: ${variantId}`
      );
    }

    // ── Step 1: Write initial MerchConfig ──────────────────────────────────
    const configRef = db
      .collection('users')
      .doc(uid)
      .collection('merch_configs')
      .doc();
    const configId = configRef.id;

    const configData: MerchConfig = {
      configId,
      userId: uid,
      variantId,
      selectedCountryCodes,
      quantity,
      shopifyCartId: null,
      shopifyOrderId: null,
      status: 'pending',
      createdAt: Timestamp.now(),
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
      // M38 field (ADR-093): links this order to the originating TravelCard, if any
      cardId: typeof cardId === 'string' ? cardId : null,
      // M48 field (ADR-100): links this order to the ArtworkConfirmation the user approved
      artworkConfirmationId: typeof artworkConfirmationId === 'string' ? artworkConfirmationId : null,
      // M53 field (ADR-105): links this order to the MockupApproval the user confirmed
      mockupApprovalId: typeof mockupApprovalId === 'string' ? mockupApprovalId : null,
    };
    await configRef.set(configData);

    // ── Step 2 & 3: Generate preview + print PNGs ──────────────────────────
    const bucket = getStorage().bucket();
    const previewPath = `previews/${configId}.jpg`;
    const frontPrintPath = `front_print_files/${configId}.png`;
    const backPrintPath = `back_print_files/${configId}.png`;
    let previewUrl: string;
    let frontPrintFileSignedUrl: string | null = null;
    let backPrintFileSignedUrl: string | null = null;

    try {
      const sharp = (await import('sharp')).default;
      let previewJpeg: Buffer | null = null;
      let frontPrintBuf: Buffer | null = null;
      let backPrintBuf: Buffer | null = null;

      const bgColour = printDims.backgroundColor === 'transparent'
        ? { r: 0, g: 0, b: 0, alpha: 0 }
        : { r: 255, g: 255, b: 255, alpha: 1 };

      // Process front image if provided
      if (typeof frontImageBase64 === 'string' && frontImageBase64.length > 0) {
        const clientBuf = Buffer.from(frontImageBase64, 'base64');
        frontPrintBuf = await sharp(clientBuf)
          .resize(printDims.widthPx, printDims.heightPx, { fit: 'contain', background: bgColour })
          .toFormat('png')
          .toBuffer();
      }

      // Process back image if provided
      if (typeof resolvedBackBase64 === 'string' && resolvedBackBase64.length > 0) {
        const clientBuf = Buffer.from(resolvedBackBase64, 'base64');
        
        // Preview generated from the back card (primary design)
        previewJpeg = await sharp(clientBuf)
          .resize(800, 600, { fit: 'contain', background: { r: 255, g: 255, b: 255, alpha: 1 } })
          .toFormat('jpeg', { quality: 80 })
          .toBuffer();

        backPrintBuf = await sharp(clientBuf)
          .resize(printDims.widthPx, printDims.heightPx, { fit: 'contain', background: bgColour })
          .toFormat('png')
          .toBuffer();
      }

      // Fallback: Server-side flag grid generation
      if (!frontPrintBuf && !backPrintBuf) {
        const previewPng = await generateFlagGrid({
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

        backPrintBuf = await generateFlagGrid({
          templateId: 'flag_grid_v1',
          selectedCountryCodes,
          widthPx: printDims.widthPx,
          heightPx: printDims.heightPx,
          dpi: printDims.dpi,
          backgroundColor: printDims.backgroundColor,
        });
      }

      // Upload preview (public read)
      if (!previewJpeg && frontPrintBuf) {
        // Edge case: no back image, generate preview from front image
        previewJpeg = await sharp(frontPrintBuf)
          .resize(800, 600, { fit: 'contain', background: { r: 255, g: 255, b: 255, alpha: 1 } })
          .toFormat('jpeg', { quality: 80 })
          .toBuffer();
      }
      
      const previewFile = bucket.file(previewPath);
      await previewFile.save(previewJpeg!, {
        metadata: { contentType: 'image/jpeg' },
        public: true,
      });
      previewUrl = previewFile.publicUrl();

      const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);

      // Upload front print file (private)
      if (frontPrintBuf) {
        const frontPrintFile = bucket.file(frontPrintPath);
        await frontPrintFile.save(frontPrintBuf, { metadata: { contentType: 'image/png' } });
        const [signedUrl] = await frontPrintFile.getSignedUrl({ action: 'read', expires: expiresAt });
        frontPrintFileSignedUrl = signedUrl;
      }

      // Upload back print file (private)
      if (backPrintBuf) {
        const backPrintFile = bucket.file(backPrintPath);
        await backPrintFile.save(backPrintBuf, { metadata: { contentType: 'image/png' } });
        const [signedUrl] = await backPrintFile.getSignedUrl({ action: 'read', expires: expiresAt });
        backPrintFileSignedUrl = signedUrl;
      }

      // Update MerchConfig: files_ready
      await configRef.update({
        designStatus: 'files_ready',
        previewStoragePath: previewPath,
        frontPrintFileStoragePath: frontPrintBuf ? frontPrintPath : null,
        frontPrintFileSignedUrl,
        backPrintFileStoragePath: backPrintBuf ? backPrintPath : null,
        backPrintFileSignedUrl,
        printFileExpiresAt: Timestamp.fromDate(expiresAt),
      });
    } catch (err) {
      await configRef.update({ designStatus: 'generation_error' });
      console.error(`[createMerchCart] Image generation failed for ${configId}:`, err);
      throw new HttpsError(
        'internal',
        'Design generation failed. Please try again.'
      );
    }

    // ── Step 4: Create Shopify cart ────────────────────────────────────────
    const storefrontToken = process.env['SHOPIFY_STOREFRONT_TOKEN'];
    const storeDomain = process.env['SHOPIFY_STORE_DOMAIN'];
    if (!storefrontToken || !storeDomain) {
      throw new HttpsError('internal', 'Storefront configuration missing.');
    }

    const variables = {
      lines: [{ merchandiseId: variantId, quantity }],
      attributes: [{ key: 'merchConfigId', value: configId }],
    };

    const shopifyRes = await fetch(
      `https://${storeDomain}/api/2025-01/graphql.json`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Shopify-Storefront-Access-Token': storefrontToken,
        },
        body: JSON.stringify({ query: CART_CREATE_MUTATION, variables }),
      }
    );

    if (!shopifyRes.ok) {
      throw new HttpsError(
        'internal',
        `Shopify request failed: ${shopifyRes.status}`
      );
    }

    const shopifyData = (await shopifyRes.json()) as ShopifyCartCreateResponse;

    if (shopifyData.errors && shopifyData.errors.length > 0) {
      throw new HttpsError('internal', shopifyData.errors[0].message);
    }

    const cartCreate = shopifyData.data?.cartCreate;
    if (!cartCreate) {
      throw new HttpsError('internal', 'Shopify returned no cartCreate data.');
    }

    if (cartCreate.userErrors.length > 0) {
      throw new HttpsError('invalid-argument', cartCreate.userErrors[0].message);
    }

    const cart = cartCreate.cart;
    if (!cart) {
      throw new HttpsError('internal', 'Shopify cartCreate returned no cart.');
    }

    // Update MerchConfig with cart ID
    await configRef.update({ shopifyCartId: cart.id, status: 'cart_created' });

    // ── Step 5: Generate Printful mockup (non-blocking) ────────────────────
    // Skip for poster variants (printfulVariantId === 0 = not configured).
    let frontMockupUrl: string | null = null;
    let backMockupUrl: string | null = null;
    const printfulVariantId = PRINTFUL_VARIANT_IDS[variantId] ?? 0;

    if (printfulVariantId !== 0) {
      try {
        const mockups = await generatePrintfulMockup(
          printfulVariantId,
          frontPrintFileSignedUrl,
          backPrintFileSignedUrl
        );
        frontMockupUrl = mockups.frontMockupUrl;
        backMockupUrl = mockups.backMockupUrl;
      } catch (err) {
        // Mockup failure must never block checkout.
        console.error(
          `[createMerchCart] Mockup generation threw for ${configId}:`,
          err
        );
      }
    }

    if (frontMockupUrl || backMockupUrl) {
      await configRef.update({ frontMockupUrl, backMockupUrl });
    }

    return {
      checkoutUrl: cart.checkoutUrl,
      cartId: cart.id,
      merchConfigId: configId,
      previewUrl,
      frontMockupUrl,
      backMockupUrl,
    };
  }
);

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
export const shopifyOrderCreated = onRequest(
  { invoker: 'public' },
  async (req, res) => {
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
    const hmacHeader = req.headers['x-shopify-hmac-sha256'] as
      | string
      | undefined;
    if (!hmacHeader) {
      res.status(401).send('Missing HMAC header');
      return;
    }

    const rawBody = (req as unknown as { rawBody: Buffer }).rawBody;
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
    if (
      hmacHeaderBuf.length !== expectedBuf.length ||
      !crypto.timingSafeEqual(hmacHeaderBuf, expectedBuf)
    ) {
      res.status(401).send('HMAC verification failed');
      return;
    }

    // Parse Shopify order payload
    const payload = req.body as {
      id?: number;
      note_attributes?: Array<{ name: string; value: string }>;
      shipping_address?: {
        name?: string;
        address1?: string;
        address2?: string;
        city?: string;
        province_code?: string;
        zip?: string;
        country_code?: string;
        phone?: string;
      };
    };

    const shopifyOrderId = payload.id?.toString() ?? null;
    if (!shopifyOrderId) {
      res.status(200).send('ok');
      return;
    }

    const noteAttrs = payload.note_attributes ?? [];
    // Log note_attributes so the first test order makes the payload visible in Cloud Logging.
    console.error(
      `[shopifyOrderCreated] order ${shopifyOrderId} note_attributes:`,
      JSON.stringify(noteAttrs)
    );
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
    const config = snap.docs[0].data() as MerchConfig;

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
        } else {
          console.warn(
            `[shopifyOrderCreated] ArtworkConfirmation not found: ${config.artworkConfirmationId}`
          );
        }
      } catch (err) {
        console.error(
          `[shopifyOrderCreated] Failed to link ArtworkConfirmation ${config.artworkConfirmationId}:`,
          err
        );
      }
    }

    // ── Validate / refresh print file ──────────────────────────────────────
    let frontPrintFileSignedUrl = config.frontPrintFileSignedUrl;
    let backPrintFileSignedUrl = config.backPrintFileSignedUrl;

    if (
      config.designStatus === 'generation_error' ||
      (!config.frontPrintFileStoragePath && !config.backPrintFileStoragePath) ||
      (!frontPrintFileSignedUrl && !backPrintFileSignedUrl)
    ) {
      // Attempt regeneration (fallback generates back card only)
      const regenerated = await _regeneratePrintFile(
        docRef,
        config,
        shopifyOrderId
      );
      if (!regenerated) {
        res.status(200).send('ok');
        return;
      }
      backPrintFileSignedUrl = regenerated.backPrintFileSignedUrl;
    } else if (config.printFileExpiresAt) {
      // Refresh signed URL if expiring within 1 hour
      const expiresMs = config.printFileExpiresAt.toDate().getTime();
      const oneHourMs = 60 * 60 * 1000;
      if (expiresMs - Date.now() < oneHourMs) {
        if (config.frontPrintFileStoragePath) {
          frontPrintFileSignedUrl = await _refreshSignedUrl(
            docRef,
            config.frontPrintFileStoragePath
          );
        }
        if (config.backPrintFileStoragePath) {
          backPrintFileSignedUrl = await _refreshSignedUrl(
            docRef,
            config.backPrintFileStoragePath
          );
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

    const printfulVariantId = PRINTFUL_VARIANT_IDS[config.variantId];
    if (!printfulVariantId) {
      console.error(
        `[shopifyOrderCreated] No Printful variant ID for Shopify GID: ${config.variantId}`
      );
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
      files.push({ url: frontPrintFileSignedUrl, type: 'default' }); // Printful 'default' = front
    }
    if (backPrintFileSignedUrl) {
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

      const printfulData = (await printfulRes.json()) as {
        id?: string | number;
        error?: string;
      };

      // Log Printful response status and body for sandbox debugging (Task 117).
      console.error(
        `[shopifyOrderCreated] Printful API response for order ${shopifyOrderId}:`,
        `status=${printfulRes.status}`,
        JSON.stringify(printfulData)
      );

      if (!printfulRes.ok || printfulData.error) {
        console.error(
          `[shopifyOrderCreated] Printful API error for order ${shopifyOrderId}:`,
          printfulData
        );
        await docRef.update({ designStatus: 'print_file_error' });
      } else {
        await docRef.update({
          printfulOrderId: String(printfulData.id),
          designStatus: 'print_file_submitted',
        });
      }
    } catch (err) {
      console.error(
        `[shopifyOrderCreated] Printful request threw for order ${shopifyOrderId}:`,
        err
      );
      await docRef.update({ designStatus: 'print_file_error' });
    }

    res.status(200).send('ok');
  }
);

// ── Private helpers ───────────────────────────────────────────────────────────

/**
 * Attempt to regenerate the print file for a MerchConfig whose generation
 * previously failed or whose file is missing. Updates Firestore on success or
 * failure. Returns the new signed URL on success, null on failure.
 */
async function _regeneratePrintFile(
  docRef: FirebaseFirestore.DocumentReference,
  config: MerchConfig,
  shopifyOrderId: string
): Promise<{ backPrintFileSignedUrl: string } | null> {
  const printDims = PRINT_DIMENSIONS[config.variantId];
  if (!printDims) {
    console.error(
      `[_regeneratePrintFile] No print dimensions for variant ${config.variantId}`
    );
    await docRef.update({ designStatus: 'print_file_error' });
    return null;
  }

  try {
    const printBuf = await generateFlagGrid({
      templateId: 'flag_grid_v1',
      selectedCountryCodes: config.selectedCountryCodes,
      widthPx: printDims.widthPx,
      heightPx: printDims.heightPx,
      dpi: printDims.dpi,
      backgroundColor: printDims.backgroundColor,
    });

    const bucket = getStorage().bucket();
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
      printFileExpiresAt: Timestamp.fromDate(expiresAt),
    });
    
    return { backPrintFileSignedUrl: signedUrl };
  } catch (err) {
    console.error(
      `[_regeneratePrintFile] Regeneration failed for order ${shopifyOrderId}:`,
      err
    );
    await docRef.update({ designStatus: 'print_file_error' });
    return null;
  }
}

/**
 * Refreshes the signed URL for an existing print file in Firebase Storage.
 * Returns the new signed URL.
 */
async function _refreshSignedUrl(
  docRef: FirebaseFirestore.DocumentReference,
  printFileStoragePath: string
): Promise<string> {
  const bucket = getStorage().bucket();
  const printFile = bucket.file(printFileStoragePath);
  const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
  const [signedUrl] = await printFile.getSignedUrl({
    action: 'read',
    expires: expiresAt,
  });
  // Note: Firestore update is skipped here for simplicity as we have two separate paths now.
  return signedUrl;
}
