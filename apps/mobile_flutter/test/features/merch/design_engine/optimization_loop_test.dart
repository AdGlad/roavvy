// M199 — AI design engine: candidate generator + evolutionary loop.
//
// The renderer and scorers are INJECTED (M198/M200 own the concrete ones), so
// these tests use fakes: a renderer that returns dummy bytes and deterministic
// rule-based scorers / constraints.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/flag_grid_layout_engine.dart';
import 'package:mobile_flutter/features/merch/design_engine/candidate_generator.dart';
import 'package:mobile_flutter/features/merch/design_engine/design_engine_contracts.dart';
import 'package:mobile_flutter/features/merch/design_engine/design_params.dart';
import 'package:mobile_flutter/features/merch/design_engine/genome_mutator.dart';
import 'package:mobile_flutter/features/merch/design_engine/optimization_loop.dart';
import 'package:mobile_flutter/features/merch/design_engine/travel_profile.dart';
import 'package:mobile_flutter/features/merch/merch_preset.dart';
import 'package:mobile_flutter/features/merch/merch_template_ranker.dart';
import 'package:shared_models/shared_models.dart';

// ── Test fixtures ────────────────────────────────────────────────────────────

TravelProfile _profile({
  TravelPersona persona = TravelPersona.continentHopper,
  List<CountrySetOption>? sets,
}) {
  final candidateSets = sets ??
      const [
        CountrySetOption(
          source: MerchCountrySource.allTime,
          label: 'All Countries',
          codes: ['FR', 'DE', 'IT', 'ES', 'JP'],
        ),
        CountrySetOption(
          source: MerchCountrySource.thisYear,
          label: 'This Year',
          codes: ['JP', 'ES'],
        ),
        CountrySetOption(
          source: MerchCountrySource.recentTrip,
          label: 'Recent Trip',
          codes: ['ES'],
        ),
        CountrySetOption(
          source: MerchCountrySource.singleCountry,
          label: 'Japan',
          codes: ['JP'],
        ),
      ];
  final allCodes = {for (final s in candidateSets) ...s.codes}.toList();
  return TravelProfile(
    allCodes: allCodes,
    density: MerchTemplateRanker.densityFor(allCodes.length),
    continents: const {'EU', 'AS'},
    dominantContinent: 'EU',
    candidateSets: candidateSets,
    earliest: DateTime(2018),
    latest: DateTime(2026),
    isRecencyHeavy: false,
    signatureCountries: const ['JP', 'ES'],
    persona: persona,
  );
}

TripRecord _trip(String code) => TripRecord(
      id: code,
      countryCode: code,
      startedOn: DateTime(2025),
      endedOn: DateTime(2025, 2),
      photoCount: 10,
      isManual: false,
    );

/// Renders dummy, non-empty bytes (never touches Flutter rasterisation).
class _FakeRenderer implements DesignRenderer {
  _FakeRenderer({this.delay = Duration.zero});
  final Duration delay;
  int calls = 0;

  @override
  Future<Uint8List> renderThumbnail(
    DesignParams params,
    List<TripRecord> trips,
  ) async {
    calls++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return Uint8List.fromList([1, 2, 3, params.template.index]);
  }
}

/// Deterministic analytic scorer: rewards grid + Black + dense so scores vary.
class _RuleScorer implements DesignScorer {
  const _RuleScorer();
  @override
  String get name => 'rule';
  @override
  double get weight => 1.0;
  @override
  double score(DesignParams params, TravelProfile profile, {Uint8List? thumbnail}) {
    var s = params.template == CardTemplateType.grid ? 0.4 : 0.2;
    s += params.shirtColour == 'Black' ? 0.3 : 0.1;
    s += params.density == MerchDensity.dense ? 0.2 : 0.1;
    return s.clamp(0.0, 1.0);
  }
}

/// Deterministic pixel scorer: rewards a present (rendered) thumbnail.
class _PixelScorer implements DesignScorer {
  const _PixelScorer();
  @override
  String get name => 'pixel';
  @override
  double get weight => 1.0;
  @override
  double score(DesignParams params, TravelProfile profile, {Uint8List? thumbnail}) {
    final base = params.template == CardTemplateType.grid ? 0.5 : 0.3;
    return (base + (thumbnail != null ? 0.4 : 0.0)).clamp(0.0, 1.0);
  }
}

