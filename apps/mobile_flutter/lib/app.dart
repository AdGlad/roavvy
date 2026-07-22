import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers.dart';
import 'core/theme/roavvy_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/legal/terms_screen.dart';
import 'features/onboarding/onboarding_flow.dart';
import 'features/shared/quokka/quokka_preview_screen.dart';
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
      if (kDebugMode) {
        // temp: skip auth gate for visual review
        if (state.uri.path == '/') return '/app';
        return null;
      }
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
      GoRoute(path: '/', builder: (context, state) => const LandingPage()),
      GoRoute(
        path: '/login',
        builder: (context, state) => const SignInScreen(),
      ),
      // DEV-ONLY: remove before shipping
      GoRoute(
        path: '/dev/quokka',
        builder: (context, state) => const QuokkaPreviewScreen(),
      ),
      GoRoute(
        path: '/app',
        builder:
            (context, state) =>
                kIsWeb ? const _WebAppShell() : const _OnboardingGate(),
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

class RoavvyApp extends ConsumerStatefulWidget {
  const RoavvyApp({super.key});

  @override
  ConsumerState<RoavvyApp> createState() => _RoavvyAppState();
}

class _RoavvyAppState extends ConsumerState<RoavvyApp> {
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    // Listen for incoming roavvy:// links — triggered when the user taps
    // "Return to shopping" in the Shopify in-app checkout browser, which
    // closes SFSafariViewController and opens the app via the custom scheme.
    _linkSub = AppLinks().uriLinkStream.listen((uri) {
      if (uri.scheme == 'roavvy' && mounted) {
        ref.read(_routerProvider).go('/app');
      }
    });
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(_routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Roavvy',
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      theme: roavvyLightTheme,
      darkTheme: roavvyDarkTheme,
      themeMode: themeMode,
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
              const Icon(
                Icons.check_circle_outline,
                color: Color(0xFF001F3F),
                size: 64,
              ),
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

  // T4 — show "Restoring your map…" only if startup takes > 2 s (ADR-160).
  bool _showRestoreIndicator = false;
  Timer? _restoreTimer;

  @override
  void initState() {
    super.initState();
    _restoreTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showRestoreIndicator = true);
    });
  }

  @override
  void dispose() {
    _restoreTimer?.cancel();
    super.dispose();
  }

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
    final startupAsync = ref.watch(startupCompleteProvider);
    final termsAsync = ref.watch(termsAcceptedProvider);
    final onboardingAsync = ref.watch(onboardingCompleteProvider);

    // Cancel the restore indicator timer once startup finishes.
    if (!startupAsync.isLoading) _restoreTimer?.cancel();

    // Show loading until startup and initial checks are resolved.
    if (startupAsync.isLoading || termsAsync.isLoading || onboardingAsync.isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              if (_showRestoreIndicator && startupAsync.isLoading) ...[
                const SizedBox(height: 16),
                Text(
                  'Restoring your map\u2026',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      );
    }

    final termsAccepted = termsAsync.valueOrNull ?? false;
    if (!termsAccepted) {
      // Auto-push terms screen on the next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => _pushTerms());
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return onboardingAsync.when(
      data:
          (complete) =>
              complete
                  ? MainShell(openScanOnLoad: _openScanOnLoad)
                  : OnboardingFlow(onComplete: _completeOnboarding),
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const MainShell(),
    );
  }
}
