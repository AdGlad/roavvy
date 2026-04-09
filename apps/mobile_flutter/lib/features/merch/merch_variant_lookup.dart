// Shared product enum and variant GID lookup tables for the Roavvy merch
// commerce flow.
//
// Extracted from MerchVariantScreen / MerchProductBrowserScreen in M55
// (ADR-107) to allow LocalMockupPreviewScreen to use the same data without
// duplication. Source of truth: docs/engineering/commerce_api_contracts.md
//
// IMPORTANT: Keep in sync with Shopify product/variant data.

/// Products available in the Roavvy store.
///
/// Previously defined in [MerchProductBrowserScreen] (now deprecated). Moved
/// here in M55 so that LocalMockupPreviewScreen and ProductMockupSpecs can
/// reference it without depending on the deprecated screen (ADR-107).
enum MerchProduct {
  tshirt(
    name: 'Roavvy Test Tee',
    tagline: 'Wear your world',
    fromPrice: '£29.99',
    gid: 'gid://shopify/Product/8357194694843',
  ),
  poster(
    name: 'Roavvy Travel Poster',
    tagline: 'Frame the journey',
    fromPrice: '£24.99',
    gid: 'gid://shopify/Product/8357218353339',
  );

  const MerchProduct({
    required this.name,
    required this.tagline,
    required this.fromPrice,
    required this.gid,
  });

  final String name;
  final String tagline;
  final String fromPrice;
  final String gid;
}

const tshirtColors = ['Black', 'White', 'Blue', 'Grey', 'Red'];
const tshirtSizes = ['S', 'M', 'L', 'XL', '2XL'];
const posterPapers = ['Enhanced Matte', 'Luster', 'Fine Art'];
const posterSizes = ['12x18in', '18x24in', '24x36in', 'A3', 'A4'];

/// Maps (color, size) → Shopify ProductVariant GID for the T-shirt.
const Map<(String, String), String> tshirtGids = {
  ('Black', 'S'): 'gid://shopify/ProductVariant/47577103466683',
  ('Black', 'M'): 'gid://shopify/ProductVariant/47577103499451',
  ('Black', 'L'): 'gid://shopify/ProductVariant/47577103532219',
  ('Black', 'XL'): 'gid://shopify/ProductVariant/47577103564987',
  ('Black', '2XL'): 'gid://shopify/ProductVariant/47577103597755',
  ('White', 'S'): 'gid://shopify/ProductVariant/47577103630523',
  ('White', 'M'): 'gid://shopify/ProductVariant/47577103663291',
  ('White', 'L'): 'gid://shopify/ProductVariant/47577103696059',
  ('White', 'XL'): 'gid://shopify/ProductVariant/47577103728827',
  ('White', '2XL'): 'gid://shopify/ProductVariant/47577103761595',
  ('Blue', 'S'): 'gid://shopify/ProductVariant/47577103794363',
  ('Blue', 'M'): 'gid://shopify/ProductVariant/47577103827131',
  ('Blue', 'L'): 'gid://shopify/ProductVariant/47577103859899',
  ('Blue', 'XL'): 'gid://shopify/ProductVariant/47577103892667',
  ('Blue', '2XL'): 'gid://shopify/ProductVariant/47577103925435',
  ('Grey', 'S'): 'gid://shopify/ProductVariant/47577103958203',
  ('Grey', 'M'): 'gid://shopify/ProductVariant/47577103990971',
  ('Grey', 'L'): 'gid://shopify/ProductVariant/47577104023739',
  ('Grey', 'XL'): 'gid://shopify/ProductVariant/47577104056507',
  ('Grey', '2XL'): 'gid://shopify/ProductVariant/47577104089275',
  ('Red', 'S'): 'gid://shopify/ProductVariant/47577104122043',
  ('Red', 'M'): 'gid://shopify/ProductVariant/47577104154811',
  ('Red', 'L'): 'gid://shopify/ProductVariant/47577104187579',
  ('Red', 'XL'): 'gid://shopify/ProductVariant/47577104220347',
  ('Red', '2XL'): 'gid://shopify/ProductVariant/47577104253115',
};

/// Maps (paper, size) → Shopify ProductVariant GID for the Poster.
const Map<(String, String), String> posterGids = {
  ('Enhanced Matte', '12x18in'): 'gid://shopify/ProductVariant/47577104318651',
  ('Enhanced Matte', '18x24in'): 'gid://shopify/ProductVariant/47577104351419',
  ('Enhanced Matte', '24x36in'): 'gid://shopify/ProductVariant/47577104384187',
  ('Enhanced Matte', 'A3'): 'gid://shopify/ProductVariant/47577104416955',
  ('Enhanced Matte', 'A4'): 'gid://shopify/ProductVariant/47577104449723',
  ('Luster', '12x18in'): 'gid://shopify/ProductVariant/47577104482491',
  ('Luster', '18x24in'): 'gid://shopify/ProductVariant/47577104515259',
  ('Luster', '24x36in'): 'gid://shopify/ProductVariant/47577104548027',
  ('Luster', 'A3'): 'gid://shopify/ProductVariant/47577104580795',
  ('Luster', 'A4'): 'gid://shopify/ProductVariant/47577104613563',
  ('Fine Art', '12x18in'): 'gid://shopify/ProductVariant/47577104646331',
  ('Fine Art', '18x24in'): 'gid://shopify/ProductVariant/47577104679099',
  ('Fine Art', '24x36in'): 'gid://shopify/ProductVariant/47577104711867',
  ('Fine Art', 'A3'): 'gid://shopify/ProductVariant/47577104744635',
  ('Fine Art', 'A4'): 'gid://shopify/ProductVariant/47577104777403',
};

/// Resolves the Shopify ProductVariant GID for the given product configuration.
///
/// Returns the first GID as a fallback if the combination is not found (should
/// not happen in production with the locked-down pickers).
String resolveVariantGid({
  required MerchProduct product,
  required String colour,
  required String size,
  String paper = 'Enhanced Matte',
}) {
  if (product == MerchProduct.tshirt) {
    return tshirtGids[(colour, size)] ?? tshirtGids.values.first;
  } else {
    return posterGids[(paper, size)] ?? posterGids.values.first;
  }
}
