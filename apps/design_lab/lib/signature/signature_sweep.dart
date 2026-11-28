import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:design_studio/design_studio.dart';

/// One rendered + checked design: a country's hero (index 0) or a variation.
class SweepCell {
  SweepCell({
    required this.country,
    required this.index,
    required this.recipe,
    required this.report,
    this.image,
  });

  /// The pack key: a country code, or `"a+b"` for a pair pack.
  final String country;
  final int index;
  final DesignRecipe recipe;
  final QaReport report;

  /// The transparent artwork, when the caller asked to keep it.
  final ui.Image? image;

  bool get isHero => index == 0;
  String get key => '$country#$index';
}

/// Renders a Signature Recipe across countries and runs [SignatureQa] on each
/// render. The Lab workbench and the command-line review export both use this
/// class, so they always produce the same report for the same pack (M191 T7).
class SignatureSweep {
  SignatureSweep(
    this.service, {
    this.longSide = defaultLongSide,
    this.thresholds = QaThresholds.standard,
    this.display,
  });

  /// Preview size for QA + the contact sheet (portrait 300×375).
  static const int defaultLongSide = 375;

  /// Variations per country that must pass the hard checks before approval
  /// (ADR-181 §4, M191 T6).
  static const int approvalVariations = 8;

  /// Lock countries used on approval unless the owner changes them.
  static const List<String> defaultLockCountries = [
    'us', 'jp', 'br', 'fr', 'za', 'sc', //
  ];

  /// The fixed pair set a pair pack is sheeted and approved over when it
  /// lists no `samplePairs` of its own (M207). Chosen to break designs:
  /// look-alikes, same-colour neighbours, emblems, cantons on the B side,
  /// non-rectangular, very dark/light, and the owner's reference pairs.
  static const List<String> defaultSamplePairs = [
    // Look-alikes.
    'id+mc', 'ro+td', 'nl+lu', 'ie+ci',
    // Same-colour neighbours.
    'fr+it', 'us+gb', 'co+ec', 'de+be',
    // Emblems.
    'mx+pt', 'es+cr', 'py+dz', 'br+ar', 'sa+ae',
    // Non-rectangular.
    'np+ch', 'bt+np',
    // Cantons and hoist triangles on the B side.
    'co+us', 'hu+us', 'mx+us', 'ca+us', 'gr+cy', 'au+nz', 'jm+cu',
    // Very dark / very light; discs.
    'ly+cy', 'jp+kr', 'pk+in',
    // The owner's references (ADR-185).
    've+pr', 'us+co', 'dz+py', 'gb-eng+pt',
    // Crosses, sun, regression flags.
    'fi+se', 'za+gb', 'sc+mu',
  ];

  /// Lock pairs used on approval of a pair pack unless the owner changes
  /// them.
  static const List<String> defaultLockPairs = [
    'us+co', 'fr+it', 'mx+pt', 'jp+kr', 'np+ch', 'id+mc', //
  ];

  /// The sample country lists of a list pack (M214): the first 3, 6, 12, 24
  /// and 48 of a fixed traveller's order ([SignatureList.samples]).
  static List<String> get sampleListKeys => [
    for (final l in SignatureList.samples) l.key,
  ];

  /// The keys a pack is sheeted over: [codes] for a single pack, its sample
  /// pairs (or [defaultSamplePairs]) for a pair pack, the sample lists for a
  /// list pack.
  static List<String> keysFor(SignatureRecipe pack, List<String> codes) =>
      pack.isList
      ? sampleListKeys
      : !pack.isPair
      ? codes
      : (pack.samplePairs.isNotEmpty ? pack.samplePairs : defaultSamplePairs);

  /// Default lock keys for approval.
  static List<String> defaultLocksFor(SignatureRecipe pack) => pack.isList
      ? sampleListKeys
      : pack.isPair
      ? defaultLockPairs
      : defaultLockCountries;

  /// A key every pack can render (fallbacks, orientation probes).
  static String probeKey(SignatureRecipe pack) => pack.isList
      ? SignatureRecipe.defaultSampleList.key
      : pack.isPair
      ? pack.firstPair.key
      : 'us';

  final RenderService service;
  final int longSide;
  final QaThresholds thresholds;

  /// The garment the kept image is shown on (null = neutral). Only matters
  /// for designs that change with the garment ([dependsOnGarment]).
  ui.Color? display;

