# apps/web_nextjs — CLAUDE.md

## Purpose

The Next.js web app. Serves three primary use cases:
1. **Travel map viewer** — embeddable/shareable world map of visited countries.
2. **Sharing & social** — public travel card pages generated from a sharing token.
3. **Merchandise** — Shopify storefront integration for personalised travel products.

The web app does **not** scan photos. It consumes data synced from the mobile app via Firestore.

## Stack

- **Next.js 14+** (App Router, TypeScript)
- **Firebase Auth** — shared auth with mobile
- **Cloud Firestore** — read user travel data, write user preferences
- **Shopify Storefront API** — product listing, cart, checkout
- **`packages/shared_models`** — shared TypeScript types (consumed as a local package)

## Key Rules

1. **No photo handling of any kind.** This app never receives, displays, or stores photo data.
2. **Sharing token pages are public** but must not expose user identity — render only country list and stats.
3. **Shopify credentials stay server-side.** The Storefront API token must only be used in Server Components or Route Handlers, never in client bundles.
4. **Firebase is read-heavy.** Batch reads where possible; avoid listener proliferation.
5. **SSR for sharing pages** — travel card URLs must be crawlable and render correctly without JavaScript.

## Directory Conventions

```
app/
  (app)/             Authenticated app routes (map, achievements)
  share/[token]/     Public sharing page (SSR)
  shop/              Merchandise pages
  api/               Route Handlers (Shopify proxy, webhooks)
components/
  map/               World map components
  ui/                Generic design system components
lib/
  firebase/          Firestore client helpers
  shopify/           Storefront API client
  models/            Re-exports from shared_models
```

## Styling

Tailwind CSS. No CSS-in-JS. Component variants via `cva`.

## Testing

- Jest + React Testing Library for components.
- Playwright for E2E on critical paths (sharing page render, checkout flow).

## Related Docs

- [System Overview](../../docs/architecture/system_overview.md)
- [Data Model](../../docs/architecture/data_model.md)
- [Privacy Principles](../../docs/architecture/privacy_principles.md)
