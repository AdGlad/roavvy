import 'dart:io';
import 'dart:typed_data';
import '../lib/country_lookup.dart';

void main() {
  final bytes = File('/Users/adglad/git/roavvy/apps/mobile_flutter/assets/geodata/ne_countries.bin')
      .readAsBytesSync();
  initCountryLookup(Uint8List.fromList(bytes));

  // Warm up
  for (var i = 0; i < 10; i++) resolveCountry(51.5, -0.12);

  final coords = [
    (51.5, -0.12),    // London UK
    (35.68, 139.69),  // Tokyo JP
    (40.71, -74.01),  // New York US
    (48.85, 2.35),    // Paris FR
    (-33.87, 151.2),  // Sydney AU
    (55.75, 37.62),   // Moscow RU
    (-23.55, -46.63), // Sao Paulo BR
    (28.61, 77.21),   // Delhi IN
    (39.93, 116.39),  // Beijing CN
    (19.43, -99.13),  // Mexico City MX
    (4.36, 18.56),    // CAR — sparse polygon, worst case
    (0.0, 0.0),       // Null island — ocean
  ];

  final sw = Stopwatch()..start();
  for (var i = 0; i < 500; i++) {
    final c = coords[i % coords.length];
    resolveCountry(c.$1, c.$2);
  }
  sw.stop();

  final avgUs = sw.elapsedMicroseconds / 500;
  final avgMs = avgUs / 1000;
  print('500 lookups in ${sw.elapsedMilliseconds}ms');
  print('Average: ${avgUs.toStringAsFixed(1)} µs (${avgMs.toStringAsFixed(3)} ms)');
  print(avgMs < 5.0 ? 'PASS (<5ms SLA)' : 'FAIL (>5ms SLA)');
}
