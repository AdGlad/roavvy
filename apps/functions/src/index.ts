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

// Printful v1 print area for Gildan 64000 DTG (product 12): 1800×2400 px = 12"×16" @ 150 DPI.
// position coords derived from print canvas (4500×5400): scale W×0.4, H×0.4444.
const MOCKUP_AREA_W = 1800;
const MOCKUP_AREA_H = 2400;

type MockupPosition = {
  area_width: number; area_height: number;
  width: number; height: number;
  top: number; left: number;
};

/** Fills the entire front print area (center placement). */
const FRONT_FULL_POSITION: MockupPosition = {
  area_width: MOCKUP_AREA_W, area_height: MOCKUP_AREA_H,
  width: MOCKUP_AREA_W, height: MOCKUP_AREA_H,
  top: 0, left: 0,
};

/**
 * Left chest (wearer's left = viewer's right) within the 1800×2400 front print area.
 * Scaled from print canvas coords: top=0.07H, left=0.58W, width=0.29W.
 * Scale factors: W×(1800/4500)=0.4, H×(2400/5400)=0.4444.
 */
const LEFT_CHEST_POSITION: MockupPosition = {
  area_width: MOCKUP_AREA_W, area_height: MOCKUP_AREA_H,
  width: 522, height: 522,
  top: 168, left: 1044,
};

/**
 * Generates photorealistic front and back t-shirt mockups using the Printful v1
 * Mockup Generator API. Uses the `position` field (OpenAPI spec: GenerationTaskFilePosition)
 * to place the design within the print area — supports full-front and chest placements.
 *
 * Returns separate frontMockupUrl and backMockupUrl (not a combined collage).
 */
