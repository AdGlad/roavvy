import 'dart:typed_data';

import 'package:country_lookup/country_lookup.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'scan_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final data = await rootBundle.load('assets/geodata/ne_countries.bin');
  final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  initCountryLookup(bytes);
  runApp(RoavvySpike(geodataBytes: bytes));
}

class RoavvySpike extends StatelessWidget {
  const RoavvySpike({super.key, required this.geodataBytes});

  final Uint8List geodataBytes;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Roavvy Spike',
      home: ScanScreen(geodataBytes: geodataBytes),
    );
  }
}
