import 'package:country_lookup/country_lookup.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'scan_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final data = await rootBundle.load('assets/geodata/ne_countries.bin');
  initCountryLookup(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  runApp(const RoavvySpike());
}

class RoavvySpike extends StatelessWidget {
  const RoavvySpike({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Roavvy Spike',
      home: ScanScreen(),
    );
  }
}
