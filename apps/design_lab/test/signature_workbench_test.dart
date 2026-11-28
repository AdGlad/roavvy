import 'dart:io';

import 'package:design_forge/design_forge.dart';
import 'package:design_lab/flag_source.dart';
import 'package:design_lab/render_service.dart';
import 'package:design_lab/signature/signature_edit.dart';
import 'package:design_lab/signature/signature_io.dart';
import 'package:design_lab/signature/signature_screen.dart';
import 'package:design_lab/signature/signature_sweep.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:flutter/material.dart' hide Orientation;
import 'package:flutter_test/flutter_test.dart';

/// The bundled torn-flag seed pack, read from the repo.
SignatureRecipe _seedPack() => SignaturePackCodec.decode(
  File(
    '../../packages/design_studio/assets/signature/torn_flag.pack.json',
  ).readAsStringSync(),
);

/// A test-only two-country pack (M207): two flags in a duo layout. Real
/// pair packs ship from M209.
SignatureRecipe _pairPack() {
  final r = DesignRecipe(
    seed: 1,
    content: RecipeContent(flags: [FlagRef('us'), FlagRef('co')]),
    composition: const Composition(
      family: DesignFamily.duoBlend,
      orientation: Orientation.portrait,
    ),
  );
  final json = r.toJson()
    ..remove('recipeId')
    ..remove('provenance');
  RecipePath('content.flags.0.code').write(json, '{{countryA}}');
  RecipePath('content.flags.1.code').write(json, '{{countryB}}');
  return SignatureRecipe(
    id: 'test_pair',
    title: 'Test Pair',
    version: 1,
    status: SignatureStatus.draft,
    base: json,
    countries: 2,
    samplePairs: const ['us+co', 'fr+it'],
    layout: const {
      'front': {'zone': 'leftChest'},
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late SignatureIO io;
  late RenderService service;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('signature_workbench');
    io = SignatureIO(tmp)..save(_seedPack());
    service = RenderService(FlagSource.locate()!.resolver());
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  group('SignatureIO', () {
    test('save writes canonical packs and keeps the index', () {
      expect(io.listIds(), ['torn_flag']);
      final pack = io.load('torn_flag');
      expect(
        io.packFile('torn_flag').readAsStringSync(),
        SignaturePackCodec.encode(pack),
      );
      io.save(pack);
      expect(io.listIds(), ['torn_flag'], reason: 'no duplicate index entries');
    });
  });

  group('SignatureEdit', () {
    test('editable paths hide engine versions and the country slot', () {
      final paths = SignatureEdit.editablePaths(_seedPack());
      expect(paths.first, 'seed');
      expect(paths, contains('tornStrips.distress'));
      expect(paths.where((p) => p.startsWith('content.')), isEmpty);
      expect(paths, isNot(contains('engineVersion')));
    });

    test('editing an approved pack reopens it as the next draft version', () {
      final approved = SignatureEdit.approve(
        _seedPack(),
        lockCountries: ['us', 'jp'],
        approvedAt: DateTime.utc(2026, 11, 27),
      );
      expect(approved.isApproved, isTrue);
      expect(
        approved.version,
        1,
        reason: 'approval keeps the reviewed version',
      );
      expect(approved.locks.keys, unorderedEquals(['us', 'jp']));
      expect(SignatureResolver.driftedLocks(approved), isEmpty);

      final edited = SignatureEdit.setBase(
        approved,
        'tornStrips.distress',
        0.6,
      );
      expect(edited.status, SignatureStatus.draft);
      expect(edited.version, 2);
      expect(edited.approvedAt, isNull);
    });

    test('a variation saved as hero reproduces that variation', () {
      var p = SignatureEdit.setRange(
        _seedPack(),
        'seed',
        SignatureEdit.defaultRange('seed', 1),
      );
      p = SignatureEdit.setRange(
        p,
        'tornStrips.distress',
        SignatureEdit.defaultRange('tornStrips.distress', 0.75),
      );
      final v5 = SignatureResolver.variation(p, 'jp', 5);
      p = SignatureEdit.setHero(p, 'jp', SignatureEdit.heroValuesOf(p, v5));
      expect(SignatureResolver.hero(p, 'jp').recipeId, v5.recipeId);

      // Dropping a range drops hero values for it.
      p = SignatureEdit.setRange(p, 'tornStrips.distress', null);
      expect(p.heroes['jp']!.keys, ['seed']);
    });

    test('edits and approval keep layout and pair fields', () {
      var p = SignatureEdit.setRange(
        _pairPack(),
        'seed',
        SignatureEdit.defaultRange('seed', 1),
      );
      expect(p.layout, _pairPack().layout);
      expect(p.countries, 2);
      expect(p.samplePairs, ['us+co', 'fr+it']);
      p = SignatureEdit.setOverride(
        p,
        'fr+it',
        CountryOverride(params: {'seed': 7}, reason: 'clash'),
      );
      final approved = SignatureEdit.approve(
        p,
        lockCountries: ['us+co', 'FR+IT'],
        approvedAt: DateTime.utc(2026),
      );
      expect(approved.locks.keys, unorderedEquals(['us+co', 'fr+it']));
      expect(approved.layout, _pairPack().layout);
      expect(approved.isPair, isTrue);
      expect(SignatureResolver.driftedLocks(approved), isEmpty);
      // The seed pack's layout survives a base edit too (it used to drop).
      final single = _seedPack().copyWith(
        layout: const {
          'back': {'zone': 'upperBack'},
        },
      );
      expect(
        SignatureEdit.setBase(single, 'tornStrips.distress', 0.6).layout,
        single.layout,
      );
    });

    test('invalid edits are refused', () {
      final p = SignatureEdit.setRange(
        _seedPack(),
        'tornStrips.distress',
        const NumRange(0.6, 0.8),
      );
      expect(
        () => SignatureEdit.setOverride(
          p,
          'jp',
          CountryOverride(params: {'tornStrips.distress': 0.95}, reason: 'x'),
        ),
        throwsFormatException,
      );
      expect(() => SignatureEdit.parseLike(1, 'abc'), throwsFormatException);
      expect(SignatureEdit.parseLike(0.5, '0.25'), 0.25);
      expect(SignatureEdit.parseLike(true, 'false'), false);
    });

    test('rotation is editable and varies between upright and on its side', () {
      final pack = _seedPack();
      expect(
        SignatureEdit.editablePaths(pack),
        contains('composition.rotation'),
      );
      expect(
        SignatureEdit.defaultRange('composition.rotation', 0),
        const ValueSet([0, 90]),
      );
      final turned = SignatureEdit.setBase(pack, 'composition.rotation', 90);
      expect(SignatureResolver.hero(turned, 'us').composition.rotation, 90);
      expect(
        () => SignatureEdit.setBase(pack, 'composition.rotation', 45),
        throwsFormatException,
      );
    });

    test('default ranges stay inside 0..1 for unit parameters', () {
      final r =
          SignatureEdit.defaultRange('tornStrips.distress', 0.95) as NumRange;
      expect(r.min, closeTo(0.85, 1e-9));
      expect(r.max, 1.0);
    });
  });

  group('SignatureSweep', () {
    testWidgets('renders, checks and reports the same way for UI and CLI', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final sweep = SignatureSweep(service, longSide: 150);
        final pack = SignatureEdit.setRange(
          _seedPack(),
          'seed',
          SignatureEdit.defaultRange('seed', 1),
        );
        final cells = await sweep.run(pack, [
          'us',
          'jp',
        ], variations: 2).toList();
        expect(cells.map((c) => c.key), [
          'us#0',
          'jp#0',
          'us#1',
          'jp#1',
          'us#2',
          'jp#2',
        ]);
        expect(SignatureSweep.blockers(cells), isEmpty);
        final report = SignatureSweep.report(pack, cells, label: 't');
        expect((report['summary'] as Map)['countries'], 2);
        expect((report['countries'] as Map)['jp'], hasLength(3));
        final png = await SignatureSweep.contactSheet([
          for (final c in cells)
            if (c.isHero) c,
        ]);
        expect(png.length, greaterThan(1000));
      });
    });

    testWidgets('a pair cell adds the pair checks and the swapped order', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final sweep = SignatureSweep(service, longSide: 150);
        final cell = await sweep.cell(_pairPack(), 'us+co', 0);
        expect(cell.country, 'us+co');
        expect(cell.recipe.content.flags.map((f) => f.code), ['us', 'co']);
        expect(cell.report.metrics, contains('pair'));
        final v = await sweep.cell(_pairPack(), 'us+co', 2);
        expect(v.recipe.content.flags.map((f) => f.code), ['us', 'co']);
        // A swapped order that cannot render fails the hero.
        final bad = await sweep.cell(_pairPack(), 'us+zz', 0);
        expect(bad.report.status, QaStatus.fail);
        final png = await SignatureSweep.contactSheet([cell]);
        expect(png.length, greaterThan(1000));
      });
    });

    test('pair packs sheet their sample pairs', () {
      expect(SignatureSweep.keysFor(_pairPack(), const ['us']), [
        'us+co',
        'fr+it',
      ]);
      final noSamples = _pairPack().copyWith(samplePairs: const []);
      expect(
        SignatureSweep.keysFor(noSamples, const ['us']),
        SignatureSweep.defaultSamplePairs,
      );
      expect(
        SignatureSweep.defaultSamplePairs.length,
        inInclusiveRange(28, 36),
      );
      for (final k in [
        ...SignatureSweep.defaultSamplePairs,
        ...SignatureSweep.defaultLockPairs,
      ]) {
        final p = SignaturePair.parse(k);
        expect(kCountryAlpha3.containsKey(p.a), isTrue, reason: k);
        expect(kCountryAlpha3.containsKey(p.b), isTrue, reason: k);
      }
      expect(
        SignatureSweep.defaultSamplePairs.toSet(),
        containsAll(SignatureSweep.defaultLockPairs),
      );
    });

    testWidgets('an unknown flag is a hard failure, not a crash', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final cell = await SignatureSweep(
          service,
          longSide: 150,
        ).cell(_seedPack(), 'zz-not-a-flag', 0);
        expect(cell.report.status, QaStatus.fail);
      });
    });
  });

  testWidgets(
    'the workbench shows every country with a QA dot and edits the pack',
    (tester) async {
      tester.view.physicalSize = const Size(1800, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final key = GlobalKey<SignatureScreenState>();

      await tester.pumpWidget(
        MaterialApp(
          home: SignatureScreen(
            key: key,
            service: service,
            io: io,
            codes: const ['us', 'jp', 'sc'],
            countryNames: const {
              'us': 'United States',
              'jp': 'Japan',
              'sc': 'Seychelles',
            },
            sweepLongSide: 150,
          ),
        ),
      );
      Future<void> settle() async {
        for (var i = 0; i < 600; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)),
          );
          await tester.pump();
          if (!key.currentState!.isSweeping &&
              key.currentState!.cells.length == 3) {
            return;
          }
        }
      }

      await settle();
      expect(find.text('Signature Workbench'), findsOneWidget);
      expect(find.text('draft v1'), findsOneWidget);
      expect(key.currentState!.cells.keys, unorderedEquals(['us', 'jp', 'sc']));
      expect(find.byKey(const ValueKey('tile-jp')), findsOneWidget);

      // Tick "Vary" on the seed: the pack gains a range and becomes unsaved.
      await tester.tap(find.byKey(const ValueKey('vary-seed')));
      await tester.pump();
      expect(key.currentState!.pack!.envelope.ranges.keys, contains('seed'));
      expect(find.text('draft v1 · unsaved'), findsOneWidget);

      // Save writes it to disk.
      await tester.tap(find.text('Save draft'));
      await tester.pump();
      expect(io.load('torn_flag').envelope.ranges.keys, contains('seed'));

      // Undo restores the previous pack.
      await tester.tap(find.byTooltip('Undo'));
      await tester.pump();
      expect(key.currentState!.pack!.envelope.isEmpty, isTrue);
      await settle();

      // Approve: checks heroes + variations, saves the approved pack with
      // locks, writes the review sheet, then offers the golden update.
      await tester.tap(find.text('Approve…'));
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextField, 'Lock countries (goldens)'),
        'us, jp',
      );
      await tester.tap(find.text('Check & approve'));
      for (var i = 0; i < 900 && find.text('Done').evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump();
      }
      expect(find.text('Done'), findsOneWidget);
      final saved = io.load('torn_flag');
      expect(saved.isApproved, isTrue);
      expect(saved.locks.keys, unorderedEquals(['us', 'jp']));
      expect(SignatureResolver.driftedLocks(saved), isEmpty);
      expect(
        File(
          '${tmp.path}/design_studio/contact_sheets/signature/torn_flag/v1/qa_report.json',
        ).existsSync(),
        isTrue,
      );
      await tester.tap(find.text('Done'));
      await tester.pump();
      expect(find.text('approved v1'), findsOneWidget);
    },
  );

  testWidgets('a pair pack: sample pairs, A/B picker, swap and pair locks', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2200, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    io.save(_pairPack());
    final key = GlobalKey<SignatureScreenState>();
    await tester.pumpWidget(
      MaterialApp(
        home: SignatureScreen(
          key: key,
          service: service,
          io: io,
          initialPack: 'test_pair',
          codes: const ['us', 'co', 'fr', 'it', 'jp'],
          countryNames: const {
            'us': 'United States',
            'co': 'Colombia',
            'fr': 'France',
            'it': 'Italy',
            'jp': 'Japan',
          },
          sweepLongSide: 120,
        ),
      ),
    );
    Future<void> settle(int n) async {
      for (var i = 0; i < 600; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump();
        final s = key.currentState!;
        if (!s.isSweeping && s.cells.length == n) return;
      }
    }

    await settle(2);
    final state = key.currentState!;
    expect(state.keys, ['us+co', 'fr+it']);
    expect(state.cells.keys, unorderedEquals(['us+co', 'fr+it']));
    expect(find.byKey(const ValueKey('tile-us+co')), findsOneWidget);
    expect(find.byKey(const ValueKey('pair-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('pair-b')), findsOneWidget);

    // Swap the picker (us/co → co/us) and show it.
    await tester.tap(find.byKey(const ValueKey('pair-swap')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('pair-show')));
    await tester.pump();
    await settle(3);
    expect(state.keys, ['us+co', 'fr+it', 'co+us']);
    expect(state.selected, 'co+us');
    expect(find.text('CO+US Colombia + United States'), findsWidgets);

    // Swap from the inspector.
    state.showPair('jp', 'fr');
    await tester.pump();
    await settle(4);
    await tester.tap(find.byKey(const ValueKey('inspect-swap')));
    await tester.pump();
    await settle(5);
    expect(state.selected, 'fr+jp');

    // Approve with pair locks.
    await tester.tap(find.text('Approve…'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'Lock pairs (a+b, goldens)'),
      'us+co, fr+it',
    );
    await tester.tap(find.text('Check & approve'));
    for (var i = 0; i < 1500 && find.text('Done').evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
    expect(find.text('Done'), findsOneWidget);
    final saved = io.load('test_pair');
    expect(saved.isApproved, isTrue);
    expect(saved.locks.keys, unorderedEquals(['us+co', 'fr+it']));
    expect(saved.layout, _pairPack().layout);
    expect(SignatureResolver.driftedLocks(saved), isEmpty);
    await tester.tap(find.text('Done'));
    await tester.pump();
  });
}