  /// True when the artwork itself differs by garment: an automatic outline
  /// (dark on light shirts, light on dark) or garment-adaptive ink.
  static bool dependsOnGarment(DesignRecipe r) =>
      (r.composition.outlineWidth > 0 &&
          r.composition.outlineColour == Composition.autoOutline) ||
      r.inkIsAdaptive ||
      // Captions are inked for the shirt they print on (ADR-183), as the app
      // does (`inkFollowsShirt`).
      r.captions != null;

  static bool _isLight(ui.Color c) => c.computeLuminance() >= 0.3;

  /// Renders and checks one design. A render error becomes a hard failure,
  /// never an exception, so one bad flag cannot stop a sweep.
  ///
  /// A garment-dependent design is rendered once for the light garments and
  /// once for the dark ones, and each render is checked only against its own
  /// garments — so a green dot means it reads on every shirt AS PRINTED.
  ///
  /// [country] is a pack key: for a pair pack (`"a+b"`) the pair checks
  /// ([PairQa]) are added, and a hero is also checked in the swapped order
  /// unless [checkSwap] is false.
  Future<SweepCell> cell(
    SignatureRecipe pack,
    String country,
    int index, {
    bool keepImage = true,
    bool checkSwap = true,
  }) async {
    final c = await _cell(pack, country, index, keepImage: keepImage);
    if (!pack.isPair || !checkSwap || index != 0) return c;
    final swap = SignaturePair.parse(country).swapped.key;
    final swapped = await _cell(pack, swap, 0, keepImage: false);
    final f = PairQa.swapFinding(swap, swapped.report);
    if (f == null) return c;
    return SweepCell(
      country: c.country,
      index: c.index,
      recipe: c.recipe,
      report: QaReport.merge([
        c.report,
        QaReport(hard: [f], soft: const [], metrics: const {}),
      ]),
      image: c.image,
    );
  }

  Future<SweepCell> _cell(
    SignatureRecipe pack,
    String country,
    int index, {
    required bool keepImage,
  }) async {
    final DesignRecipe recipe;
    try {
      recipe = SignatureResolver.variationFor(pack, country, index);
    } catch (e) {
      return SweepCell(
        country: country,
        index: index,
        recipe: SignatureResolver.heroFor(pack, probeKey(pack)),
        report: SignatureQa.renderFailed(e),
      );
    }
    Future<QaReport> withPair(QaReport base, ui.Image image) async =>
        !pack.isPair
        ? base
        : QaReport.merge([
            base,
            await PairQa.checkImage(image, geometry: PairGeometry.of(recipe)),
          ]);
    try {
      if (!dependsOnGarment(recipe)) {
        final image = await service.imageFor(
          recipe,
          longSide,
          transparent: true,
        );
        final report = await withPair(
          await SignatureQa.checkImage(image, thresholds: thresholds),
          image,
        );
        return SweepCell(
          country: country,
          index: index,
          recipe: recipe,
          report: report,
          image: keepImage ? image : null,
        );
      }
      final parts = <QaReport>[];
      ui.Image? shown;
      final wantLight = display == null || _isLight(display!);
      for (final light in [true, false]) {
        final group = [
          for (final g in thresholds.garments)
            if (_isLight(g.$1) == light) g,
        ];
        if (group.isEmpty) continue;
        final image = await service.imageFor(
          recipe,
          longSide,
          transparent: true,
          background: group.first.$1,
        );
        parts.add(
          await SignatureQa.checkImage(
            image,
            thresholds: thresholds.only(group),
          ),
        );
        if (light == wantLight) shown = image;
      }
      return SweepCell(
        country: country,
        index: index,
        recipe: recipe,
        report: shown == null
            ? QaReport.merge(parts)
            : await withPair(QaReport.merge(parts), shown),
        image: keepImage ? shown : null,
      );
    } catch (e) {
      return SweepCell(
        country: country,
        index: index,
        recipe: recipe,
        report: SignatureQa.renderFailed(e),
      );
    }
  }

  /// Heroes for [countries], then (if [variations] > 0) variations 1..n for
  /// each. Stops early when [cancelled] returns true.
  Stream<SweepCell> run(
    SignatureRecipe pack,
    List<String> countries, {
    int variations = 0,
    bool keepImages = true,
    bool Function()? cancelled,
  }) async* {
    for (final cc in countries) {
      if (cancelled?.call() ?? false) return;
      yield await cell(pack, cc, 0, keepImage: keepImages);
    }
    for (var i = 1; i <= variations; i++) {
      for (final cc in countries) {
        if (cancelled?.call() ?? false) return;
        yield await cell(pack, cc, i, keepImage: keepImages);
      }
    }
  }

  /// Cells with a hard failure, which block approval.
  static List<SweepCell> blockers(Iterable<SweepCell> cells) => [
    for (final c in cells)
      if (c.report.status == QaStatus.fail) c,
  ];

