import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_models/shared_models.dart';

/// Persists [TravelCard] records to Firestore.
///
/// Path: `users/{uid}/travel_cards/{cardId}` — covered by the existing
/// wildcard security rule (ADR-029, ADR-092).
///
/// Callers should invoke [create] fire-and-forget; the share flow must not
/// block on this write (ADR-092).
class TravelCardService {
  const TravelCardService(this._firestore);

  final FirebaseFirestore _firestore;

  /// Writes [card] to `users/{uid}/travel_cards/{cardId}`.
  Future<void> create(TravelCard card) => _firestore
      .collection('users')
      .doc(card.userId)
      .collection('travel_cards')
      .doc(card.cardId)
      .set(card.toFirestore());
}
