import 'package:cloud_firestore/cloud_firestore.dart';

import 'merch_cart_item.dart';

/// Reads and writes [MerchCartItem] records in Firestore.
///
/// Collection path: `users/{uid}/cartItems`.
///
/// All writes use `updatedAt = now()`. Callers are responsible for supplying
/// the correct [uid]; this repository performs no auth checks.
class MerchCartRepository {
  MerchCartRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _firestore.collection('users').doc(uid).collection('cartItems');

  // ── Create ──────────────────────────────────────────────────────────────────

  /// Writes a new cart item and returns its Firestore document ID.
  Future<String> create(String uid, MerchCartItem item) async {
    final ref = _col(uid).doc(item.id);
    await ref.set(item.toMap());
    return item.id;
  }

  // ── Update ──────────────────────────────────────────────────────────────────

  /// Merges [fields] into an existing cart item.
  Future<void> update(
    String uid,
    String itemId,
    Map<String, dynamic> fields,
  ) async {
    await _col(uid).doc(itemId).update({
      ...fields,
      'updatedAt': Timestamp.fromDate(DateTime.now().toUtc()),
    });
  }

  /// Convenience: mark item as [MerchCartItemStatus.mockupReady].
  Future<void> markMockupReady(
    String uid,
    String itemId, {
    required String checkoutUrl,
    required String? frontMockupUrl,
    required String? backMockupUrl,
    required String? merchConfigId,
  }) => update(uid, itemId, {
    'status': MerchCartItemStatus.mockupReady.value,
    'checkoutUrl': checkoutUrl,
    if (frontMockupUrl != null) 'frontMockupUrl': frontMockupUrl,
    if (backMockupUrl != null) 'backMockupUrl': backMockupUrl,
    if (merchConfigId != null) 'merchConfigId': merchConfigId,
  });

  /// Convenience: update mockup URLs once Printful finishes asynchronously.
  Future<void> updateMockupUrls(
    String uid,
    String itemId, {
    required String? frontMockupUrl,
    required String? backMockupUrl,
  }) => update(uid, itemId, {
    if (frontMockupUrl != null) 'frontMockupUrl': frontMockupUrl,
    if (backMockupUrl != null) 'backMockupUrl': backMockupUrl,
  });

  /// Convenience: mark item as [MerchCartItemStatus.failed].
  Future<void> markFailed(String uid, String itemId, {String? reason}) =>
      update(uid, itemId, {
        'status': MerchCartItemStatus.failed.value,
        if (reason != null) 'failureReason': reason,
      });

  /// Convenience: mark item as [MerchCartItemStatus.checkoutStarted].
  Future<void> markCheckoutStarted(String uid, String itemId) => update(
    uid,
    itemId,
    {'status': MerchCartItemStatus.checkoutStarted.value},
  );

  // ── Read ────────────────────────────────────────────────────────────────────

  /// Returns all active cart items ordered newest-first.
  /// Fetches all cart items client-side and excludes purchased ones to avoid
  /// the composite index required by whereNotIn + orderBy (ADR-167).
  Future<List<MerchCartItem>> loadActive(String uid) async {
    final snap =
        await _col(uid).orderBy('updatedAt', descending: true).limit(50).get();
    return snap.docs
        .map((d) => MerchCartItem.fromDoc(d.id, d.data()))
        .where((item) => item.status != MerchCartItemStatus.purchased)
        .toList();
  }

  /// Real-time stream of active cart items ordered newest-first.
  /// Automatically excludes purchased items client-side.
  Stream<List<MerchCartItem>> watchActive(String uid) {
    return _col(uid)
        .orderBy('updatedAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((d) => MerchCartItem.fromDoc(d.id, d.data()))
                  .where((item) => item.status != MerchCartItemStatus.purchased)
                  .toList(),
        );
  }

  // ── Delete ──────────────────────────────────────────────────────────────────

  Future<void> delete(String uid, String itemId) async {
    await _col(uid).doc(itemId).delete();
  }
}
