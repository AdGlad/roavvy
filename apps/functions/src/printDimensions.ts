/**
 * Static lookup tables mapping Shopify ProductVariant GIDs to:
 *   - print canvas dimensions (pixels at the given DPI)
 *   - Printful numeric variant IDs
 *
 * Sources:
 *   - Shopify GIDs: docs/engineering/commerce_api_contracts.md §3
 *   - Print dimensions: ADR-065 static print dimension table
 *   - Printful variant IDs: MUST be verified in the Printful dashboard
 *     (Catalogue → your product → variant detail). Placeholders (0) must be
 *     replaced before Task 80 is accepted.
 *
 * T-shirt DTG print area uses 150 DPI (4500×5400 covers ~30×36 in at 150 DPI).
 * Poster print areas use 300 DPI.
 */

export interface PrintDimensions {
  widthPx: number;
  heightPx: number;
  dpi: number;
  backgroundColor: 'white' | 'transparent';
}

// ── Print dimensions keyed by Shopify variant GID ────────────────────────────

/** T-shirt GIDs — all share the same DTG front print area */
const _tshirtDimensions: PrintDimensions = {
  widthPx: 4500,
  heightPx: 5400,
  dpi: 150,
  backgroundColor: 'transparent',
};

/** Poster dimensions keyed by size label */
const _posterDimensionsBySize: Record<string, PrintDimensions> = {
  '12x18in': { widthPx: 3600, heightPx: 5400, dpi: 300, backgroundColor: 'white' },
  '18x24in': { widthPx: 5400, heightPx: 7200, dpi: 300, backgroundColor: 'white' },
  '24x36in': { widthPx: 7200, heightPx: 10800, dpi: 300, backgroundColor: 'white' },
  'A3': { widthPx: 3508, heightPx: 4961, dpi: 300, backgroundColor: 'white' },
  'A4': { widthPx: 2480, heightPx: 3508, dpi: 300, backgroundColor: 'white' },
};

export const PRINT_DIMENSIONS: Record<string, PrintDimensions> = {
  // ── T-Shirt: Roavvy Test Tee (all 25 colour × size variants) ──
  'gid://shopify/ProductVariant/47577103466683': _tshirtDimensions, // Black / S
  'gid://shopify/ProductVariant/47577103499451': _tshirtDimensions, // Black / M
  'gid://shopify/ProductVariant/47577103532219': _tshirtDimensions, // Black / L
  'gid://shopify/ProductVariant/47577103564987': _tshirtDimensions, // Black / XL
  'gid://shopify/ProductVariant/47577103597755': _tshirtDimensions, // Black / 2XL
  'gid://shopify/ProductVariant/47577103630523': _tshirtDimensions, // White / S
  'gid://shopify/ProductVariant/47577103663291': _tshirtDimensions, // White / M
  'gid://shopify/ProductVariant/47577103696059': _tshirtDimensions, // White / L
  'gid://shopify/ProductVariant/47577103728827': _tshirtDimensions, // White / XL
  'gid://shopify/ProductVariant/47577103761595': _tshirtDimensions, // White / 2XL
  'gid://shopify/ProductVariant/47577103794363': _tshirtDimensions, // Navy / S
  'gid://shopify/ProductVariant/47577103827131': _tshirtDimensions, // Navy / M
  'gid://shopify/ProductVariant/47577103859899': _tshirtDimensions, // Navy / L
  'gid://shopify/ProductVariant/47577103892667': _tshirtDimensions, // Navy / XL
  'gid://shopify/ProductVariant/47577103925435': _tshirtDimensions, // Navy / 2XL
  'gid://shopify/ProductVariant/47577103958203': _tshirtDimensions, // Heather Grey / S
  'gid://shopify/ProductVariant/47577103990971': _tshirtDimensions, // Heather Grey / M
  'gid://shopify/ProductVariant/47577104023739': _tshirtDimensions, // Heather Grey / L
  'gid://shopify/ProductVariant/47577104056507': _tshirtDimensions, // Heather Grey / XL
  'gid://shopify/ProductVariant/47577104089275': _tshirtDimensions, // Heather Grey / 2XL
  'gid://shopify/ProductVariant/47577104122043': _tshirtDimensions, // Red / S
  'gid://shopify/ProductVariant/47577104154811': _tshirtDimensions, // Red / M
  'gid://shopify/ProductVariant/47577104187579': _tshirtDimensions, // Red / L
  'gid://shopify/ProductVariant/47577104220347': _tshirtDimensions, // Red / XL
  'gid://shopify/ProductVariant/47577104253115': _tshirtDimensions, // Red / 2XL

  // ── Poster: Roavvy Travel Poster (15 paper × size variants) ──
  // Enhanced Matte
  'gid://shopify/ProductVariant/47577104318651': _posterDimensionsBySize['12x18in']!,
  'gid://shopify/ProductVariant/47577104351419': _posterDimensionsBySize['18x24in']!,
  'gid://shopify/ProductVariant/47577104384187': _posterDimensionsBySize['24x36in']!,
  'gid://shopify/ProductVariant/47577104416955': _posterDimensionsBySize['A3']!,
  'gid://shopify/ProductVariant/47577104449723': _posterDimensionsBySize['A4']!,
  // Luster
  'gid://shopify/ProductVariant/47577104482491': _posterDimensionsBySize['12x18in']!,
  'gid://shopify/ProductVariant/47577104515259': _posterDimensionsBySize['18x24in']!,
  'gid://shopify/ProductVariant/47577104548027': _posterDimensionsBySize['24x36in']!,
  'gid://shopify/ProductVariant/47577104580795': _posterDimensionsBySize['A3']!,
  'gid://shopify/ProductVariant/47577104613563': _posterDimensionsBySize['A4']!,
  // Fine Art
  'gid://shopify/ProductVariant/47577104646331': _posterDimensionsBySize['12x18in']!,
  'gid://shopify/ProductVariant/47577104679099': _posterDimensionsBySize['18x24in']!,
  'gid://shopify/ProductVariant/47577104711867': _posterDimensionsBySize['24x36in']!,
  'gid://shopify/ProductVariant/47577104744635': _posterDimensionsBySize['A3']!,
  'gid://shopify/ProductVariant/47577104777403': _posterDimensionsBySize['A4']!,
};

