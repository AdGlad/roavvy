import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_models/shared_models.dart';

/// Persists [MockupApproval] records to Firestore.
///
/// Path: `users/{uid}/mockup_approvals/{mockupApprovalId}` — covered by
/// the existing wildcard security rule `match /users/{userId}/{document=**}`
/// (ADR-029, ADR-105).
class MockupApprovalService {
  const MockupApprovalService(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String uid) =>
      _firestore
          .collection('users')
          .doc(uid)
          .collection('mockup_approvals');

  /// Writes [approval] to Firestore and returns the [mockupApprovalId].
  Future<String> create(MockupApproval approval) async {
    await _collection(approval.userId)
        .doc(approval.mockupApprovalId)
        .set(approval.toFirestore());
    return approval.mockupApprovalId;
  }
}
