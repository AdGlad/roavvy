import 'dart:io';
import 'dart:typed_data';
import '../lib/country_lookup.dart';

void main() {
  final bytes = File('/Users/adglad/git/roavvy/apps/mobile_flutter/assets/geodata/ne_countries.bin')
      .readAsBytesSync();
  initCountryLookup(Uint8List.fromList(bytes));

  final cases = [
    // Overseas territory overrides
    (4.0, -53.0, 'GF'),    // French Guiana
    (14.6, -61.0, 'MQ'),   // Martinique
    (16.2, -61.5, 'GP'),   // Guadeloupe
    (-12.8, 45.1, 'YT'),   // Mayotte
    (46.9, -56.2, 'PM'),   // Saint Pierre & Miquelon
    (12.2, -68.3, 'BQ'),   // Bonaire
    (17.489, -62.972, 'BQ'),  // Sint Eustatius (refined centroid)
    (78.22, 15.64, 'SJ'),     // Longyearbyen, Svalbard (refined)
    (-10.5, 105.66, 'CX'),    // Christmas Island (refined centroid)
    (-12.34, 96.84, 'CC'),    // Cocos (Keeling) Islands (Direction Island area)
    // Core countries
    (51.5, -0.12, 'GB'),   // London
    (35.68, 139.69, 'JP'), // Tokyo
    (48.85, 2.35, 'FR'),   // Paris (metropolitan)
  ];

  var pass = 0; var fail = 0;
  for (final (lat, lon, expected) in cases) {
    final got = resolveCountry(lat, lon);
    final ok = got == expected;
    if (ok) pass++; else fail++;
    print('${ok ? "PASS" : "FAIL"} ($lat,$lon) → $got (expected $expected)');
  }
  print('\n$pass/${pass+fail} passed');
  exit(fail > 0 ? 1 : 0);
}