async function generatePrintfulMockup(
  printfulVariantId: number,
  frontPrintFileUrl: string | null,
  backPrintFileUrl: string | null,
  frontPosition = 'center',
): Promise<{ frontMockupUrl: string | null; backMockupUrl: string | null }> {
  const t0 = Date.now();
  const elapsed = () => `+${Date.now() - t0}ms`;

  const apiKey = process.env['PRINTFUL_API_KEY'];
  if (!apiKey) {
    console.error('[mockup] PRINTFUL_API_KEY not set — skipping mockup');
    return { frontMockupUrl: null, backMockupUrl: null };
  }

  // Select front position based on placement. The v1 mockup generator only supports
  // 'front' as the placement name; position.{top,left,width,height} controls where
  // within the 1800×2400 print area the image is rendered (per OpenAPI spec).
  //
  // left_chest: small chest PNG + chest-area position (design placed via position field).
  // right_chest + center: full composited canvas + full-area position (design baked in).
  const frontFilePosition: MockupPosition =
    frontPosition === 'left_chest' ? LEFT_CHEST_POSITION : FRONT_FULL_POSITION;

  type V1File = { placement: string; image_url: string; position: MockupPosition };
  const files: V1File[] = [];

  if (frontPrintFileUrl) {
    files.push({ placement: 'front', image_url: frontPrintFileUrl, position: frontFilePosition });
  }
  if (backPrintFileUrl) {
    files.push({ placement: 'back', image_url: backPrintFileUrl, position: FRONT_FULL_POSITION });
  }

  if (files.length === 0) {
    console.log('[mockup] no files — skipping Printful request');
    return { frontMockupUrl: null, backMockupUrl: null };
  }

  console.log('[mockup] starting Printful v1 mockup generation', {
    frontPosition,
    placements: files.map((f) => f.placement),
    variantId: printfulVariantId,
  });

  // POST /mockup-generator/create-task/{product_id}
  // v1 API — supports explicit position params for design size/placement control.
  console.log(`[mockup] ${elapsed()} submitting v1 task`);
  const createRes = await fetch(
    'https://api.printful.com/mockup-generator/create-task/12',
    {
      method: 'POST',
      headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        variant_ids: [printfulVariantId],
        format: 'jpg',
        files,
      }),
    }
  );

  if (!createRes.ok) {
    const body = await createRes.text();
    console.error(`[mockup] ${elapsed()} v1 create-task failed ${createRes.status}: ${body}`);
    return { frontMockupUrl: null, backMockupUrl: null };
  }

  const createData = (await createRes.json()) as {
    code?: number;
    result?: { task_key?: string };
    error?: { message?: string };
  };
  const taskKey = createData.result?.task_key;
  if (!taskKey) {
    console.error(`[mockup] ${elapsed()} no task_key in v1 response`, JSON.stringify(createData));
    return { frontMockupUrl: null, backMockupUrl: null };
  }
  console.log(`[mockup] ${elapsed()} v1 task submitted — task_key=${taskKey}, polling...`);

  // Poll GET /mockup-generator/task?task_key={key}
  const maxAttempts = 25;
  const intervalMs = 3000;
  let frontMockupUrl: string | null = null;
  let backMockupUrl: string | null = null;

  for (let i = 0; i < maxAttempts; i++) {
    await new Promise((resolve) => setTimeout(resolve, intervalMs));

    const pollRes = await fetch(
      `https://api.printful.com/mockup-generator/task?task_key=${encodeURIComponent(taskKey)}`,
      { headers: { Authorization: `Bearer ${apiKey}` } }
    );

    if (!pollRes.ok) {
      console.error(`[mockup] ${elapsed()} poll[${i}] failed ${pollRes.status}`);
      return { frontMockupUrl: null, backMockupUrl: null };
    }

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const pollData = (await pollRes.json()) as { code?: number; result?: { status?: string; mockups?: Array<any> } };
    const status = pollData.result?.status;
    console.log(`[mockup] ${elapsed()} poll[${i}] status=${status ?? 'unknown'}`);

    if (status === 'completed') {
      const mockups: Array<any> = pollData.result?.mockups ?? [];
      for (const m of mockups) {
        const url: string | null = m?.mockup_url ?? null;
        const placement: string = m?.placement ?? '';
        if (!url) continue;
        if (placement === 'back') {
          backMockupUrl ??= url;
        } else {
          // front, left_chest, right_chest, etc.
          frontMockupUrl ??= url;
        }
      }
      console.log(`[mockup] ${elapsed()} completed — front=${frontMockupUrl ? '✓' : 'null'} back=${backMockupUrl ? '✓' : 'null'}`);
      return { frontMockupUrl, backMockupUrl };
    }

    if (status === 'failed') {
      console.error(`[mockup] ${elapsed()} v1 task failed: ${JSON.stringify(pollData)}`);
      return { frontMockupUrl: null, backMockupUrl: null };
    }
    // status pending — continue polling
  }

  console.error(`[mockup] ${elapsed()} timed out after ${maxAttempts} polls for task_key=${taskKey}`);
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
export const createMerchCart = onCall<
  CreateMerchCartRequest,
  Promise<CreateMerchCartResponse>