// ── Printful variant ID mapping keyed by Shopify variant GID ─────────────────
//
// Verified 2026-03-24 via GET /v2/sync-products/{id}/sync-variants.
// catalog_variant_id is the Printful numeric variant ID passed in order items.
//
// ⚠️  All poster variants: Printful returned catalog_variant_id=1 for 14 of 15
//     variants — poster sync variants are not configured. Poster orders will
//     fail until these are mapped in Printful. IDs set to 0 (safe failure).

export const PRINTFUL_VARIANT_IDS: Record<string, number> = {
  // ── T-Shirt: Roavvy Test Tee — verified 2026-03-24 ──
  'gid://shopify/ProductVariant/47577103466683': 474,  // Black / S
  'gid://shopify/ProductVariant/47577103499451': 505,  // Black / M
  'gid://shopify/ProductVariant/47577103532219': 536,  // Black / L
  'gid://shopify/ProductVariant/47577103564987': 567,  // Black / XL
  'gid://shopify/ProductVariant/47577103597755': 598,  // Black / 2XL
  'gid://shopify/ProductVariant/47577103630523': 473,  // White / S
  'gid://shopify/ProductVariant/47577103663291': 504,  // White / M
  'gid://shopify/ProductVariant/47577103696059': 535,  // White / L
  'gid://shopify/ProductVariant/47577103728827': 566,  // White / XL
  'gid://shopify/ProductVariant/47577103761595': 597,  // White / 2XL
  'gid://shopify/ProductVariant/47577103794363': 496,  // Navy / S
  'gid://shopify/ProductVariant/47577103827131': 527,  // Navy / M
  'gid://shopify/ProductVariant/47577103859899': 558,  // Navy / L
  'gid://shopify/ProductVariant/47577103892667': 589,  // Navy / XL
  'gid://shopify/ProductVariant/47577103925435': 620,  // Navy / 2XL
  'gid://shopify/ProductVariant/47577103958203': 22352, // Heather Grey / S
  'gid://shopify/ProductVariant/47577103990971': 22353, // Heather Grey / M
  'gid://shopify/ProductVariant/47577104023739': 22354, // Heather Grey / L
  'gid://shopify/ProductVariant/47577104056507': 22355, // Heather Grey / XL
  'gid://shopify/ProductVariant/47577104089275': 22356, // Heather Grey / 2XL
  'gid://shopify/ProductVariant/47577104122043': 499,  // Red / S
  'gid://shopify/ProductVariant/47577104154811': 530,  // Red / M
  'gid://shopify/ProductVariant/47577104187579': 561,  // Red / L
  'gid://shopify/ProductVariant/47577104220347': 592,  // Red / XL
  'gid://shopify/ProductVariant/47577104253115': 623,  // Red / 2XL
  // ── Poster: Roavvy Travel Poster — ⚠️ NOT configured in Printful (returns id=1)
  // Re-sync poster variants in Printful dashboard before enabling poster orders.
  'gid://shopify/ProductVariant/47577104318651': 0, // Enhanced Matte / 12x18in
  'gid://shopify/ProductVariant/47577104351419': 0, // Enhanced Matte / 18x24in
  'gid://shopify/ProductVariant/47577104384187': 0, // Enhanced Matte / 24x36in
  'gid://shopify/ProductVariant/47577104416955': 0, // Enhanced Matte / A3
  'gid://shopify/ProductVariant/47577104449723': 0, // Enhanced Matte / A4
  'gid://shopify/ProductVariant/47577104482491': 0, // Luster / 12x18in
  'gid://shopify/ProductVariant/47577104515259': 0, // Luster / 18x24in
  'gid://shopify/ProductVariant/47577104548027': 0, // Luster / 24x36in
  'gid://shopify/ProductVariant/47577104580795': 0, // Luster / A3
  'gid://shopify/ProductVariant/47577104613563': 0, // Luster / A4
  'gid://shopify/ProductVariant/47577104646331': 0, // Fine Art / 12x18in
  'gid://shopify/ProductVariant/47577104679099': 0, // Fine Art / 18x24in
  'gid://shopify/ProductVariant/47577104711867': 0, // Fine Art / 24x36in
  'gid://shopify/ProductVariant/47577104744635': 0, // Fine Art / A3
  'gid://shopify/ProductVariant/47577104777403': 0, // Fine Art / A4
};
