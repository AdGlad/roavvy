import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/onboarding/onboarding_flow.dart';
import 'features/shell/main_shell.dart';
import 'features/web/landing_page.dart';

final _routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: _AuthRefreshNotifier(ref),
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const LandingPage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/app',
        builder: (context, state) => const _OnboardingGate(),
        redirect: (context, state) {
          final user = authState.value;
          if (user == null && !authState.isLoading) {
            return '/login';
          }
          return null;
        },
      ),
    ],
  );
});

class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    _subscription = ref.listen(authStateProvider, (_, __) {
      notifyListeners();
    });
  }

  late final ProviderSubscription _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}

class RoavvyApp extends ConsumerWidget {
  const RoavvyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(_routerProvider);
    return MaterialApp.router(
      title: 'Roavvy',
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF001F3F),
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