>(
  { timeoutSeconds: 300, memory: '2GiB' },
  async (request) => {
    const fnT0 = Date.now();
    const fnElapsed = () => `+${Date.now() - fnT0}ms`;

    // Auth check
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required.');
    }
    const uid = request.auth.uid;
    console.log(`[cart] ${fnElapsed()} auth ok uid=${uid}`);

    // Input validation
    const { variantId, selectedCountryCodes, quantity, cardId, clientCardBase64, frontImageBase64, backImageBase64, artworkConfirmationId, mockupApprovalId, frontPosition, backPosition } = request.data;
    // 'left_chest' | 'center' | 'right_chest' | 'none' — defaults to 'center'
    const effectiveFrontPosition: string = (typeof frontPosition === 'string' && frontPosition.length > 0) ? frontPosition : 'center';
    // 'center' | 'none' — defaults to 'center'
    const effectiveBackPosition: string = (typeof backPosition === 'string' && backPosition.length > 0) ? backPosition : 'center';
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

    console.log(`[cart] ${fnElapsed()} validation ok variantId=${variantId} front=${effectiveFrontPosition} back=${effectiveBackPosition} backBase64Len=${resolvedBackBase64?.length ?? 0} frontBase64Len=${frontImageBase64?.length ?? 0}`);

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
      // M76 field (ADR-128): front placement so shopifyOrderCreated can use the correct Printful placement
      frontPosition: effectiveFrontPosition,
    };
    await configRef.set(configData);
    console.log(`[cart] ${fnElapsed()} step1 done — configId=${configId}`);

    // ── Step 2 & 3: Generate preview + print PNGs ──────────────────────────
    const bucket = getStorage().bucket();
    const previewPath = `previews/${configId}.jpg`;
    const frontPrintPath = `front_print_files/${configId}.png`;
    const backPrintPath = `back_print_files/${configId}.png`;
    let previewUrl: string;
    let frontPrintFileSignedUrl: string | null = null;
    let backPrintFileSignedUrl: string | null = null;

    try {
      console.log(`[cart] ${fnElapsed()} step2 start — image processing`);
      const sharp = (await import('sharp')).default;
      const bgColour = printDims.backgroundColor === 'transparent'
        ? { r: 0, g: 0, b: 0, alpha: 0 }
        : { r: 255, g: 255, b: 255, alpha: 1 };

      // Process front and back images in parallel — they are independent.
      const [frontPrintBuf, backResult] = await Promise.all([
        // ── Front image ────────────────────────────────────────────────────
        (async (): Promise<Buffer | null> => {
          if (typeof frontImageBase64 !== 'string' || frontImageBase64.length === 0) return null;
          const clientBuf = Buffer.from(frontImageBase64, 'base64');
          const designBuf = await sharp(clientBuf)
            .resize(printDims.widthPx, printDims.heightPx, { fit: 'contain', background: bgColour })
            .toFormat('png')
            .toBuffer();

          if (effectiveFrontPosition === 'left_chest') {
            // M76 (ADR-128): named `left_chest` placement — send a small chest-area PNG.
            // Printful positions the file within the chest area automatically when given
            // placement: 'left_chest'. Sending the full composited canvas would compress
            // the entire 4500×5400px canvas into the chest area, making the design wrong.
            const canvasW = printDims.widthPx;
            const canvasH = printDims.heightPx;
            const maxW = Math.round(canvasW * 0.29);
            const maxH = Math.round(canvasH * 0.30);
            const chestBuf = await sharp(designBuf).resize(maxW, maxH, { fit: 'inside' }).png().toBuffer();
            const chestMeta = await sharp(chestBuf).metadata();
            console.log(`[print] left_chest small PNG ${chestMeta.width}×${chestMeta.height} (max ${maxW}×${maxH})`);
            return chestBuf;
          }
          if (effectiveFrontPosition === 'right_chest') {
            // right_chest: keep pre-composite onto full canvas — 'right_chest' is not a
            // confirmed DTG named placement for product 12 (ADR-128).
            const canvasW = printDims.widthPx;
            const canvasH = printDims.heightPx;
            const maxW = Math.round(canvasW * 0.29);
            const maxH = Math.round(canvasH * 0.30);
            const top = Math.round(canvasH * 0.07);
            const left = Math.round(canvasW * 0.13);
            const resized = await sharp(designBuf).resize(maxW, maxH, { fit: 'inside' }).toBuffer();
            const { width: rw = maxW } = await sharp(resized).metadata();
            const composited = await sharp({
              create: { width: canvasW, height: canvasH, channels: 4, background: { r: 0, g: 0, b: 0, alpha: 0 } },
            })
              .composite([{ input: resized, top, left: left + Math.round((maxW - rw) / 2) }])
              .png()
              .toBuffer();
            console.log(`[print] composited right_chest onto ${canvasW}×${canvasH} at top=${top} left=${left}`);
            return composited;
          }
          return designBuf;
        })(),

        // ── Back image (also generates preview JPEG) ───────────────────────
        (async (): Promise<{ backPrintBuf: Buffer; previewJpeg: Buffer } | null> => {
          if (typeof resolvedBackBase64 !== 'string' || resolvedBackBase64.length === 0) return null;
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

      let backPrintBuf: Buffer | null = backResult?.backPrintBuf ?? null;
      let previewJpeg: Buffer | null = backResult?.previewJpeg ?? null;
      console.log(`[cart] ${fnElapsed()} step2 done — image processing (front=${frontPrintBuf ? `${frontPrintBuf.length}B` : 'none'} back=${backPrintBuf ? `${backPrintBuf.length}B` : 'none'})`);

      // Fallback: server-side flag grid when no client images supplied.
      if (!frontPrintBuf && !backPrintBuf && effectiveBackPosition !== 'none') {
        const previewPng = await generateFlagGrid({
          templateId: 'flag_grid_v1',
          selectedCountryCodes,
          widthPx: 800,
          heightPx: 600,
          dpi: 96,
          backgroundColor: 'white',
        });
        previewJpeg = await sharp(previewPng).toFormat('jpeg', { quality: 80 }).toBuffer();
        backPrintBuf = await generateFlagGrid({
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
      const [uploadedPreviewUrl, resolvedFrontSignedUrl, resolvedBackSignedUrl] = await Promise.all([
        (async () => {
          const f = bucket.file(previewPath);
          await f.save(previewJpeg!, { metadata: { contentType: 'image/jpeg' }, public: true });
          return f.publicUrl();
        })(),
        frontPrintBuf
          ? (async () => {
              const f = bucket.file(frontPrintPath);
              await f.save(frontPrintBuf!, { metadata: { contentType: 'image/png' } });
              const [url] = await f.getSignedUrl({ action: 'read', expires: expiresAt });
              return url;
            })()
          : Promise.resolve(null as string | null),
        backPrintBuf
          ? (async () => {
              const f = bucket.file(backPrintPath);
              await f.save(backPrintBuf!, { metadata: { contentType: 'image/png' } });
              const [url] = await f.getSignedUrl({ action: 'read', expires: expiresAt });
              return url;
            })()
          : Promise.resolve(null as string | null),
      ]);

      previewUrl = uploadedPreviewUrl;
      frontPrintFileSignedUrl = resolvedFrontSignedUrl;
      backPrintFileSignedUrl = resolvedBackSignedUrl;
      console.log(`[cart] ${fnElapsed()} step3 done — uploads complete`);

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
    console.log(`[cart] ${fnElapsed()} step4 start — Shopify cart`);
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
    console.log(`[cart] ${fnElapsed()} step4 done — cart created cartId=${cart.id}`);

    // ── Step 5: Generate Printful mockup (background — does not block response) ─
    // The promise updates Firestore when complete; the client polls for the URL.
    // Skipped for poster variants (printfulVariantId === 0 = not configured).
    const printfulVariantId = PRINTFUL_VARIANT_IDS[variantId] ?? 0;
    if (printfulVariantId !== 0) {
      void generatePrintfulMockup(
        printfulVariantId,
        // The v1 API position field places the image at the correct area within the
        // print area — no compositing needed. frontPrintFileSignedUrl is the design
        // PNG (small chest image for left/right_chest, full canvas for center).
        frontPrintFileSignedUrl,
        backPrintFileSignedUrl,
        effectiveFrontPosition,
      )
        .then(({ frontMockupUrl, backMockupUrl }) => {
          if (frontMockupUrl || backMockupUrl) {
            void configRef.update({ frontMockupUrl, backMockupUrl });
          }
        })
        .catch((err: unknown) => {
          console.error(`[createMerchCart] Background mockup failed for ${configId}:`, err);
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
      // M76 (ADR-128): use named 'left_chest' placement for left-chest orders so the
      // production print matches the mockup. Pre-M76 configs have frontPosition=null,
      // which falls through to 'default' (center front) — safe backwards-compatible default.
      // NOTE: 'placement' field verified against Printful v2 Orders API 2026-04-23.
      if (config.frontPosition === 'left_chest') {
        files.push({ url: frontPrintFileSignedUrl, placement: 'left_chest' });
      } else {
        files.push({ url: frontPrintFileSignedUrl, type: 'default' }); // Printful 'default' = front
      }
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
