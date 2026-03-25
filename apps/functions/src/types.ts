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
  /** Firebase Storage path for the full-resolution print PNG */
  printFileStoragePath: string | null;
  /** Signed URL (7-day expiry) for the print PNG — sent to Printful */
  printFileSignedUrl: string | null;
  /** When the signed URL expires */
  printFileExpiresAt: Timestamp | null;
  /** Printful order ID set after shopifyOrderCreated successfully creates the order */
  printfulOrderId: string | null;
  /**
   * Photorealistic t-shirt mockup URL returned by Printful Mockup API (ADR-089).
   * Null for poster products (not configured) or if mockup generation timed out.
   * Set by createMerchCart after the Shopify cart is created.
   */
  mockupUrl: string | null;
  /**
   * ID of the TravelCard that originated this order (M38: print from card, ADR-093).
   * Null when the order was created from the country selection flow.
   */
  cardId: string | null;
}

/** Request payload for createMerchCart onCall function */
export interface CreateMerchCartRequest {
  variantId: string;
  selectedCountryCodes: string[];
  quantity: number;
  /** Optional: links this cart to a TravelCard (ADR-093) */
  cardId?: string;
}

/** Response payload from createMerchCart */
export interface CreateMerchCartResponse {
  checkoutUrl: string;
  cartId: string;
  merchConfigId: string;
  /** Public URL of the generated preview image (Firebase Storage) */
  previewUrl: string;
  /**
   * Photorealistic t-shirt mockup URL from Printful Mockup API (ADR-089).
   * Null for poster products or if mockup generation timed out / errored.
   */
  mockupUrl: string | null;
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