  /// The QA report written beside a contact sheet.
  static Map<String, Object?> report(
    SignatureRecipe pack,
    List<SweepCell> cells, {
    required String label,
    int longSide = defaultLongSide,
  }) {
    int count(QaStatus s, {bool? hero}) => cells
        .where(
          (c) => c.report.status == s && (hero == null || c.isHero == hero),
        )
        .length;
    final byCountry = <String, List<SweepCell>>{};
    for (final c in cells) {
      (byCountry[c.country] ??= []).add(c);
    }
    final countries = byCountry.keys.toList()..sort();
    return {
      'pack': pack.id,
      'version': pack.version,
      'status': pack.status.name,
      'label': label,
      'renderLongSide': longSide,
      'summary': {
        'countries': countries.length,
        'heroes': {
          for (final s in QaStatus.values) s.name: count(s, hero: true),
        },
        'variations': {
          for (final s in QaStatus.values) s.name: count(s, hero: false),
        },
      },
      'blockers': [
        for (final c in blockers(cells))
          {
            'country': c.country,
            'index': c.index,
            'hard': [for (final f in c.report.hard) f.toJson()],
          },
      ],
      'countries': {
        for (final cc in countries)
          cc: [
            for (final c
                in byCountry[cc]!..sort((a, b) => a.index.compareTo(b.index)))
              {
                'index': c.index,
                'recipeId': c.recipe.recipeId,
                ...c.report.toJson(),
              },
          ],
      },
    };
  }

  /// A labelled grid of hero renders on [background], each with a QA dot
  /// (green pass, amber warn, red fail).
  static Future<Uint8List> contactSheet(
    List<SweepCell> cells, {
    ui.Color background = const ui.Color(0xFF9EA3A8),
    int columns = 16,
    String? labelFontFamily,
    Map<String, String> names = const {},
  }) async {
    final shown = [
      for (final c in cells)
        if (c.image != null) c,
    ];
    if (shown.isEmpty) throw StateError('No rendered cells to lay out');
    // Cells fit the largest render in each direction, so portrait and
    // landscape (rotated) designs share one grid at full size.
    var cw = 0, ch = 0;
    for (final c in shown) {
      if (c.image!.width > cw) cw = c.image!.width;
      if (c.image!.height > ch) ch = c.image!.height;
    }
    const labelH = 26, pad = 10;
    final cols = shown.length < columns ? shown.length : columns;
    final rows = (shown.length / cols).ceil();
    final w = cols * (cw + pad) + pad;
    final h = rows * (ch + labelH + pad) + pad;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)
      ..drawRect(
        ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        ui.Paint()..color = background,
      );
    for (var i = 0; i < shown.length; i++) {
      final c = shown[i];
      final x = (pad + (i % cols) * (cw + pad)).toDouble();
      final y = (pad + (i ~/ cols) * (ch + labelH + pad)).toDouble();
      final img = c.image!;
      canvas.drawImage(
        img,
        ui.Offset(x + (cw - img.width) / 2, y + (ch - img.height) / 2),
        ui.Paint(),
      );
      canvas.drawCircle(
        ui.Offset(x + 9, y + 9),
        6,
        ui.Paint()..color = statusColour(c.report.status),
      );
      final label = c.country.contains('+')
          ? _pairLabel(c.country)
          : names[c.country] == null
          ? c.country.toUpperCase()
          : '${c.country.toUpperCase()} ${names[c.country]}';
      final pb =
          ui.ParagraphBuilder(
              ui.ParagraphStyle(
                fontSize: 15,
                fontFamily: labelFontFamily,
                maxLines: 1,
                ellipsis: '…',
              ),
            )
            ..pushStyle(ui.TextStyle(color: const ui.Color(0xFF111111)))
            ..addText(c.isHero ? label : '$label · v${c.index}');
      canvas.drawParagraph(
        pb.build()..layout(ui.ParagraphConstraints(width: cw.toDouble())),
        ui.Offset(x, y + ch + 4),
      );
    }
    final image = await recorder.endRecording().toImage(w, h);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  /// `US + CO` (names are too long for a pair tile).
  static String _pairLabel(String key) {
    final p = SignaturePair.parse(key);
    return '${p.a.toUpperCase()} + ${p.b.toUpperCase()}';
  }

  static ui.Color statusColour(QaStatus s) => switch (s) {
    QaStatus.pass => const ui.Color(0xFF2E9E4F),
    QaStatus.warn => const ui.Color(0xFFE0A100),
    QaStatus.fail => const ui.Color(0xFFD7263D),
  };
}
