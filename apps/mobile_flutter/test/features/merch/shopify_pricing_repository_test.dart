import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/merch/shopify_pricing_repository.dart';

void main() {
  group('MerchPrices.formatMoney', () {
    test('formats a Shopify Money map with the currency symbol', () {
      expect(
        MerchPrices.formatMoney({'amount': '29.99', 'currencyCode': 'AUD'}),
        'AU\$29.99',
      );
      expect(
        MerchPrices.formatMoney({'amount': '29.9', 'currencyCode': 'USD'}),
        '\$29.90',
      );
      expect(
        MerchPrices.formatMoney({'amount': '30', 'currencyCode': 'GBP'}),
        '£30.00',
      );
    });

    test('unknown currency falls back to the code prefix', () {
      expect(
        MerchPrices.formatMoney({'amount': '10.00', 'currencyCode': 'JPY'}),
        'JPY 10.00',
      );
    });

    test('returns null for missing or malformed input', () {
      expect(MerchPrices.formatMoney(null), isNull);
      expect(MerchPrices.formatMoney('29.99'), isNull);
      expect(MerchPrices.formatMoney({'currencyCode': 'AUD'}), isNull);
      expect(
        MerchPrices.formatMoney({'amount': 'not-a-number'}),
        isNull,
      );
    });
  });
}
