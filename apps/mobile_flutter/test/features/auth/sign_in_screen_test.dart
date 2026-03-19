import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:mobile_flutter/data/visit_repository.dart';
import 'package:mobile_flutter/features/auth/sign_in_screen.dart';

Widget _pumpSignInScreen() {
  final db = RoavvyDatabase(NativeDatabase.memory());
  return ProviderScope(
    overrides: [
      visitRepositoryProvider.overrideWithValue(VisitRepository(db)),
    ],
    child: const MaterialApp(home: SignInScreen()),
  );
}

void main() {
  testWidgets('shows Sign in with Apple button', (tester) async {
    await tester.pumpWidget(_pumpSignInScreen());

    expect(find.text('Sign in with Apple'), findsOneWidget);
  });

  testWidgets('shows Continue anonymously button', (tester) async {
    await tester.pumpWidget(_pumpSignInScreen());

    expect(find.text('Continue anonymously'), findsOneWidget);
  });

  testWidgets('shows email and password fields', (tester) async {
    await tester.pumpWidget(_pumpSignInScreen());

    expect(find.byType(TextField), findsNWidgets(2));
  });
}
