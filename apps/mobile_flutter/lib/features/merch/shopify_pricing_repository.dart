import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shown wherever a real Shopify price isn't available. We never invent or
/// default an amount that could disagree with the Shopify checkout — the exact
/// total is confirmed there.
const String kPriceConfirmedAtCheckout = 'Price confirmed at checkout';

/// Prices returned by the `getMerchPrices` Firebase function.
class MerchPrices {
  const MerchPrices({this.tshirtFromPrice, this.posterFromPrice});

  /// Live Shopify "from" price (buyer currency), e.g. "AU$29.99", or **null**
  /// when unknown — callers must show [kPriceConfirmedAtCheckout], never a
  /// hardcoded amount.
  final String? tshirtFromPrice;
  final String? posterFromPrice;

  /// Unknown prices — while loading or when the Shopify fetch fails. Deliberately
  /// carries no amount so nothing is ever guessed.
  static const unknown = MerchPrices();

  static MerchPrices _fromJson(Map<String, dynamic> data) => MerchPrices(
    tshirtFromPrice: formatMoney(data['tshirtPrice']),
    posterFromPrice: formatMoney(data['posterPrice']),
  );

  /// Formats a Shopify Money map (`{amount, currencyCode}`) into a display
  /// string like "AU$29.99". Returns null when the map is missing/malformed.
  static String? formatMoney(Object? money) {
    if (money is! Map) return null;
    final amount = double.tryParse(money['amount']?.toString() ?? '');
    if (amount == null) return null;
    final currency = money['currencyCode']?.toString() ?? 'GBP';
    return '${_symbol(currency)}${amount.toStringAsFixed(2)}';
  }

  static String _symbol(String currencyCode) {
    return switch (currencyCode) {
      'GBP' => '£',
      'EUR' => '€',
      'USD' => '\$',
      'CAD' => 'CA\$',
      'AUD' => 'AU\$',
      'NZD' => 'NZ\$',
      'SGD' => 'SG\$',
      'HKD' => 'HK\$',
      _ => '$currencyCode ',
    };
  }
}

/// The buyer's ISO 3166-1 alpha-2 country code from the device locale, used to
/// present prices and the Shopify checkout in the buyer's currency (M195).
/// e.g. "en_AU" → "AU", "en-US" → "US". Falls back to "AU" (the default
/// market) when the locale has no region; the backend applies the same default.
String buyerCountryCode() {
  final locale = Platform.localeName; // e.g. "en_AU" or "en-AU"
  final parts = locale.split(RegExp(r'[_\-]'));
  if (parts.length >= 2) {
    final code = parts.last.toUpperCase();
    if (RegExp(r'^[A-Z]{2}$').hasMatch(code)) return code;
  }
  return 'AU';
}

/// Fetches live product prices from Shopify via the `getMerchPrices` Cloud
/// Function. The buyer's country is inferred from the device locale so
/// prices are returned in the correct presentment currency (e.g. AUD for AU).
///
/// Cached for the lifetime of the provider — re-fetched on app restart.
final shopifyPricingProvider = FutureProvider<MerchPrices>((ref) async {
  try {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'getMerchPrices',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 10)),
    );
    final result = await callable.call<Map<String, dynamic>>({
      'countryCode': buyerCountryCode(),
    });
    return MerchPrices._fromJson(result.data);
  } catch (_) {
    return MerchPrices.unknown;
  }
});
