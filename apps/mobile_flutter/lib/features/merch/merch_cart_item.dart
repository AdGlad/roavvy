import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of a client-side merch cart item (M120 / ADR-167).
///
/// Lifecycle:
///   [mockupGenerating] → createMerchCart called; waiting for Printful.
///   [mockupReady]      → checkoutUrl + mockup URLs available.
///   [checkoutStarted]  → user opened Shopify checkout.
///   [purchased]        → order webhook confirmed purchase.
///   [failed]           → createMerchCart or Printful failed after retries.
enum MerchCartItemStatus {
  mockupGenerating,
  mockupReady,
  checkoutStarted,
  purchased,
  failed;

  static MerchCartItemStatus fromString(String s) => switch (s) {
    'mockupGenerating' => mockupGenerating,
    'mockupReady' => mockupReady,
    'checkoutStarted' => checkoutStarted,
    'purchased' => purchased,
    _ => failed,
  };

  String get value => name;
}

/// Client-side record of a merch design saved at "Approve & Preview" time.
///
/// Stored at `users/{uid}/cartItems/{id}`.
/// Separate from `merch_configs` which is written server-side (ADR-167).
class MerchCartItem {
  const MerchCartItem({
    required this.id,
    required this.status,
    required this.productType,
    required this.variantId,
    required this.templateType,
    required this.colour,
    required this.size,
    required this.frontPosition,
    required this.backPosition,
    required this.selectedCountryCodes,
    required this.createdAt,
    required this.updatedAt,
    this.title,
    this.subtitle,
    this.cardId,
    this.artworkConfirmationId,
    this.frontMockupUrl,
    this.backMockupUrl,
    this.checkoutUrl,
    this.merchConfigId,
    this.failureReason,
  });

  final String id;
  final MerchCartItemStatus status;

  /// `'tshirt'` or `'poster'`.
  final String productType;

  /// Shopify variant GID string.
  final String variantId;

  /// Card template type name (e.g. `'grid'`, `'passport'`).
  final String templateType;

  final String colour;
  final String size;

  /// `'center'` | `'left_chest'` | `'right_chest'` | `'none'`
  final String frontPosition;

  /// `'center'` | `'none'`
  final String backPosition;

  final List<String> selectedCountryCodes;

  final DateTime createdAt;
  final DateTime updatedAt;

  final String? title;
  final String? subtitle;
  final String? cardId;
  final String? artworkConfirmationId;

  /// Printful photorealistic mockup URL (front view). Available after
  /// Printful finishes generating — may be null while [status] is
  /// [MerchCartItemStatus.mockupGenerating].
  final String? frontMockupUrl;

  /// Printful back mockup URL. Null when back print is disabled.
  final String? backMockupUrl;

  /// Shopify checkout URL returned by `createMerchCart`. Non-null once
  /// the Firebase Function has succeeded.
  final String? checkoutUrl;

  /// Firestore merch_config document ID. Set after `createMerchCart` returns.
  final String? merchConfigId;

  /// Human-readable failure reason stored for debugging.
  final String? failureReason;

  bool get isTshirt => productType == 'tshirt';

  factory MerchCartItem.fromDoc(String id, Map<String, dynamic> data) {
    List<String> parseCodes(dynamic v) {
      if (v is List) return v.cast<String>();
      return const [];
    }

    DateTime parseTs(dynamic v) {
      if (v is Timestamp) return v.toDate().toUtc();
      return DateTime.now().toUtc();
    }

    return MerchCartItem(
      id: id,
      status: MerchCartItemStatus.fromString(
        data['status'] as String? ?? 'failed',
      ),
      productType: data['productType'] as String? ?? 'tshirt',
      variantId: data['variantId'] as String? ?? '',
      templateType: data['templateType'] as String? ?? 'grid',
      colour: data['colour'] as String? ?? 'Black',
      size: data['size'] as String? ?? 'L',
      frontPosition: data['frontPosition'] as String? ?? 'center',
      backPosition: data['backPosition'] as String? ?? 'center',
      selectedCountryCodes: parseCodes(data['selectedCountryCodes']),
      createdAt: parseTs(data['createdAt']),
      updatedAt: parseTs(data['updatedAt']),
      title: data['title'] as String?,
      subtitle: data['subtitle'] as String?,
      cardId: data['cardId'] as String?,
      artworkConfirmationId: data['artworkConfirmationId'] as String?,
      frontMockupUrl: data['frontMockupUrl'] as String?,
      backMockupUrl: data['backMockupUrl'] as String?,
      checkoutUrl: data['checkoutUrl'] as String?,
      merchConfigId: data['merchConfigId'] as String?,
      failureReason: data['failureReason'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'status': status.value,
    'productType': productType,
    'variantId': variantId,
    'templateType': templateType,
    'colour': colour,
    'size': size,
    'frontPosition': frontPosition,
    'backPosition': backPosition,
    'selectedCountryCodes': selectedCountryCodes,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
    if (title != null) 'title': title,
    if (subtitle != null) 'subtitle': subtitle,
    if (cardId != null) 'cardId': cardId,
    if (artworkConfirmationId != null)
      'artworkConfirmationId': artworkConfirmationId,
    if (frontMockupUrl != null) 'frontMockupUrl': frontMockupUrl,
    if (backMockupUrl != null) 'backMockupUrl': backMockupUrl,
    if (checkoutUrl != null) 'checkoutUrl': checkoutUrl,
    if (merchConfigId != null) 'merchConfigId': merchConfigId,
    if (failureReason != null) 'failureReason': failureReason,
  };

  MerchCartItem copyWith({
    MerchCartItemStatus? status,
    String? frontMockupUrl,
    String? backMockupUrl,
    String? checkoutUrl,
    String? merchConfigId,
    String? failureReason,
    DateTime? updatedAt,
  }) {
    return MerchCartItem(
      id: id,
      status: status ?? this.status,
      productType: productType,
      variantId: variantId,
      templateType: templateType,
      colour: colour,
      size: size,
      frontPosition: frontPosition,
      backPosition: backPosition,
      selectedCountryCodes: selectedCountryCodes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
      title: title,
      subtitle: subtitle,
      cardId: cardId,
      artworkConfirmationId: artworkConfirmationId,
      frontMockupUrl: frontMockupUrl ?? this.frontMockupUrl,
      backMockupUrl: backMockupUrl ?? this.backMockupUrl,
      checkoutUrl: checkoutUrl ?? this.checkoutUrl,
      merchConfigId: merchConfigId ?? this.merchConfigId,
      failureReason: failureReason ?? this.failureReason,
    );
  }
}
