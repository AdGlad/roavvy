import 'package:shared_models/shared_models.dart';
import 'package:test/test.dart';

void main() {
  final confirmedAt = DateTime.utc(2026, 3, 31, 12);
  final rangeStart = DateTime.utc(2022, 1, 1);
  final rangeEnd = DateTime.utc(2024, 12, 31);

  ArtworkConfirmation makeConfirmation({
    ArtworkConfirmationStatus status = ArtworkConfirmationStatus.confirmed,
    bool entryOnly = false,
    DateTime? dateRangeStart,
    DateTime? dateRangeEnd,
    String dateLabel = '2022–2024',
  }) =>
      ArtworkConfirmation(
        confirmationId: 'ac-001',
        userId: 'user-123',
        templateType: CardTemplateType.passport,
        aspectRatio: 1.5,
        countryCodes: const ['FR', 'DE', 'JP'],
        countryCount: 3,
        dateLabel: dateLabel,
        dateRangeStart: dateRangeStart,
        dateRangeEnd: dateRangeEnd,
        entryOnly: entryOnly,
        imageHash: 'a' * 64,
        renderSchemaVersion: 'v1',
        confirmedAt: confirmedAt,
        status: status,
      );

  group('ArtworkConfirmation — construction', () {
    test('all required fields are stored', () {
      final ac = makeConfirmation();
      expect(ac.confirmationId, 'ac-001');
      expect(ac.userId, 'user-123');
      expect(ac.templateType, CardTemplateType.passport);
      expect(ac.aspectRatio, 1.5);
      expect(ac.countryCodes, ['FR', 'DE', 'JP']);
      expect(ac.countryCount, 3);
      expect(ac.dateLabel, '2022–2024');
      expect(ac.entryOnly, isFalse);
      expect(ac.imageHash, 'a' * 64);
      expect(ac.renderSchemaVersion, 'v1');
      expect(ac.confirmedAt, confirmedAt);
      expect(ac.status, ArtworkConfirmationStatus.confirmed);
    });

    test('dateRangeStart and dateRangeEnd are nullable', () {
      final noRange = makeConfirmation();
      expect(noRange.dateRangeStart, isNull);
      expect(noRange.dateRangeEnd, isNull);

      final withRange = makeConfirmation(
        dateRangeStart: rangeStart,
        dateRangeEnd: rangeEnd,
      );
      expect(withRange.dateRangeStart, rangeStart);
      expect(withRange.dateRangeEnd, rangeEnd);
    });
  });

  group('ArtworkConfirmation — Firestore round-trip', () {
    test('toFirestore → fromFirestore is lossless (with date range)', () {
      final original = makeConfirmation(
        dateRangeStart: rangeStart,
        dateRangeEnd: rangeEnd,
      );
      final map = original.toFirestore();
      final restored = ArtworkConfirmation.fromFirestore(map);

      expect(restored.confirmationId, original.confirmationId);
      expect(restored.userId, original.userId);
      expect(restored.templateType, original.templateType);
      expect(restored.aspectRatio, original.aspectRatio);
      expect(restored.countryCodes, original.countryCodes);
      expect(restored.countryCount, original.countryCount);
      expect(restored.dateLabel, original.dateLabel);
      expect(restored.dateRangeStart, original.dateRangeStart);
      expect(restored.dateRangeEnd, original.dateRangeEnd);
      expect(restored.entryOnly, original.entryOnly);
      expect(restored.imageHash, original.imageHash);
      expect(restored.renderSchemaVersion, original.renderSchemaVersion);
      expect(restored.confirmedAt, original.confirmedAt);
      expect(restored.status, original.status);
    });

    test('toFirestore → fromFirestore is lossless (without date range)', () {
      final original = makeConfirmation(dateLabel: '');
      final map = original.toFirestore();
      expect(map.containsKey('dateRangeStart'), isFalse);
      expect(map.containsKey('dateRangeEnd'), isFalse);

      final restored = ArtworkConfirmation.fromFirestore(map);
      expect(restored.dateRangeStart, isNull);
      expect(restored.dateRangeEnd, isNull);
    });
  });

  group('ArtworkConfirmation — status values', () {
    test('all three status values serialise and deserialise correctly', () {
      for (final status in ArtworkConfirmationStatus.values) {
        final ac = makeConfirmation(status: status);
        final map = ac.toFirestore();
        final restored = ArtworkConfirmation.fromFirestore(map);
        expect(restored.status, status,
            reason: 'Status ${status.firestoreValue} did not round-trip');
      }
    });

    test('firestoreValue uses expected string literals', () {
      expect(ArtworkConfirmationStatus.confirmed.firestoreValue, 'confirmed');
      expect(ArtworkConfirmationStatus.purchaseLinked.firestoreValue,
          'purchase_linked');
      expect(ArtworkConfirmationStatus.archived.firestoreValue, 'archived');
    });

    test('fromString throws on unknown value', () {
      expect(
        () => ArtworkConfirmationStatusX.fromString('unknown_value'),
        throwsArgumentError,
      );
    });
  });

  group('ArtworkConfirmation — entryOnly field', () {
    test('entryOnly=true round-trips correctly', () {
      final ac = makeConfirmation(entryOnly: true);
      final restored = ArtworkConfirmation.fromFirestore(ac.toFirestore());
      expect(restored.entryOnly, isTrue);
    });
  });
}
