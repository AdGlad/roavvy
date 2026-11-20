import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/legal/terms_screen.dart';

/// ADR-180 / M188: a build without commerce shows Terms with no purchase,
/// subscription or promo-code clauses.
void main() {
  Future<String> termsText(
    WidgetTester tester, {
    required bool commerce,
  }) async {
    await tester.pumpWidget(MaterialApp(home: TermsScreen(commerce: commerce)));
    return tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join('\n');
  }

  testWidgets('free Terms promise no purchase', (tester) async {
    final text = await termsText(tester, commerce: false);
    expect(text, contains('6. Free Service'));
    for (final banned in [
      'Merchandise',
      'merchandise',
      'Print-on-Demand',
      'Printful',
      'Shopify',
      'Subscription',
      'Promotional',
      'Social Features',
      'purchas', // purchase, purchasing (the free clause says "no purchases")
    ]) {
      final hits = RegExp(banned).allMatches(text).length;
      final allowed = banned == 'purchas' ? 1 : 0;
      expect(hits, allowed, reason: '"$banned" in the free Terms');
    }
    // Sections renumber with no gaps.
    expect(text, contains('12. Governing Law'));
  });

  testWidgets('commerce Terms keep the merchandise clauses', (tester) async {
    final text = await termsText(tester, commerce: true);
    expect(text, contains('6. Merchandise & Print-on-Demand'));
    expect(text, contains('8. Promotional Codes & Rewards'));
    expect(text, contains('15. Governing Law'));
    expect(text, isNot(contains('Free Service')));
  });
}
