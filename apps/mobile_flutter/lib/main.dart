import 'package:flutter/material.dart';
import 'scan_screen.dart';

void main() {
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
