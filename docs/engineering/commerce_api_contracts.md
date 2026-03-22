# Commerce API Contracts

_Last updated: 2026-03-21 (Task 69)_

This document is the authoritative reference for all commerce API contracts used in the M20 build. Firebase Functions are the only layer that calls these APIs. The mobile app and web app never call Shopify or Printful directly.

---

## 1. Shopify store

| Property | Value |
|---|---|
| Store domain | `roavvy.myshopify.com` |
| App name | Roavvy Firebase |
| Shopify API version | `2025-01` |
| Admin GraphQL endpoint | `https://roavvy.myshopify.com/admin/api/2025-01/graphql.json` |
| Storefront GraphQL endpoint | `https://roavvy.myshopify.com/api/2025-01/graphql.json` |

---

## 2. Authentication — client credentials grant

Firebase Functions obtain a 24-hour access token by exchanging client credentials. Tokens must be cached and refreshed before expiry.

**Endpoint**
```
POST https://roavvy.myshopify.com/admin/oauth/access_token
Content-Type: application/x-www-form-urlencoded
```

**Request body**
```
grant_type=client_credentials
client_id=<SHOPIFY_CLIENT_ID>
client_secret=<SHOPIFY_CLIENT_SECRET>
```

**Response**
```json
{
  "access_token": "shpat_...",
  "scope": "read_orders,write_orders,read_products,write_products,unauthenticated_write_checkouts,unauthenticated_read_checkouts,unauthenticated_read_product_listings",
  "expires_in": 86399
}
```

**Credentials storage**
- Local dev: `apps/functions/.env` (git-ignored)
- Deployed: Firebase Functions environment config
- Keys: `SHOPIFY_CLIENT_ID`, `SHOPIFY_CLIENT_SECRET`, `SHOPIFY_STORE_DOMAIN`

---

## 3. Product catalogue GIDs

### T-Shirt — Roavvy Test Tee

Product GID: `gid://shopify/Product/8357194694843`

| Variant | GID |
|---|---|
| Black / S | `gid://shopify/ProductVariant/47577103466683` |
| Black / M | `gid://shopify/ProductVariant/47577103499451` |
| Black / L | `gid://shopify/ProductVariant/47577103532219` |
| Black / XL | `gid://shopify/ProductVariant/47577103564987` |
| Black / 2XL | `gid://shopify/ProductVariant/47577103597755` |
| White / S | `gid://shopify/ProductVariant/47577103630523` |
| White / M | `gid://shopify/ProductVariant/47577103663291` |
| White / L | `gid://shopify/ProductVariant/47577103696059` |
| White / XL | `gid://shopify/ProductVariant/47577103728827` |
| White / 2XL | `gid://shopify/ProductVariant/47577103761595` |
| Navy / S | `gid://shopify/ProductVariant/47577103794363` |
| Navy / M | `gid://shopify/ProductVariant/47577103827131` |
| Navy / L | `gid://shopify/ProductVariant/47577103859899` |
| Navy / XL | `gid://shopify/ProductVariant/47577103892667` |
| Navy / 2XL | `gid://shopify/ProductVariant/47577103925435` |
| Heather Grey / S | `gid://shopify/ProductVariant/47577103958203` |
| Heather Grey / M | `gid://shopify/ProductVariant/47577103990971` |
| Heather Grey / L | `gid://shopify/ProductVariant/47577104023739` |
| Heather Grey / XL | `gid://shopify/ProductVariant/47577104056507` |
| Heather Grey / 2XL | `gid://shopify/ProductVariant/47577104089275` |
| Red / S | `gid://shopify/ProductVariant/47577104122043` |
| Red / M | `gid://shopify/ProductVariant/47577104154811` |
| Red / L | `gid://shopify/ProductVariant/47577104187579` |
| Red / XL | `gid://shopify/ProductVariant/47577104220347` |
| Red / 2XL | `gid://shopify/ProductVariant/47577104253115` |

### Poster — Roavvy Travel Poster

Product GID: `gid://shopify/Product/8357218353339`

