import 'travel_card.dart';

/// Records that a user explicitly approved the product mockup — confirming
/// their card design, colour choice, and placement — before checkout was
/// initiated (ADR-105 / M53).
///
/// Firestore path: `users/{uid}/mockup_approvals/{mockupApprovalId}`.
///
/// Document shape:
/// ```json
/// {
///   "mockupApprovalId": "ma-1711234567890",
///   "userId": "abc123",
///   "artworkConfirmationId": "ac-1711234567000",
///   "templateType": "grid",
///   "variantId": "gid://shopify/ProductVariant/12345",
///   "placementType": "front",
///   "confirmedAt": "2026-04-01T12:00:00.000Z"
/// }
/// ```
class MockupApproval {
  const MockupApproval({
    required this.mockupApprovalId,
    required this.userId,
    this.artworkConfirmationId,
    required this.templateType,
    required this.variantId,
    this.placementType,
    required this.confirmedAt,
  });

  final String mockupApprovalId;
  final String userId;

  /// Links to the [ArtworkConfirmation] that preceded this approval.
  /// Null when the user skipped artwork confirmation (legacy path).
  final String? artworkConfirmationId;

  final CardTemplateType templateType;

  /// Shopify variant GID string, e.g. `"gid://shopify/ProductVariant/12345"`.
  /// Stored as an opaque string — not parsed.
  final String variantId;

  /// `'front'` or `'back'` for t-shirts; null for posters.
  final String? placementType;

  final DateTime confirmedAt;

  Map<String, dynamic> toFirestore() => {
        'mockupApprovalId': mockupApprovalId,
        'userId': userId,
        if (artworkConfirmationId != null)
          'artworkConfirmationId': artworkConfirmationId,
        'templateType': templateType.name,
        'variantId': variantId,
        if (placementType != null) 'placementType': placementType,
        'confirmedAt': confirmedAt.toUtc().toIso8601String(),
      };

  factory MockupApproval.fromFirestore(Map<String, dynamic> data) {
    return MockupApproval(
      mockupApprovalId: data['mockupApprovalId'] as String,
      userId: data['userId'] as String,
      artworkConfirmationId: data['artworkConfirmationId'] as String?,
      templateType:
          CardTemplateType.values.byName(data['templateType'] as String),
      variantId: data['variantId'] as String,
      placementType: data['placementType'] as String?,
      confirmedAt: DateTime.parse(data['confirmedAt'] as String),
    );
  }
}
