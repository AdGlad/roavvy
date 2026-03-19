import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/onboarding/onboarding_flow.dart';
import 'features/shell/main_shell.dart';

class RoavvyApp extends ConsumerWidget {
  const RoavvyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    return MaterialApp(
      title: 'Roavvy',
      home: authState.when(
        data: (user) {
          if (user == null) return const SignInScreen();
          return _OnboardingGate(key: ValueKey(user.uid));
        },
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (_, __) => const SignInScreen(),
      ),
    );
  }
}

/// Watches [onboardingCompleteProvider] and routes to [OnboardingFlow] or
/// [MainShell]. Holds the initial tab index so "Scan my photos" can open
/// directly on the Scan tab (ADR-053).
class _OnboardingGate extends ConsumerStatefulWidget {
  const _OnboardingGate({super.key});

  @override
  ConsumerState<_OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends ConsumerState<_OnboardingGate> {
  int _initialTab = 0;

  Future<void> _completeOnboarding({bool goToScan = false}) async {
    if (mounted) setState(() => _initialTab = goToScan ? 3 : 0);
    ref.invalidate(onboardingCompleteProvider);
  }

  @override
  Widget build(BuildContext context) {
    final onboardingAsync = ref.watch(onboardingCompleteProvider);
    return onboardingAsync.when(
      data: (complete) => complete
          ? MainShell(initialTab: _initialTab)
          : OnboardingFlow(onComplete: _completeOnboarding),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const MainShell(),
    );
  }
}
