import { Timestamp } from 'firebase-admin/firestore';

/**
 * Firestore document stored at users/{uid}/merch_configs/{configId}.
 * Written by createMerchCart before the Shopify cart is created.
 *
 * M21 additions (ADR-065): templateId, designStatus, and image storage fields
 * support the two-stage flag image generation pipeline.
 */
export interface MerchConfig {
  /** Firestore document ID — stored as a field for collection group queries */
  configId: string;
  userId: string;
  /** Shopify ProductVariant GID e.g. "gid://shopify/ProductVariant/47577103466683" */
  variantId: string;
  /** ISO 3166-1 alpha-2 country codes selected by the user */
  selectedCountryCodes: string[];
  /** Always 1 for PoC */
  quantity: number;
  /** Populated by createMerchCart after cartCreate succeeds */
  shopifyCartId: string | null;
  /** Populated by shopifyOrderCreated webhook */
  shopifyOrderId: string | null;
  /** Order status: "pending" → "cart_created" → "ordered" */
  status: 'pending' | 'cart_created' | 'ordered';
  createdAt: Timestamp;

  // ── M21: flag image generation pipeline (ADR-065) ──────────────────────────

  /** Flag grid template used to generate the print file */
  templateId: 'flag_grid_v1';
  /**
   * Image generation lifecycle:
   * pending → files_ready (both PNGs generated and uploaded)
   *        → generation_error (generator threw; cart not returned to user)
   * files_ready → print_file_submitted (Printful order created)
   *            → print_file_error (Printful API error; logged, webhook returns 200)
   */
  designStatus:
    | 'pending'
    | 'files_ready'
    | 'generation_error'
    | 'print_file_submitted'
    | 'print_file_error';
  /** Firebase Storage path for the web-optimised preview JPEG */
  previewStoragePath: string | null;
  /** Firebase Storage path for the full-resolution front print PNG */
  frontPrintFileStoragePath: string | null;
  /** Signed URL (7-day expiry) for the front print PNG — sent to Printful */
  frontPrintFileSignedUrl: string | null;
  /** Firebase Storage path for the full-resolution back print PNG */
  backPrintFileStoragePath: string | null;
  /** Signed URL (7-day expiry) for the back print PNG — sent to Printful */
  backPrintFileSignedUrl: string | null;
  /** When the signed URL expires */
  printFileExpiresAt: Timestamp | null;
  /** Printful order ID set after shopifyOrderCreated successfully creates the order */
  printfulOrderId: string | null;
  /**
   * Photorealistic front t-shirt mockup URL returned by Printful Mockup API (ADR-120).
   * Null for poster products (not configured) or if mockup generation timed out.
   */
  frontMockupUrl: string | null;
  /**
   * Photorealistic back t-shirt mockup URL returned by Printful Mockup API (ADR-120).
   */
  backMockupUrl: string | null;
  /**
   * Lifecycle status of the Printful mockup generation background task.
   * null         = poster product or not yet started
   * 'generating' = task submitted to Printful, polling in progress
   * 'ready'      = mockup URLs written (may still be null if Printful returned nothing)
   * 'timeout'    = Printful polling exhausted without a result
   * 'failed'     = unrecoverable error during generation
   */
  mockupStatus: 'generating' | 'ready' | 'timeout' | 'failed' | null;
  /** Error message when mockupStatus === 'failed'. */
  mockupError: string | null;
  /**
   * ID of the TravelCard that originated this order (M38: print from card, ADR-093).
   * Null when the order was created from the country selection flow.
   */
  cardId: string | null;
  /**
   * ID of the ArtworkConfirmation the user approved before selecting this product
   * (M48: data foundation, ADR-100).
   * Null for orders placed before M48 or via the legacy country-selection flow.
   */
  artworkConfirmationId: string | null;
  /**
   * ID of the MockupApproval record the user confirmed before checkout was
   * initiated (M53, ADR-105).
   * Null for orders placed before M53.
   */
  mockupApprovalId: string | null;
  /**
   * Where the front design is placed on the shirt (M76, ADR-128).
   * 'left_chest' | 'center' | 'right_chest' | 'none'.
   * Null for orders placed before M76 — treated as 'center' by shopifyOrderCreated.
   */
  frontPosition: string | null;
  /**
   * Gift message subject line (M81). Forwarded to Printful `gift.subject`.
   * Null when not a gift order. Max 200 chars enforced by shopifyOrderCreated.
   */
  giftSubject: string | null;
  /**
   * Gift message body (M81). Forwarded to Printful `gift.message`.
   * Null when not a gift order. Max 200 chars enforced by shopifyOrderCreated.
   */
  giftMessage: string | null;
  /**
   * Printful v2 mockup task ID returned by POST /v2/mockup-tasks (M157).
   * Stored so printfulMockupWebhook can look up the config by task ID.
   * Null for poster products or pre-M157 configs.
   */
  printfulMockupTaskId: number | null;
}

