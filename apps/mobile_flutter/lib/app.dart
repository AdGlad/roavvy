import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/legal/terms_screen.dart';
import 'features/onboarding/onboarding_flow.dart';
import 'features/shell/main_shell.dart';
import 'features/web/landing_page.dart';

// IMPORTANT: do NOT ref.watch(authStateProvider) here.
// Watching it at provider level rebuilds the entire GoRouter whenever auth
// changes, which resets initialLocation to '/' and snaps the user back to
// the landing page on every sign-in / sign-out event.
// Auth state is read lazily inside the redirect callback via _AuthNotifier.
final _routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthNotifier(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      if (notifier.isLoading) return null;
      final path = state.uri.path;

      if (notifier.isLoggedIn) {
        // After sign-in: move off the landing page and sign-in screen.
        if (path == '/' || path == '/login') return '/app';
      } else {
        // Not authenticated: gate the app route.
        if (path.startsWith('/app')) return '/login';
      }
      return null;
    },
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
        builder: (context, state) => kIsWeb
            ? const _WebAppShell()
            : const _OnboardingGate(),
      ),
    ],
  );
});

/// Holds current Firebase auth state and notifies GoRouter when it changes.
/// Using a ChangeNotifier (rather than watching the provider directly on
/// _routerProvider) prevents the GoRouter from being recreated on auth events.
class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(Ref ref) {
    final initial = ref.read(authStateProvider);
    _isLoggedIn = initial.value != null;
    _isLoading = initial.isLoading;
    _subscription = ref.listen(authStateProvider, (_, next) {
      _isLoggedIn = next.value != null;
      _isLoading = next.isLoading;
      notifyListeners();
    });
  }

  late final ProviderSubscription _subscription;
  bool _isLoggedIn = false;
  bool _isLoading = false;

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;

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

/// Web shell shown at /app — the full app requires native SQLite, so on web
/// we show a simple signed-in confirmation with a download prompt.
class _WebAppShell extends StatelessWidget {
  const _WebAppShell();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline,
                  color: Color(0xFF001F3F), size: 64),
              const SizedBox(height: 24),
              const Text(
                "You're signed in to Roavvy",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Download the iOS app to scan your photos and explore your travel map.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            ],
          ),
        ),
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
  bool _openScanOnLoad = false;
  bool _termsShowing = false;

  Future<void> _completeOnboarding({bool goToScan = false}) async {
    if (mounted) setState(() => _openScanOnLoad = goToScan);
    ref.invalidate(onboardingCompleteProvider);
  }

  Future<void> _pushTerms() async {
    if (_termsShowing) return;
    _termsShowing = true;
    final accepted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const TermsScreen(requireAccept: true),
      ),
    );
    _termsShowing = false;
    if (accepted == true && mounted) {
      ref.invalidate(termsAcceptedProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final termsAsync = ref.watch(termsAcceptedProvider);
    final onboardingAsync = ref.watch(onboardingCompleteProvider);

    // Show loading until both are resolved.
    if (termsAsync.isLoading || onboardingAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final termsAccepted = termsAsync.valueOrNull ?? false;
    if (!termsAccepted) {
      // Auto-push terms screen on the next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => _pushTerms());
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return onboardingAsync.when(
      data: (complete) => complete
          ? MainShell(openScanOnLoad: _openScanOnLoad)
          : OnboardingFlow(onComplete: _completeOnboarding),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const MainShell(),
    );
  }
}
