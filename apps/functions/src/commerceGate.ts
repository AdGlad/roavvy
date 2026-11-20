import { defineBoolean } from 'firebase-functions/params';
import { HttpsError } from 'firebase-functions/v2/https';

/**
 * Server-side commerce kill switch (ADR-180, M187).
 *
 * Off unless the deployed project sets COMMERCE_ENABLED=true (see
 * `.env.<projectId>`). While off, the commerce callables refuse before any
 * Shopify, Printful or Firestore work, whatever build or request calls them.
 * Webhooks stay deployed: without orders they have nothing to do.
 */
export const commerceEnabled = defineBoolean('COMMERCE_ENABLED', {
  default: false,
  description: 'Allow merch pricing and cart creation (ADR-180).',
});

/** Throws `failed-precondition` unless commerce is enabled. */
export function assertCommerceEnabled(): void {
  if (!commerceEnabled.value()) {
    throw new HttpsError('failed-precondition', 'Purchasing is not available.');
  }
}
