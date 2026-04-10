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
  /**
   * @deprecated Use backPrintFileStoragePath. Kept for backward compat with old documents.
   * Firebase Storage path for the full-resolution print PNG
   */
  printFileStoragePath?: string | null;
  /**
   * @deprecated Use backPrintFileSignedUrl. Kept for backward compat with old documents.
   * Signed URL (7-day expiry) for the print PNG — sent to Printful
   */
  printFileSignedUrl?: string | null;
  /**
   * @deprecated Use backPrintFileExpiresAt. Kept for backward compat with old documents.
   * When the signed URL expires
   */
  printFileExpiresAt?: Timestamp | null;
  /** Printful order ID set after shopifyOrderCreated successfully creates the order */
  printfulOrderId: string | null;
  /**
   * @deprecated Use backMockupUrl. Kept for backward compat with old documents.
   * Photorealistic t-shirt mockup URL returned by Printful Mockup API (ADR-089).
   */
  mockupUrl?: string | null;
  /**
   * ID of the TravelCard that originated this order (M38: print from card, ADR-093).
   * Null when the order was created from the country selection flow.
   */
  cardId: string | null;
  /**
   * @deprecated Placement is now always both front and back for t-shirts (M63).
   * Kept for backward compat with old documents.
   */
  placement?: 'front' | 'back';

  // ── M63: dual-placement print files ────────────────────────────────────────

  /** Firebase Storage path for the front (left-chest ribbon) print PNG */
  frontPrintFileStoragePath: string | null;
  /** Signed URL (7-day expiry) for the front print PNG */
  frontPrintFileSignedUrl: string | null;
  /** When the front signed URL expires */
  frontPrintFileExpiresAt: Timestamp | null;
  /** Firebase Storage path for the back (full card artwork) print PNG */
  backPrintFileStoragePath: string | null;
  /** Signed URL (7-day expiry) for the back print PNG */
  backPrintFileSignedUrl: string | null;
  /** When the back signed URL expires */
  backPrintFileExpiresAt: Timestamp | null;
  /** Photorealistic mockup URL for the front placement */
  frontMockupUrl: string | null;
  /** Photorealistic mockup URL for the back placement */
  backMockupUrl: string | null;
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
}

/** Request payload for createMerchCart onCall function */
export interface CreateMerchCartRequest {
  variantId: string;
  selectedCountryCodes: string[];
  quantity: number;
  /** Optional: links this cart to a TravelCard (ADR-093) */
  cardId?: string;
  /**
   * @deprecated Use backCardBase64. Legacy alias — treated as backCardBase64.
   * Base64-encoded PNG of the card rendered on the client.
   * Rejected if length exceeds 5,500,000 characters (~4 MB decoded).
   */
  clientCardBase64?: string;
  /**
   * Base64-encoded PNG of the back (card artwork) rendered on the client.
   * When present, used as the back print file and preview.
   * Rejected if length exceeds 5,500,000 characters (~4 MB decoded).
   */
  backCardBase64?: string;
  /**
   * Base64-encoded PNG of the front (left-chest ribbon) rendered on the client.
   * When present and product is a t-shirt, composited onto the front print canvas.
   * Rejected if length exceeds 5,500,000 characters (~4 MB decoded).
   */
  frontCardBase64?: string;
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
}

/** Response payload from createMerchCart */
export interface CreateMerchCartResponse {
  checkoutUrl: string;
  cartId: string;
  merchConfigId: string;
  /** Public URL of the generated preview image (Firebase Storage) */
  previewUrl: string;
  /**
   * @deprecated Use backMockupUrl.
   * Photorealistic t-shirt mockup URL from Printful Mockup API (ADR-089).
   * Null for poster products or if mockup generation timed out / errored.
   */
  mockupUrl: string | null;
  /** Photorealistic mockup URL for the front placement. Null for poster products. */
  frontMockupUrl: string | null;
  /** Photorealistic mockup URL for the back placement. Null for poster products. */
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
