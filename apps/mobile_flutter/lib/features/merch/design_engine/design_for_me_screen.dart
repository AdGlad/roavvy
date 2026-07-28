import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';

import '../local_mockup_preview_screen.dart';
import '../merch_option_list_widgets.dart';
import '../merch_preset.dart';
import 'analytic_scorers.dart';
import 'candidate_generator.dart';
import 'card_render_thumbnailer.dart';
import 'genome_mutator.dart';
import 'optimization_loop.dart';
import 'pixel_scorers.dart';
import 'printability.dart';
import 'travel_profile_analyzer.dart';

/// "Design for me" — the AI design engine's user surface (M201). Runs the
/// on-device optimisation loop against the user's travel profile and presents
/// the best 3 printable designs, best-first, upgrading progressively. Picking
/// one hands off to the EXISTING [LocalMockupPreviewScreen]; the purchase flow
/// is untouched.
class DesignForMeScreen extends ConsumerStatefulWidget {
  const DesignForMeScreen({
    super.key,
    required this.codes,
    required this.allCodes,
    required this.trips,
  });

  /// The countries the user chose to design with.
  final List<String> codes;

  /// The user's full visited set (for the front ribbon).
  final List<String> allCodes;

  final List<TripRecord> trips;

  @override
  ConsumerState<DesignForMeScreen> createState() => _DesignForMeScreenState();
}

class _DesignForMeScreenState extends ConsumerState<DesignForMeScreen> {
  static const _budget = DesignEngineBudget(
    maxDuration: Duration(milliseconds: 4500), // under the 5 s product cap
    maxGenerations: 5,
    populationSize: 40,
    topK: 6,
  );

  List<DesignCandidate> _designs = const [];
  bool _running = true;
  CancellationToken? _cancel;
  int _seed = 7;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _cancel?.cancel();
    super.dispose();
  }

  List<String> get _selected =>
      widget.codes.map((c) => c.toUpperCase()).toList();

  List<TripRecord> get _scopedTrips {
    final set = _selected.toSet();
    final scoped =
        widget.trips.where((t) => set.contains(t.countryCode.toUpperCase()));
    return scoped.isEmpty ? widget.trips : scoped.toList();
  }

  Future<void> _run() async {
    _cancel?.cancel();
    final cancel = _cancel = CancellationToken();
    setState(() => _running = true);

    final profile = TravelProfileAnalyzer.analyze(_scopedTrips);
    if (profile.isEmpty || !mounted) {
      if (mounted) setState(() => _running = false);
      return;
    }

    final results = await OptimizationLoop().run(
      profile: profile,
      trips: _scopedTrips,
      generator: RankerSeededGenerator(rng: math.Random(_seed)),
      constraints: kDefaultPrintabilityConstraints,
      analyticScorers: const [...kDefaultAnalyticScorers, kDefaultProfileScorer],
      pixelScorers: kDefaultPixelScorers,
      renderer: CardRenderThumbnailer.forContext(context),
      mutator: const GenomeMutator(),
      budget: _budget,
      cancel: cancel,
      rng: math.Random(_seed),
      onProgress: (best) {
        if (mounted && !cancel.isCancelled) setState(() => _designs = best);
      },
    );

    if (!mounted || cancel.isCancelled) return;
    setState(() {
      _designs = results;
      _running = false;
    });
  }

  void _regenerate() {
    setState(() {
      _seed = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
      _designs = const [];
    });
    _run();
  }

  void _openDesign(DesignCandidate candidate) {
    final p = candidate.profileParams(widget.allCodes, _scopedTrips);
    if (kDebugMode) {
      // Telemetry seam (M202): the chosen genome, anonymised (no photos/PII).
      debugPrint('[design-engine] chosen ${candidate.params.contentHash}');
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LocalMockupPreviewScreen(
          selectedCodes: p.codes,
          allCodes: widget.allCodes,
          trips: p.trips,
          initialTemplate: candidate.params.template,
          initialPreset: MerchPreset(
            id: 'ai_${candidate.params.contentHash.hashCode}',
            label: 'For you',
            config: candidate.params.toPresetConfig(),
          ),
          confirmedAspectRatio: merchBackCardAspectRatio(candidate.params.template),
          transparentBackground: true,
          initialColour: candidate.params.shirtColour,
          gridLayoutMode: candidate.params.gridLayoutMode,
          clipShape: candidate.params.clipShape,
          clipCode: candidate.params.clipCode,
          flagRepeatCount: candidate.params.rowCount,
          rowCount: candidate.params.rowCount,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Designed for you'),
        actions: [
          if (!_running)
            IconButton(
              tooltip: 'Try again',
              icon: const Icon(Icons.auto_awesome_rounded),
              onPressed: _regenerate,
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _running && _designs.isEmpty
                    ? 'Crafting your designs…'
                    : 'Tap a design to customise & order',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildBody(theme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_designs.isEmpty) {
      return _running
          ? _buildSkeleton(theme)
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.brush_outlined, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    'Couldn’t craft a design from this selection.',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _regenerate,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            );
    }
    return ListView.separated(
      itemCount: _designs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _DesignCard(
        candidate: _designs[i],
        featured: i == 0,
        onTap: () => _openDesign(_designs[i]),
      ),
    );
  }

  Widget _buildSkeleton(ThemeData theme) {
    return ListView.separated(
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => Container(
        height: i == 0 ? 220 : 150,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

const Map<String, Color> _shirtSwatch = {
  'Black': Color(0xFF1A1A1A),
  'White': Color(0xFFF5F5F5),
  'Blue': Color(0xFF2B4C7E),
  'Grey': Color(0xFF9E9E9E),
  'Red': Color(0xFFB23A3A),
};

class _DesignCard extends StatelessWidget {
  const _DesignCard({
    required this.candidate,
    required this.featured,
    required this.onTap,
  });

  final DesignCandidate candidate;
  final bool featured;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = _shirtSwatch[candidate.params.shirtColour] ?? const Color(0xFF1A1A1A);
    final thumb = candidate.thumbnail;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      elevation: featured ? 3 : 1,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: featured ? 220 : 150,
          child: Center(
            child: thumb == null
                ? const CircularProgressIndicator()
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Image.memory(
                      thumb,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Maps a candidate's genome to the concrete codes/trips the preview needs.
extension _CandidateNav on DesignCandidate {
  ({List<String> codes, List<TripRecord> trips}) profileParams(
    List<String> allCodes,
    List<TripRecord> scopedTrips,
  ) {
    final codes = params.countryCodes;
    final set = codes.map((c) => c.toUpperCase()).toSet();
    final trips = scopedTrips
        .where((t) => set.contains(t.countryCode.toUpperCase()))
        .toList();
    return (codes: codes, trips: trips.isEmpty ? scopedTrips : trips);
  }
}
