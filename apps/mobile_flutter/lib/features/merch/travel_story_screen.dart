import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/providers.dart';
import 'local_mockup_preview_screen.dart';
import 'merch_preset.dart';
import 'travel_story_data.dart';
import 'travel_story_summary_card.dart';

String _achievementEmoji(Achievement a) {
  if (a.continentScope != null) return '🌍';
  if (a.regionScope != null) return '🗺️';
  return switch (a.category) {
    AchievementCategory.countries => '🏳️',
    AchievementCategory.continents => '🌏',
    AchievementCategory.trips => '✈️',
    AchievementCategory.thisYear => '📅',
    AchievementCategory.heritageSites => '🏛️',
  };
}

/// Full-screen Wrapped-style animated story experience (M146, ADR-178).
///
/// User-paced: advances on tap or swipe; never auto-advances.
/// Pushed modally (`fullscreenDialog: true`) from Year in Review and
/// Scan Summary entry points.
class TravelStoryScreen extends StatefulWidget {
  const TravelStoryScreen({super.key, required this.data});

  final TravelStoryData data;

  @override
  State<TravelStoryScreen> createState() => _TravelStoryScreenState();
}

class _TravelStoryScreenState extends State<TravelStoryScreen> {
  late final PageController _controller;
  late final List<Widget> _pages;

  final _summaryCardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _pages = _buildPages();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Widget> _buildPages() {
    final d = widget.data;
    final pages = <Widget>[
      // Page 1: Year banner
      _StoryPage(
        key: const ValueKey('year'),
        onTap: _next,
        child: _YearPage(year: d.year),
      ),
      // Page 2: Country count
      _StoryPage(
        key: const ValueKey('countries'),
        onTap: _next,
        child: _CountriesPage(data: d),
      ),
      // Page 3: Continents (skip if only 1)
      if (d.continentCount > 1)
        _StoryPage(
          key: const ValueKey('continents'),
          onTap: _next,
          child: _ContinentsPage(data: d),
        ),
      // Page 4: Achievement (skip if none)
      if (d.topAchievement != null)
        _StoryPage(
          key: const ValueKey('achievement'),
          onTap: _next,
          child: _AchievementPage(achievement: d.topAchievement!),
        ),
      // Page 5: Identity
      _StoryPage(
        key: const ValueKey('identity'),
        onTap: _next,
        child: _IdentityPage(data: d),
      ),
      // Page 6: CTA
      _StoryPage(
        key: const ValueKey('cta'),
        onTap: null,
        child: _CtaPage(
          data: d,
          summaryCardKey: _summaryCardKey,
          onDesign: _openPreview,
          onShare: _share,
          onDismiss: () => Navigator.of(context).pop(),
        ),
      ),
    ];
    return pages;
  }

