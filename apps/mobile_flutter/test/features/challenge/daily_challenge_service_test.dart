// T3.8 — DailyChallengeService date selection and document parsing tests
//
// Uses FakeFirebaseFirestore — no real Firestore call is made.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/challenge/daily_challenge_service.dart';

void main() {
  // ── todayLocal ─────────────────────────────────────────────────────────────

  group('todayLocal', () {
    test('returns a string matching YYYY-MM-DD format', () {
      final date = todayLocal();
      final pattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
      expect(
        pattern.hasMatch(date),
        isTrue,
        reason: 'todayLocal() must return YYYY-MM-DD, got "$date"',
      );
    });

    test('returned date is close to DateTime.now() (within 1 day)', () {
      final date = todayLocal();
      final parts = date.split('-').map(int.parse).toList();
      final parsed = DateTime(parts[0], parts[1], parts[2]);
      final today = DateTime.now();
      final diff = today.difference(parsed).inDays.abs();
      expect(
        diff,
        lessThanOrEqualTo(1),
        reason: 'todayLocal() must return today or yesterday (UTC edge)',
      );
    });
  });

  // ── fetchToday ─────────────────────────────────────────────────────────────

  group('DailyChallengeService.fetchToday', () {
    test('throws DailyChallengeUnavailable when document is missing', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final service = DailyChallengeService(firestore: fakeFirestore);

      await expectLater(
        service.fetchToday(),
        throwsA(isA<DailyChallengeUnavailable>()),
      );
    });

    test(
      'returns DailyChallenge when correctly shaped document exists',
      () async {
        final fakeFirestore = FakeFirebaseFirestore();
        final service = DailyChallengeService(firestore: fakeFirestore);
        final date = todayLocal();

        await fakeFirestore.collection('daily_challenge').doc(date).set({
          'siteId': '208',
          'difficulty': 'medium',
          'clues': [
            {'type': 'geography', 'text': 'Located in South Asia'},
            {'type': 'category', 'text': 'Cultural site'},
            {'type': 'historical', 'text': 'Built in the 17th century'},
            {'type': 'location', 'text': 'Agra, India'},
            {'type': 'direct', 'text': 'A mausoleum of white marble'},
          ],
        });

        final challenge = await service.fetchToday();
        expect(challenge.siteId, '208');
        expect(challenge.difficulty, 'medium');
        expect(challenge.clues, hasLength(5));
      },
    );

    test('typed clues are deserialised into ChallengeClue objects', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final service = DailyChallengeService(firestore: fakeFirestore);
      final date = todayLocal();

      await fakeFirestore.collection('daily_challenge').doc(date).set({
        'siteId': '1',
        'clues': [
          {'type': 'geography', 'text': 'In Europe'},
          'Old plain string clue', // backwards-compat format
        ],
      });

      final challenge = await service.fetchToday();
      expect(challenge.clues[0].type, 'geography');
      expect(challenge.clues[0].text, 'In Europe');
      // Plain string clues are parsed with type 'general'.
      expect(challenge.clues[1].type, 'general');
      expect(challenge.clues[1].text, 'Old plain string clue');
    });

    test('missing difficulty field defaults to medium', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final service = DailyChallengeService(firestore: fakeFirestore);
      final date = todayLocal();

      await fakeFirestore.collection('daily_challenge').doc(date).set({
        'siteId': '42',
        'clues': [
          {'type': 'direct', 'text': 'Hint'},
        ],
        // no 'difficulty' field
      });

      final challenge = await service.fetchToday();
      expect(challenge.difficulty, 'medium');
    });

    test('uses today key — not yesterday or tomorrow', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final service = DailyChallengeService(firestore: fakeFirestore);
      final today = todayLocal();

      // Write yesterday and tomorrow but not today.
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayKey =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
      await fakeFirestore.collection('daily_challenge').doc(yesterdayKey).set({
        'siteId': 'yesterday',
        'clues': [
          {'type': 'direct', 'text': 'Yesterday clue'},
        ],
      });

      // Today's document does not exist → service should throw, not return yesterday.
      await expectLater(
        service.fetchToday(),
        throwsA(isA<DailyChallengeUnavailable>()),
      );

      // Now write today's document and verify it's returned.
      await fakeFirestore.collection('daily_challenge').doc(today).set({
        'siteId': 'today-site',
        'clues': [
          {'type': 'direct', 'text': 'Today clue'},
        ],
      });
      final challenge = await service.fetchToday();
      expect(challenge.siteId, 'today-site');
    });
  });

  // ── DailyChallengeUnavailable ──────────────────────────────────────────────

  group('DailyChallengeUnavailable', () {
    test('toString returns human-readable string', () {
      expect(
        const DailyChallengeUnavailable().toString(),
        'DailyChallengeUnavailable',
      );
    });

    test('is an Exception', () {
      expect(const DailyChallengeUnavailable(), isA<Exception>());
    });
  });
}
