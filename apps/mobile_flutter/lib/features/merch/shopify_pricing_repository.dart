import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Prices returned by the `getMerchPrices` Firebase function.
class MerchPrices {
  const MerchPrices({
    required this.tshirtFromPrice,
    required this.posterFromPrice,
  });

  /// Formatted price string with currency symbol, e.g. "AU$59.99".
  final String tshirtFromPrice;
  final String posterFromPrice;

  // Placeholder shown only while the live Shopify price loads or on error. Uses
  // the default market (AU$) rather than a hardcoded £ so the purchase flow
  // never flashes the wrong currency; the live per-buyer price overrides it.
  static const _fallback = MerchPrices(
    tshirtFromPrice: 'AU\$59.99',
    posterFromPrice: 'AU\$49.99',
  );

  static MerchPrices? _fromJson(Map<String, dynamic> data) {
    try {
      final tshirt = data['tshirtPrice'] as Map<String, dynamic>;
      final poster = data['posterPrice'] as Map<String, dynamic>;
      return MerchPrices(
        tshirtFromPrice: _format(tshirt),
        posterFromPrice: _format(poster),
      );
    } catch (_) {
      return null;
    }
  }

  /// Formats a Shopify Money map (`{amount, currencyCode}`) into a display
  /// string like "AU$29.99". Returns null when the map is missing/malformed.
  static String? formatMoney(Object? money) {
    if (money is! Map) return null;
    final amount = double.tryParse(money['amount']?.toString() ?? '');
    if (amount == null) return null;
    final currency = money['currencyCode']?.toString() ?? 'GBP';
    return '${_symbol(currency)}${amount.toStringAsFixed(2)}';
  }

  static String _format(Map<String, dynamic> money) {
    final amount = double.tryParse(money['amount'] as String? ?? '') ?? 0.0;
    final currency = money['currencyCode'] as String? ?? 'GBP';
    // Use the currency code as prefix for non-GBP/EUR/USD currencies so the
    // user sees e.g. "AU$59.99" rather than just "$59.99".
    final symbol = _symbol(currency);
    return '$symbol${amount.toStringAsFixed(2)}';
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
    return MerchPrices._fromJson(result.data) ?? MerchPrices._fallback;
  } catch (_) {
    return MerchPrices._fallback;
  }
});