  void _next() {
    final page = _controller.page?.round() ?? 0;
    if (page < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _openPreview() {
    final enabled =
        ProviderScope.containerOf(context).read(purchasingEnabledProvider);
    if (!enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The store is temporarily unavailable. Check back soon.',
          ),
        ),
      );
      return;
    }
    final d = widget.data;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LocalMockupPreviewScreen(
          selectedCodes: d.merchOption.codes,
          allCodes: d.countryCodes,
          trips: d.merchOption.trips,
          initialTemplate: d.merchOption.template,
          initialPreset: MerchPreset(
            id: 'travel_story',
            label: 'Travel Story',
            config: MerchPresetConfig(
              layout: d.merchOption.template,
              source: MerchCountrySource.allTime,
              jitter: 0.4,
              density: MerchDensity.balanced,
              stampMode: MerchStampMode.entryExit,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _share() async {
    final bytes = await TravelStorySummaryCard.capture(_summaryCardKey);
    if (bytes == null || !mounted) return;
    await TravelStorySummaryCard.shareBytes(
      context: context,
      pngBytes: bytes,
      year: widget.data.year,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Stack(
        children: [
          PageView(
            controller: _controller,
            children: _pages,
          ),
          // Page indicator dots at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: _DotIndicator(
              count: _pages.length,
              controller: _controller,
            ),
          ),
          // Close button top-right
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          // Off-screen summary card for share capture
          Positioned(
            left: -10000,
            top: -10000,
            width: 320,
            child: RepaintBoundary(
              key: _summaryCardKey,
              child: TravelStorySummaryCard(data: widget.data),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Page wrapper ──────────────────────────────────────────────────────────────

/// Wraps a story page content with a dark navy gradient background and
/// optional tap-anywhere-to-advance behaviour.
class _StoryPage extends StatefulWidget {
  const _StoryPage({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends State<_StoryPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1117), Color(0xFF060A0F)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Page 1: Year ──────────────────────────────────────────────────────────────

class _YearPage extends StatelessWidget {
  const _YearPage({required this.year});

  final int year;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Your',
            style: TextStyle(color: Colors.white54, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            '$year',
            style: const TextStyle(
              color: Color(0xFFD4A017),
              fontSize: 96,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'in travel',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 48),
          const Text(
            'Tap to continue',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Page 2: Countries ─────────────────────────────────────────────────────────

class _CountriesPage extends StatelessWidget {
  const _CountriesPage({required this.data});

  final TravelStoryData data;

  @override
  Widget build(BuildContext context) {
    final n = data.countryCodes.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _CountUpText(
            target: n,
            style: const TextStyle(
              color: Color(0xFFD4A017),
              fontSize: 96,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            n == 1 ? 'country visited' : 'countries visited',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 32),
          _FlagStrip(codes: data.countryCodes),
        ],
      ),
    );
  }
}

// ── Page 3: Continents ────────────────────────────────────────────────────────

class _ContinentsPage extends StatelessWidget {
  const _ContinentsPage({required this.data});

  final TravelStoryData data;

  @override
  Widget build(BuildContext context) {
    final n = data.continentCount;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _CountUpText(
            target: n,
            style: const TextStyle(
              color: Color(0xFFD4A017),
              fontSize: 96,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            n == 1 ? 'continent explored' : 'continents explored',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Page 4: Achievement ───────────────────────────────────────────────────────

class _AchievementPage extends StatelessWidget {
  const _AchievementPage({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _achievementEmoji(achievement),
              style: const TextStyle(fontSize: 72),
            ),
            const SizedBox(height: 20),
            Text(
              achievement.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFD4A017),
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              achievement.description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Page 5: Identity ──────────────────────────────────────────────────────────

class _IdentityPage extends StatelessWidget {
  const _IdentityPage({required this.data});

  final TravelStoryData data;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'You are a',
              style: TextStyle(color: Colors.white54, fontSize: 18),
            ),
            const SizedBox(height: 16),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Text(
                data.identity.emoji,
                style: const TextStyle(fontSize: 80),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              data.identity.displayName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFD4A017),
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              data.identity.tagline,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 15,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Page 6: CTA ───────────────────────────────────────────────────────────────

class _CtaPage extends StatelessWidget {
  const _CtaPage({
    required this.data,
    required this.summaryCardKey,
    required this.onDesign,
    required this.onShare,
    required this.onDismiss,
  });

  final TravelStoryData data;
  final GlobalKey summaryCardKey;
  final VoidCallback onDesign;
  final VoidCallback onShare;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Here is your ${data.year} shirt',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          // Merch preview card
          _StoryMerchPreview(data: data),
          const SizedBox(height: 32),
          // Design CTA
          FilledButton.icon(
            onPressed: onDesign,
            icon: const Icon(Icons.checkroom_outlined),
            label: const Text('Design this shirt'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
              minimumSize: const Size.fromHeight(48),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Share CTA
          OutlinedButton.icon(
            onPressed: onShare,
            icon: const Icon(Icons.share_outlined, size: 18),
            label: const Text('Share this story'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
              minimumSize: const Size.fromHeight(44),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onDismiss,
            child: const Text(
              'Maybe later',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact mockup preview on the CTA page.
class _StoryMerchPreview extends StatelessWidget {
  const _StoryMerchPreview({required this.data});

  final TravelStoryData data;

  @override
  Widget build(BuildContext context) {
    final n = data.countryCodes.length;
    return Container(
      height: 160,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2E4A), Color(0xFF0E1A2B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data.identity.emoji, style: const TextStyle(fontSize: 32)),
          const Spacer(),
          Text(
            data.merchOption.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$n ${n == 1 ? "country" : "countries"} · ${data.identity.displayName}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

/// Animated count-up number text.
class _CountUpText extends StatelessWidget {
  const _CountUpText({required this.target, required this.style});

  final int target;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: target),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOut,
      builder: (_, v, __) => Text('$v', style: style),
    );
  }
}

/// Horizontal scrollable strip of flag emojis.
class _FlagStrip extends StatelessWidget {
  const _FlagStrip({required this.codes});

  final List<String> codes;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: math.min(codes.length, 20),
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (_, i) => Text(
          _flagEmoji(codes[i]),
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }

  String _flagEmoji(String code) {
    if (code.length != 2) return '🏳️';
    final base = 0x1F1E6 - 0x41;
    return String.fromCharCode(base + code.codeUnitAt(0)) +
        String.fromCharCode(base + code.codeUnitAt(1));
  }
}

/// Animated dot page indicator.
class _DotIndicator extends StatefulWidget {
  const _DotIndicator({required this.count, required this.controller});

  final int count;
  final PageController controller;

  @override
  State<_DotIndicator> createState() => _DotIndicatorState();
}

class _DotIndicatorState extends State<_DotIndicator> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final page = widget.controller.hasClients
        ? (widget.controller.page ?? 0)
        : 0.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.count, (i) {
        final active = (page - i).abs() < 0.5;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 16 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? const Color(0xFFD4A017) : Colors.white24,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
