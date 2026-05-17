import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LandingPage extends ConsumerWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero Section
            _HeroSection(isMobile: isMobile),
            
            // Features
            _FeatureSection(
              title: 'Scan your travel history',
              description: 'Roavvy automatically detects the countries you\'ve visited by scanning your photo metadata on-device. No manual entry required.',
              icon: Icons.camera_enhance_outlined,
              isMobile: isMobile,
            ),
            _FeatureSection(
              title: 'See your world map',
              description: 'Watch your personal travel map grow. Your history is visualised on a beautiful interactive globe.',
              icon: Icons.public_outlined,
              isMobile: isMobile,
              reverse: !isMobile,
            ),
            _FeatureSection(
              title: 'Unlock achievements',
              description: 'Earn stamps and achievements as you explore new continents and reach travel milestones.',
              icon: Icons.emoji_events_outlined,
              isMobile: isMobile,
            ),
            _FeatureSection(
              title: 'Create personalised travel merchandise',
              description: 'Turn your travels into unique t-shirts and posters. Personalised designs based on your actual travel data.',
              icon: Icons.shopping_bag_outlined,
              isMobile: isMobile,
              reverse: !isMobile,
            ),

            // Privacy Message
            _PrivacySection(isMobile: isMobile),

            // Footer
            _FooterSection(),
          ],
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  final bool isMobile;

  const _HeroSection({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 64,
        vertical: isMobile ? 64 : 120,
      ),
      decoration: BoxDecoration(
        gradient: LinearRoute(
          colors: [Color(0xFF001F3F), Color(0xFF003366)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Text(
            'Roavvy',
            style: TextStyle(
              fontSize: isMobile ? 48 : 72,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -1.5,
            ),
          ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.2, end: 0),
          const SizedBox(height: 16),
          Text(
            'Your World Travel Map, Reimagined.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 20 : 32,
              color: Colors.white70,
              fontWeight: FontWeight.w300,
            ),
          ).animate().fadeIn(delay: 200.ms, duration: 800.ms),
          const SizedBox(height: 48),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () => context.go('/app'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                child: const Text('Open Roavvy'),
              ),
              const SizedBox(width: 16),
              OutlinedButton(
                onPressed: () => context.go('/login'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white, width: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                child: const Text('Sign In'),
              ),
            ],
          ).animate().fadeIn(delay: 400.ms, duration: 800.ms),
        ],
      ),
    );
  }
}

class _FeatureSection extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool isMobile;
  final bool reverse;

  const _FeatureSection({
    required this.title,
    required this.description,
    required this.icon,
    required this.isMobile,
    this.reverse = false,
  });

  @override
  Widget build(BuildContext context) {
    final children = [
      Expanded(
        flex: isMobile ? 0 : 1,
        child: Icon(
          icon,
          size: isMobile ? 80 : 160,
          color: Color(0xFF003366),
        ),
      ),
      if (!isMobile) const SizedBox(width: 64),
      Expanded(
        flex: isMobile ? 0 : 1,
        child: Column(
          crossAxisAlignment: isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF001F3F),
              ),
              textAlign: isMobile ? TextAlign.center : TextAlign.left,
            ),
            const SizedBox(height: 16),
            Text(
              description,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.black87,
                height: 1.6,
              ),
              textAlign: isMobile ? TextAlign.center : TextAlign.left,
            ),
          ],
        ),
      ),
    ];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 120,
        vertical: 80,
      ),
      color: reverse ? Colors.grey[50] : Colors.white,
      child: isMobile
          ? Column(children: children)
          : Row(children: reverse ? children.reversed.toList() : children),
    );
  }
}

class _PrivacySection extends StatelessWidget {
  final bool isMobile;

  const _PrivacySection({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 120,
        vertical: 100,
      ),
      color: Color(0xFFF8F9FA),
      child: Column(
        children: [
          const Icon(Icons.security, size: 64, color: Colors.green),
          const SizedBox(height: 24),
          const Text(
            'Privacy First',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Color(0xFF001F3F),
            ),
          ),
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: const Text(
              'Your photos are never uploaded. Roavvy only uses location metadata to detect places you have visited. All processing happens on your device to ensure your privacy is preserved.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                color: Colors.black54,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 64),
      color: Color(0xFF001F3F),
      child: Column(
        children: [
          const Text(
            'Roavvy',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            '© 2026 Roavvy. All rights reserved.',
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () {},
                child: const Text('Privacy Policy', style: TextStyle(color: Colors.white70)),
              ),
              const SizedBox(width: 24),
              TextButton(
                onPressed: () {},
                child: const Text('Terms of Service', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class LinearRoute extends LinearGradient {
  const LinearRoute({
    super.begin,
    super.end,
    required super.colors,
    super.stops,
    super.tileMode,
    super.transform,
  });
}
