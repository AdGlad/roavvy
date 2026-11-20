"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.commerceEnabled = void 0;
exports.assertCommerceEnabled = assertCommerceEnabled;
const params_1 = require("firebase-functions/params");
const https_1 = require("firebase-functions/v2/https");
/**
 * Server-side commerce kill switch (ADR-180, M187).
 *
 * Off unless the deployed project sets COMMERCE_ENABLED=true (see
 * `.env.<projectId>`). While off, the commerce callables refuse before any
 * Shopify, Printful or Firestore work, whatever build or request calls them.
 * Webhooks stay deployed: without orders they have nothing to do.
 */
exports.commerceEnabled = (0, params_1.defineBoolean)('COMMERCE_ENABLED', {
    default: false,
    description: 'Allow merch pricing and cart creation (ADR-180).',
});
/** Throws `failed-precondition` unless commerce is enabled. */
function assertCommerceEnabled() {
    if (!exports.commerceEnabled.value()) {
        throw new https_1.HttpsError('failed-precondition', 'Purchasing is not available.');
    }
}
//# sourceMappingURL=commerceGate.js.map