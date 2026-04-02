import 'package:shared_models/shared_models.dart';
import 'package:test/test.dart';

void main() {
  final confirmedAt = DateTime.utc(2026, 4, 1, 12, 0, 0);

  group('MockupApproval.toFirestore', () {
    test('produces correct field names with all optional fields', () {
      final approval = MockupApproval(
        mockupApprovalId: 'ma-001',
        userId: 'user-abc',
        artworkConfirmationId: 'ac-001',
        templateType: CardTemplateType.grid,
        variantId: 'gid://shopify/ProductVariant/12345',
        placementType: 'front',
        confirmedAt: confirmedAt,
      );
      final map = approval.toFirestore();

      expect(map['mockupApprovalId'], 'ma-001');
      expect(map['userId'], 'user-abc');
      expect(map['artworkConfirmationId'], 'ac-001');
      expect(map['templateType'], 'grid');
      expect(map['variantId'], 'gid://shopify/ProductVariant/12345');
      expect(map['placementType'], 'front');
      expect(map['confirmedAt'], '2026-04-01T12:00:00.000Z');
    });

    test('omits artworkConfirmationId key when null', () {
      final approval = MockupApproval(
        mockupApprovalId: 'ma-002',
        userId: 'user-abc',
        templateType: CardTemplateType.heart,
        variantId: 'gid://shopify/ProductVariant/99',
        confirmedAt: confirmedAt,
      );
      final map = approval.toFirestore();
      expect(map.containsKey('artworkConfirmationId'), isFalse);
    });

    test('omits placementType key when null', () {
      final approval = MockupApproval(
        mockupApprovalId: 'ma-003',
        userId: 'user-abc',
        templateType: CardTemplateType.passport,
        variantId: 'gid://shopify/ProductVariant/77',
        confirmedAt: confirmedAt,
      );
      final map = approval.toFirestore();
      expect(map.containsKey('placementType'), isFalse);
    });
  });

  group('MockupApproval.fromFirestore', () {
    test('round-trips all fields correctly', () {
      final original = MockupApproval(
        mockupApprovalId: 'ma-rt',
        userId: 'user-xyz',
        artworkConfirmationId: 'ac-rt',
        templateType: CardTemplateType.timeline,
        variantId: 'gid://shopify/ProductVariant/42',
        placementType: 'back',
        confirmedAt: confirmedAt,
      );
      final restored = MockupApproval.fromFirestore(original.toFirestore());

      expect(restored.mockupApprovalId, original.mockupApprovalId);
      expect(restored.userId, original.userId);
      expect(restored.artworkConfirmationId, original.artworkConfirmationId);
      expect(restored.templateType, original.templateType);
      expect(restored.variantId, original.variantId);
      expect(restored.placementType, original.placementType);
      expect(restored.confirmedAt.toUtc(), original.confirmedAt.toUtc());
    });

    test('round-trips with null optional fields', () {
      final original = MockupApproval(
        mockupApprovalId: 'ma-null',
        userId: 'user-xyz',
        templateType: CardTemplateType.grid,
        variantId: 'gid://shopify/ProductVariant/1',
        confirmedAt: confirmedAt,
      );
      final restored = MockupApproval.fromFirestore(original.toFirestore());

      expect(restored.artworkConfirmationId, isNull);
      expect(restored.placementType, isNull);
    });
  });
}
