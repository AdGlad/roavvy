import 'travel_card.dart';

/// Confirmation status lifecycle for an [ArtworkConfirmation].
///
/// `confirmed` → `purchase_linked` (after Shopify order created)
/// `confirmed` → `archived` (if user abandons or changes artwork)
enum ArtworkConfirmationStatus {
  confirmed,
  purchaseLinked,
  archived,
}

extension ArtworkConfirmationStatusX on ArtworkConfirmationStatus {
  String get firestoreValue {
    switch (this) {
      case ArtworkConfirmationStatus.confirmed:
        return 'confirmed';
      case ArtworkConfirmationStatus.purchaseLinked:
        return 'purchase_linked';
      case ArtworkConfirmationStatus.archived:
        return 'archived';
    }
  }

  static ArtworkConfirmationStatus fromString(String value) {
    switch (value) {
      case 'confirmed':
        return ArtworkConfirmationStatus.confirmed;
      case 'purchase_linked':
        return ArtworkConfirmationStatus.purchaseLinked;
      case 'archived':
        return ArtworkConfirmationStatus.archived;
      default:
        throw ArgumentError('Unknown ArtworkConfirmationStatus: $value');
    }
  }
}

/// Records that a user explicitly approved a specific rendered card image
/// before entering the product selection / purchase flow.
///
/// Firestore path: `users/{uid}/artwork_confirmations/{confirmationId}`.
///
/// The [imageHash] is a SHA-256 hex digest of the PNG bytes, tying this
/// record to the exact pixels the user saw (ADR-100).
///
/// Document shape:
/// ```json
/// {
///   "confirmationId": "ac-1711234567890",
///   "userId": "abc123",
///   "templateType": "passport",
///   "aspectRatio": 1.5,
///   "countryCodes": ["FR", "DE"],
///   "countryCount": 2,
///   "dateLabel": "2022–2024",
///   "dateRangeStart": "2022-01-01T00:00:00.000Z",
///   "dateRangeEnd": "2024-12-31T00:00:00.000Z",
///   "entryOnly": false,
///   "imageHash": "a3f1...",
///   "renderSchemaVersion": "v1",
///   "confirmedAt": "2026-03-31T12:00:00.000Z",
///   "status": "confirmed"
/// }
/// ```
class ArtworkConfirmation {
  const ArtworkConfirmation({
    required this.confirmationId,
    required this.userId,
    required this.templateType,
    required this.aspectRatio,
    required this.countryCodes,
    required this.countryCount,
    required this.dateLabel,
    this.dateRangeStart,
    this.dateRangeEnd,
    required this.entryOnly,
    required this.imageHash,
    required this.renderSchemaVersion,
    required this.confirmedAt,
    required this.status,
  });

  final String confirmationId;
  final String userId;
  final CardTemplateType templateType;

  /// Width-to-height ratio, e.g. 1.5 for landscape 3:2, 0.667 for portrait.
  final double aspectRatio;

  /// ISO 3166-1 alpha-2 country codes included in the rendered artwork.
  final List<String> countryCodes;
  final int countryCount;

  /// Human-readable date label shown on the card, e.g. "2022–2024" or "2024".
  /// Empty string when no date range is applied.
  final String dateLabel;

  /// Start of the date range filter applied when generating the card.
  /// Null when no filter was applied.
  final DateTime? dateRangeStart;

  /// End of the date range filter applied when generating the card.
  /// Null when no filter was applied.
  final DateTime? dateRangeEnd;

  /// Whether the passport template was rendered with entry stamps only.
  /// Always false for non-passport templates.
  final bool entryOnly;

  /// SHA-256 hex digest of the PNG bytes rendered at confirmation time.
  /// 64 lowercase hex characters (ADR-100).
  final String imageHash;

  /// Version of the rendering schema used to produce this image.
  /// Currently always `"v1"`.
  final String renderSchemaVersion;

  final DateTime confirmedAt;
  final ArtworkConfirmationStatus status;

  Map<String, dynamic> toFirestore() => {
        'confirmationId': confirmationId,
        'userId': userId,
        'templateType': templateType.name,
        'aspectRatio': aspectRatio,
        'countryCodes': List<String>.from(countryCodes),
        'countryCount': countryCount,
        'dateLabel': dateLabel,
        if (dateRangeStart != null)
          'dateRangeStart': dateRangeStart!.toUtc().toIso8601String(),
        if (dateRangeEnd != null)
          'dateRangeEnd': dateRangeEnd!.toUtc().toIso8601String(),
        'entryOnly': entryOnly,
        'imageHash': imageHash,
        'renderSchemaVersion': renderSchemaVersion,
        'confirmedAt': confirmedAt.toUtc().toIso8601String(),
        'status': status.firestoreValue,
      };

  factory ArtworkConfirmation.fromFirestore(Map<String, dynamic> data) {
    return ArtworkConfirmation(
      confirmationId: data['confirmationId'] as String,
      userId: data['userId'] as String,
      templateType: CardTemplateType.values.byName(data['templateType'] as String),
      aspectRatio: (data['aspectRatio'] as num).toDouble(),
      countryCodes: List<String>.from(data['countryCodes'] as List),
      countryCount: data['countryCount'] as int,
      dateLabel: data['dateLabel'] as String? ?? '',
      dateRangeStart: data['dateRangeStart'] != null
          ? DateTime.parse(data['dateRangeStart'] as String)
          : null,
      dateRangeEnd: data['dateRangeEnd'] != null
          ? DateTime.parse(data['dateRangeEnd'] as String)
          : null,
      entryOnly: data['entryOnly'] as bool? ?? false,
      imageHash: data['imageHash'] as String,
      renderSchemaVersion: data['renderSchemaVersion'] as String? ?? 'v1',
      confirmedAt: DateTime.parse(data['confirmedAt'] as String),
      status: ArtworkConfirmationStatusX.fromString(data['status'] as String),
    );
  }
}