| Variant | GID |
|---|---|
| Enhanced Matte / 12x18in | `gid://shopify/ProductVariant/47577104318651` |
| Enhanced Matte / 18x24in | `gid://shopify/ProductVariant/47577104351419` |
| Enhanced Matte / 24x36in | `gid://shopify/ProductVariant/47577104384187` |
| Enhanced Matte / A3 | `gid://shopify/ProductVariant/47577104416955` |
| Enhanced Matte / A4 | `gid://shopify/ProductVariant/47577104449723` |
| Luster / 12x18in | `gid://shopify/ProductVariant/47577104482491` |
| Luster / 18x24in | `gid://shopify/ProductVariant/47577104515259` |
| Luster / 24x36in | `gid://shopify/ProductVariant/47577104548027` |
| Luster / A3 | `gid://shopify/ProductVariant/47577104580795` |
| Luster / A4 | `gid://shopify/ProductVariant/47577104613563` |
| Fine Art / 12x18in | `gid://shopify/ProductVariant/47577104646331` |
| Fine Art / 18x24in | `gid://shopify/ProductVariant/47577104679099` |
| Fine Art / 24x36in | `gid://shopify/ProductVariant/47577104711867` |
| Fine Art / A3 | `gid://shopify/ProductVariant/47577104744635` |
| Fine Art / A4 | `gid://shopify/ProductVariant/47577104777403` |

---

## 4. Firebase Function — `POST /createMerchCart`

Creates a Shopify cart for a user's selected merchandise. Called by the mobile app when the user proceeds to checkout.

### Request (mobile → Firebase Function)

```json
{
  "userId": "firebase-uid",
  "merchConfigId": "firestore-doc-id",
  "lineItems": [
    {
      "variantId": "gid://shopify/ProductVariant/47577103466683",
      "quantity": 1
    }
  ]
}
```

- `merchConfigId` — Firestore document ID containing the user's selected countries and design configuration. Stored as a Shopify cart attribute (max 255 chars — only the ID, not the full config).
- `lineItems` — one or more variant GIDs from the catalogue above.

### Response (Firebase Function → mobile)

```json
{
  "checkoutUrl": "https://roavvy.myshopify.com/cart/c/...",
  "cartId": "gid://shopify/Cart/..."
}
```

The mobile app opens `checkoutUrl` in an in-app browser. No payment handling occurs in the app.

### Shopify Storefront API mutation used

```graphql
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
```

Variables:
```json
{
  "lines": [
    { "merchandiseId": "gid://shopify/ProductVariant/...", "quantity": 1 }
  ],
  "attributes": [
    { "key": "merchConfigId", "value": "<firestore-doc-id>" }
  ]
}
```

---

## 5. Shopify webhook — `orders/create`

Shopify calls this webhook when a customer completes checkout. Firebase Functions receive it and (post-PoC) submit the print file to Printful.

**Registration:** Configure in Shopify Admin or via Admin API.
**Endpoint:** `https://<region>-roavvy.cloudfunctions.net/shopifyOrderCreated`

### Webhook payload (key fields)

```json
{
  "id": 123456789,
  "order_number": 1001,
  "note_attributes": [
    { "name": "merchConfigId", "value": "firestore-doc-id" }
  ],
  "line_items": [
    {
      "variant_id": 47577103466683,
      "title": "Roavvy Test Tee",
      "variant_title": "Black / S",
      "quantity": 1,
      "price": "29.99"
    }
  ],
  "shipping_address": { ... },
  "financial_status": "paid"
}
```

### Webhook verification

All incoming webhook requests must be verified using the HMAC-SHA256 signature in the `X-Shopify-Hmac-Sha256` header.

```
HMAC = base64( HMAC-SHA256( SHOPIFY_CLIENT_SECRET, raw-request-body ) )
```

Reject requests where the computed HMAC does not match the header value.

---

## 6. Printful mockup API (post-PoC)

In the PoC, print files are attached manually per order in the Printful dashboard.

Post-PoC, Firebase Functions will call the Printful API on `orders/create` to submit the generated print file.

**Credentials:** `PRINTFUL_API_KEY` — stored in Firebase Functions environment config only.
**Base URL:** `https://api.printful.com`
**Docs:** https://developers.printful.com/docs/

Key endpoints:
- `POST /orders` — create a Printful order with the print file URL
- `GET /mockup-generator/create-task/{product_id}` — generate product mockup images

---

## 7. Credentials checklist

| Secret | Storage | Notes |
|---|---|---|
| `SHOPIFY_CLIENT_ID` | `apps/functions/.env` + Firebase config | Not secret but kept with credentials |
| `SHOPIFY_CLIENT_SECRET` | `apps/functions/.env` + Firebase config | Rotate immediately if exposed |
| `SHOPIFY_STORE_DOMAIN` | `apps/functions/.env` + Firebase config | `roavvy.myshopify.com` |
| `PRINTFUL_API_KEY` | Firebase config only | Obtain from Printful dashboard → API |

`apps/functions/.env` is git-ignored. Never commit secrets.

---

## 8. Firebase Blaze plan

Cloud Functions require the Firebase Blaze (pay-as-you-go) plan. Upgrade in the Firebase Console before deploying any functions. Free tier quotas apply within Blaze — costs only occur beyond those limits.
