import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_models/shared_models.dart';

/// Persists [ArtworkConfirmation] records to Firestore and manages their
/// lifecycle transitions.
///
/// Path: `users/{uid}/artwork_confirmations/{confirmationId}` — covered by
/// the existing wildcard security rule `match /users/{userId}/{document=**}`
/// (ADR-029, ADR-100).
class ArtworkConfirmationService {
  const ArtworkConfirmationService(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String uid) =>
      _firestore
          .collection('users')
          .doc(uid)
          .collection('artwork_confirmations');

  /// Writes [confirmation] to Firestore and returns the [confirmationId].
  ///
  /// The [confirmation] must have status [ArtworkConfirmationStatus.confirmed].
  Future<String> create(ArtworkConfirmation confirmation) async {
    await _collection(confirmation.userId)
        .doc(confirmation.confirmationId)
        .set(confirmation.toFirestore());
    return confirmation.confirmationId;
  }

  /// Updates the confirmation at [confirmationId] (owned by [uid]) to
  /// [ArtworkConfirmationStatus.purchaseLinked] and records the [orderId].
  Future<void> linkPurchase(String uid, String confirmationId, String orderId) =>
      _collection(uid).doc(confirmationId).update({
        'status': ArtworkConfirmationStatus.purchaseLinked.firestoreValue,
        'orderId': orderId,
      });

  /// Updates the confirmation at [confirmationId] (owned by [uid]) to
  /// [ArtworkConfirmationStatus.archived].
  Future<void> archive(String uid, String confirmationId) =>
      _collection(uid).doc(confirmationId).update({
        'status': ArtworkConfirmationStatus.archived.firestoreValue,
      });
}
