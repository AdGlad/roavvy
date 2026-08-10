import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/merch/design_engine/procedural_design_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('builds and prompts when no country is selected', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ProceduralDesignScreen(codes: [], allCodes: [], trips: []),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Auto designs'), findsOneWidget); // app bar title
    expect(find.text('Pick at least one country first.'), findsOneWidget);
  });
}
