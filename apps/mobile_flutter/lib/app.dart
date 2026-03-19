import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/shell/main_shell.dart';

class RoavvyApp extends ConsumerWidget {
  const RoavvyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    return MaterialApp(
      title: 'Roavvy',
      home: authState.when(
        data: (user) =>
            user != null ? const MainShell() : const SignInScreen(),
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (_, __) => const SignInScreen(),
      ),
    );
  }
}
