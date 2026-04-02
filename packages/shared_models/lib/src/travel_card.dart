/// Visual template types for travel card generation.
enum CardTemplateType {
  /// Flag emojis arranged in a flowing grid on a dark navy background.
  grid,

  /// Flag emojis on a warm amber gradient with a heart motif.
  heart,

  /// Country "passport stamps" arranged on a leather-brown background.
  passport,

  /// Dated travel log: trips listed chronologically with country names and
  /// date ranges on a parchment background (ADR-104 / M52).
  timeline,
}

/// A user-generated travel card capturing a snapshot of visited countries
/// with a chosen visual template.
///
/// Firestore path: `users/{uid}/travel_cards/{cardId}` (ADR-092).
///
/// Document shape:
/// ```json
/// {
///   "cardId": "card-1711234567890",
///   "userId": "abc123",
///   "templateType": "grid",
///   "countryCodes": ["FR", "DE", "JP"],
///   "countryCount": 3,
///   "createdAt": "2026-03-25T12:00:00.000Z"
/// }
/// ```
class TravelCard {
  const TravelCard({
    required this.cardId,
    required this.userId,
    required this.templateType,
    required this.countryCodes,
    required this.countryCount,
    required this.createdAt,
  });

  final String cardId;
  final String userId;
  final CardTemplateType templateType;
  final List<String> countryCodes;
  final int countryCount;
  final DateTime createdAt;

  Map<String, dynamic> toFirestore() => {
        'cardId': cardId,
        'userId': userId,
        'templateType': templateType.name,
        'countryCodes': List<String>.from(countryCodes),
        'countryCount': countryCount,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };
}