/** Request payload for createMerchCart onCall function */
export interface CreateMerchCartRequest {
  variantId: string;
  selectedCountryCodes: string[];
  quantity: number;
  /**
   * Buyer's country as ISO 3166-1 alpha-2 (e.g. 'AU') (M195). Determines the
   * presentment currency of the Shopify checkout page via
   * `buyerIdentity.countryCode` / `@inContext`. Uppercased and validated
   * server-side; defaults to 'AU' when absent or invalid. NOT the design's
   * travel countries (`selectedCountryCodes`).
   */
  buyerCountry?: string;
  /** Optional: links this cart to a TravelCard (ADR-093) */
  cardId?: string;
  /**
   * Deprecated in M63: Base64-encoded PNG of the card rendered on the client.
   * Replaced by frontImageBase64 and backImageBase64.
   */
  clientCardBase64?: string;
  /**
   * Base64-encoded PNG of the front design rendered on the client (M63).
   * Rejected if length exceeds 5,500,000 characters (~4 MB decoded).
   */
  frontImageBase64?: string;
  /**
   * Base64-encoded PNG of the back design rendered on the client (M63).
   * Rejected if length exceeds 5,500,000 characters (~4 MB decoded).
   */
  backImageBase64?: string;
  /**
   * ID of the ArtworkConfirmation the user approved before product selection
   * (M48, ADR-100). Optional — omitting it is valid for legacy callers.
   */
  artworkConfirmationId?: string;
  /**
   * ID of the MockupApproval record capturing user consent before checkout
   * (M53, ADR-105). Optional — omitting it is valid for legacy callers.
   */
  mockupApprovalId?: string;
  /**
   * Where the front design is placed on the shirt.
   * 'left_chest' | 'center' | 'right_chest' | 'none'.
   * Defaults to 'center' when omitted. Ignored for non-t-shirt variants.
   */
  frontPosition?: string;
  /**
   * Whether the back of the shirt has a design.
   * 'center' | 'none'. Defaults to 'center' when omitted.
   */
  backPosition?: string;
  /**
   * Gift message subject (M81). Triggers `gift` field on the Printful order.
   * Max 200 chars. Omit or pass null/empty string for non-gift orders.
   */
  giftSubject?: string;
  /**
   * Gift message body (M81). Max 200 chars.
   */
  giftMessage?: string;
  /**
   * GCS storage path of the front print PNG uploaded directly by the phone (M157).
   * When present, createMerchCart skips Sharp processing and signs this path instead.
   */
  frontPrintStoragePath?: string;
  /**
   * GCS storage path of the back print PNG uploaded directly by the phone (M157).
   */
  backPrintStoragePath?: string;
  /**
   * GCS storage path of the mockup PNG uploaded by the phone for Printful v2 (M157).
   */
  mockupStoragePath?: string;
  /**
   * Client-generated config ID used as the Firestore doc ID (M157).
   * Allows the client to attach a Firestore listener before the function returns.
   */
  clientConfigId?: string;
}

/** Response payload from createMerchCart */
export interface CreateMerchCartResponse {
  checkoutUrl: string;
  cartId: string;
  merchConfigId: string;
  /**
   * Photorealistic front t-shirt mockup URL from Printful Mockup API (ADR-120).
   * Null for poster products or if mockup generation timed out / errored.
   */
  frontMockupUrl: string | null;
  /**
   * Photorealistic back t-shirt mockup URL from Printful Mockup API (ADR-120).
   */
  backMockupUrl: string | null;
}

/** Shopify Storefront cartCreate mutation response shape */
export interface ShopifyCartCreateResponse {
  data?: {
    cartCreate?: {
      cart?: {
        id: string;
        checkoutUrl: string;
      };
      userErrors: Array<{ field: string[]; message: string }>;
    };
  };
  errors?: Array<{ message: string }>;
}

// ── AI Design Critic — critiqueDesigns (M202) ─────────────────────────────────

/**
 * One design submitted to `critiqueDesigns`. Carries a low-res thumbnail plus
 * minimal genome metadata ONLY — never a user photo, GPS point, or any PII.
 * This is the enforced data policy for the AI art director (architecture §16.6:
 * "thumbnail images only; no photos ever leave the device").
 */
export interface DesignCritiqueInput {
  /** Stable `DesignParams.contentHash` — the per-design cache key. */
  paramsHash: string;
  /** Base64-encoded low-resolution PNG thumbnail of the rendered design. */
  thumbnailBase64: string;
  /** Template genome (e.g. 'grid', 'passport') — metadata for the prompt. */
  template: string;
  /** Number of countries in the design (a density hint for the critic). */
  countryCount: number;
  /** Shirt colour the design is composited on (e.g. 'Black'). */
  shirtColour: string;
}

/** Request payload for the `critiqueDesigns` onCall function (≤ 3 designs). */
export interface CritiqueDesignsRequest {
  designs: DesignCritiqueInput[];
}

/** The critic's verdict for a single design. */
export interface DesignCritiqueResult {
  /** Index into the request `designs` array. */
  index: number;
  /** Aesthetic score in [0, 1] (higher = better). 0.5 = neutral fallback. */
  aestheticScore: number;
  /** Optional short genome-level nudges (e.g. 'more whitespace'). */
  hints: string[];
}

/** Response payload from `critiqueDesigns`. */
export interface CritiqueDesignsResponse {
  results: DesignCritiqueResult[];
}
