import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

const _onboardingImages = [
  'assets/onboarding/paris.jpg',
  'assets/onboarding/london.jpg',
  'assets/onboarding/egypt.jpg',
  'assets/onboarding/tokyo.jpg',
  'assets/onboarding/sydney.jpg',
];

/// Three-screen onboarding flow shown to first-time users (ADR-053).
///
/// Screens: Welcome → Privacy → Ready to scan.
/// Calls [onComplete] with `goToScan = true` when the user taps
/// "Scan my photos" on the final screen, or `goToScan = false` for skip/
/// "Not now".
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({
    super.key,
    required this.onComplete,
  });

  /// Called after [RoavvyDatabase.markOnboardingComplete] completes.
  /// `goToScan` is true only when the user explicitly taps "Scan my photos".
  final Future<void> Function({bool goToScan}) onComplete;

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  final _controller = PageController();
  int _page = 0;
  bool _saving = false;
  late final List<String> _images;

  @override
  void initState() {
    super.initState();
    final shuffled = List<String>.from(_onboardingImages)..shuffle(Random());
    _images = shuffled.take(3).toList();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _advance() async {
    if (_page < 2) {
      final duration = MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 300);
      _controller.nextPage(duration: duration, curve: Curves.easeInOut);
    }
  }

  Future<void> _complete({bool goToScan = false}) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(roavvyDatabaseProvider).markOnboardingComplete();
      await widget.onComplete(goToScan: goToScan);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageView(
          controller: _controller,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (i) => setState(() => _page = i),
          children: [
            _OnboardingPage(
              pageIndex: 0,
              currentPage: _page,
              imagePath: _images[0],
              title: 'Your travels, discovered',
              body: 'Roavvy finds every country you\'ve visited — '
                  'automatically, using the photos already on your phone.',
              ctaLabel: 'Get started',
              onCta: _advance,
              skipLabel: 'Skip',
              onSkip: _saving ? null : () => _complete(),
            ),
            _OnboardingPage(
              pageIndex: 1,
              currentPage: _page,
              imagePath: _images[1],
              title: 'Your photos never leave your phone',
              body: 'Roavvy reads only location and date from your photos — '
                  'not the images themselves. Nothing is uploaded. '
                  'Your travel data stays on your device.',
              ctaLabel: 'Got it',
              onCta: _advance,
              skipLabel: 'Skip',
              onSkip: _saving ? null : () => _complete(),
            ),
            _OnboardingPage(
              pageIndex: 2,
              currentPage: _page,
              imagePath: _images[2],
              title: 'Ready to discover your travels?',
              body: 'Scanning usually takes a few minutes. '
                  'You can explore the app while it runs.',
              ctaLabel: 'Scan my photos',
              onCta: () => _complete(goToScan: true),
              skipLabel: 'Not now',
              onSkip: _saving ? null : () => _complete(),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.pageIndex,
    required this.currentPage,
    required this.imagePath,
    required this.title,
    required this.body,
    required this.ctaLabel,
    required this.onCta,
    required this.skipLabel,
    required this.onSkip,
  });

  final int pageIndex;
  final int currentPage;
  final String imagePath;
  final String title;
  final String body;
  final String ctaLabel;
  final VoidCallback? onCta;
  final String skipLabel;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          // Illustration (decorative — excluded from semantics)
          ExcludeSemantics(
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  imagePath,
                  width: 200,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Progress dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              final filled = i == pageIndex;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Semantics(
                  label: filled ? 'Step ${pageIndex + 1} of 3' : null,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 32),
          Text(
            title,
            style: theme.textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          FilledButton(
            onPressed: onCta,
            child: Text(ctaLabel),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onSkip,
            child: Text(skipLabel),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