/// Rejects everything (used to prove the loop drains to [] gracefully).
class _RejectAllConstraint implements PrintabilityConstraint {
  const _RejectAllConstraint();
  @override
  String get name => 'reject-all';
  @override
  String? violation(DesignParams params, TravelProfile profile) => 'nope';
}

/// A generator that only emits invalid (empty-set) genomes.
class _InvalidOnlyGenerator implements CandidateGenerator {
  const _InvalidOnlyGenerator();
  @override
  List<DesignParams> seed(TravelProfile profile, {int count = 60}) => List.generate(
        count,
        (i) => DesignParams(
          template: CardTemplateType.grid,
          source: MerchCountrySource.allTime,
          countryCodes: const [], // invalid → never printable
          seed: i,
        ),
      );
}

void main() {
  final trips = [_trip('FR'), _trip('DE'), _trip('IT'), _trip('ES'), _trip('JP')];

  Future<List<DesignCandidate>> runLoop({
    TravelProfile? profile,
    CandidateGenerator? generator,
    List<PrintabilityConstraint> constraints = const [],
    List<DesignScorer> analytic = const [_RuleScorer()],
    List<DesignScorer> pixel = const [_PixelScorer()],
    DesignRenderer? renderer,
    DesignEngineBudget budget = const DesignEngineBudget(),
    void Function(List<DesignCandidate>)? onProgress,
    int genSeed = 7,
    int loopSeed = 42,
    CancellationToken? cancel,
  }) {
    return const OptimizationLoop().run(
      profile: profile ?? _profile(),
      trips: trips,
      generator: generator ?? RankerSeededGenerator(rng: math.Random(genSeed)),
      constraints: constraints,
      analyticScorers: analytic,
      pixelScorers: pixel,
      renderer: renderer ?? _FakeRenderer(),
      mutator: const GenomeMutator(),
      budget: budget,
      onProgress: onProgress,
      rng: math.Random(loopSeed),
      cancel: cancel,
    );
  }

  group('RankerSeededGenerator', () {
    test('all seeds are normalized + valid, deduped', () {
      final gen = RankerSeededGenerator(rng: math.Random(1));
      final pop = gen.seed(_profile(), count: 60);
      expect(pop, isNotEmpty);
      expect(pop.every((p) => p.isValid), isTrue);
      expect(pop.every((p) => p.normalize() == p), isTrue);
      final hashes = pop.map((p) => p.contentHash).toSet();
      expect(hashes.length, pop.length); // no duplicates
    });

    test('guarantees a seed for every candidate set', () {
      final gen = RankerSeededGenerator(rng: math.Random(2));
      final profile = _profile();
      final pop = gen.seed(profile, count: 60);
      for (final set in profile.candidateSets) {
        expect(
          pop.any((p) => p.source == set.source),
          isTrue,
          reason: 'no seed for ${set.source}',
        );
      }
    });

    test('soloDeepDive biases a single-country outline clip', () {
      final gen = RankerSeededGenerator(rng: math.Random(3));
      final profile = _profile(
        persona: TravelPersona.soloDeepDive,
        sets: const [
          CountrySetOption(
            source: MerchCountrySource.singleCountry,
            label: 'Japan',
            codes: ['JP'],
          ),
        ],
      );
      final pop = gen.seed(profile, count: 30);
      expect(
        pop.any((p) =>
            p.template == CardTemplateType.grid &&
            p.clipShape == GridClipShape.countryOutline &&
            p.clipCode == 'JP'),
        isTrue,
      );
    });

    test('deterministic for a fixed seed', () {
      final a = RankerSeededGenerator(rng: math.Random(9)).seed(_profile(), count: 40);
      final b = RankerSeededGenerator(rng: math.Random(9)).seed(_profile(), count: 40);
      expect(
        a.map((p) => p.contentHash).toList(),
        b.map((p) => p.contentHash).toList(),
      );
    });

    test('empty profile → no seeds', () {
      final gen = RankerSeededGenerator(rng: math.Random(4));
      final empty = _profile(sets: const []);
      expect(gen.seed(empty, count: 20), isEmpty);
    });
  });

  group('GenomeMutator', () {
    const mutator = GenomeMutator();

    test('mutate stays valid', () {
      final rng = math.Random(5);
      final profile = _profile();
      var p = RankerSeededGenerator(rng: math.Random(5)).seed(profile).first;
      for (var i = 0; i < 200; i++) {
        p = mutator.mutate(p, profile, rng);
        expect(p.isValid, isTrue);
        expect(p.normalize(), p);
      }
    });

    test('crossover stays valid and is a consistent genome', () {
      final rng = math.Random(6);
      final profile = _profile();
      final pop = RankerSeededGenerator(rng: math.Random(6)).seed(profile);
      for (var i = 0; i < 100; i++) {
        final a = pop[rng.nextInt(pop.length)];
        final b = pop[rng.nextInt(pop.length)];
        final child = mutator.crossover(a, b, rng);
        expect(child.isValid, isTrue);
        // countryCodes came wholesale from one parent.
        final codes = (List<String>.of(child.countryCodes)..sort()).join(',');
        final ca = (List<String>.of(a.countryCodes)..sort()).join(',');
        final cb = (List<String>.of(b.countryCodes)..sort()).join(',');
        expect(codes == ca || codes == cb, isTrue);
      }
    });

    test('mutate is deterministic for a fixed rng', () {
      final profile = _profile();
      final seed = RankerSeededGenerator(rng: math.Random(8)).seed(profile).first;
      final x = mutator.mutate(seed, profile, math.Random(11));
      final y = mutator.mutate(seed, profile, math.Random(11));
      expect(x, y);
    });
  });

  group('OptimizationLoop', () {
    test('returns exactly 3 distinct, valid, printable candidates', () async {
      final result = await runLoop();
      expect(result.length, 3);
      expect(result.every((c) => c.params.isValid), isTrue);
      expect(result.every((c) => c.score.printable), isTrue);
      expect(result.every((c) => c.thumbnail != null), isTrue);
      final hashes = result.map((c) => c.params.contentHash).toSet();
      expect(hashes.length, 3); // distinct designs
    });

    test('respects maxGenerations (one emission per generation)', () async {
      var emissions = 0;
      await runLoop(
        budget: const DesignEngineBudget(maxGenerations: 1),
        onProgress: (_) => emissions++,
      );
      expect(emissions, 1);
    });

    test('respects maxDuration budget (stops early with a slow renderer)', () async {
      var emissions = 0;
      final sw = Stopwatch()..start();
      final result = await runLoop(
        renderer: _FakeRenderer(delay: const Duration(milliseconds: 15)),
        budget: const DesignEngineBudget(
          maxDuration: Duration(milliseconds: 40),
          maxGenerations: 50,
        ),
        onProgress: (_) => emissions++,
      );
      sw.stop();
      expect(emissions, lessThan(50)); // did not run all generations
      expect(result.length, lessThanOrEqualTo(3));
      expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('onProgress emits non-worsening (improving) best results', () async {
      final bests = <double>[];
      await runLoop(
        budget: const DesignEngineBudget(maxGenerations: 6),
        onProgress: (top) {
          if (top.isNotEmpty) bests.add(top.first.score.total());
        },
      );
      expect(bests, isNotEmpty);
      for (var i = 1; i < bests.length; i++) {
        expect(bests[i], greaterThanOrEqualTo(bests[i - 1]));
      }
    });

    test('cancellation stops the loop', () async {
      final cancel = CancellationToken()..cancel();
      final result = await runLoop(cancel: cancel);
      expect(result, isEmpty); // cancelled before any generation completed
    });

    test('generator that only makes invalid genomes → empty, no throw', () async {
      final result = await runLoop(generator: const _InvalidOnlyGenerator());
      expect(result, isEmpty);
    });

    test('a reject-all printability constraint → empty, no throw', () async {
      final result = await runLoop(constraints: const [_RejectAllConstraint()]);
      expect(result, isEmpty);
    });

    test('works with no pixel scorers (analytic ranking preserved)', () async {
      final result = await runLoop(pixel: const []);
      expect(result.length, 3);
      expect(result.every((c) => c.score.printable), isTrue);
    });

    test('deterministic for fixed generator + loop seeds', () async {
      List<String> hashesOf(List<DesignCandidate> r) =>
          r.map((c) => c.params.contentHash).toList();
      final first = await runLoop(genSeed: 3, loopSeed: 99);
      final second = await runLoop(genSeed: 3, loopSeed: 99);
      expect(hashesOf(first), hashesOf(second));
    });
  });
}
