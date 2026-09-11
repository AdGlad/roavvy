import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:design_studio/design_studio.dart';

import 'production_print_specs.dart';

/// Developer-only calibration targets, drawn through the M26 production
/// pipeline's own geometry.
///
/// The point of these is that no code in this repo can prove where a design
/// lands on a physical garment. A print file is correct when someone measures
/// a real shirt, and these are what makes that measurement possible: a ruled,
/// labelled target at exactly the dimensions and transparency a real print
/// file has, with no garment pixels in it, so whatever comes back from the
/// fulfiller can be held against a tape measure.
///
/// Never shipped to a customer and never called by the Studio.
abstract final class PrintCalibration {
  /// The font the labels are drawn in.
  ///
  /// A sheet generated inside `flutter test` has no real font available and
  /// its text comes out as blocks, which is useless on a sheet whose whole job
  /// is to be read. The harness loads one under this family before generating;
  /// when nothing is loaded the labels fall back to the default and the
  /// GEOMETRIC markers below — the grid, the boundary, the crosshair, the
  /// one-inch square, the top/left/right arrows — still carry every
  /// measurement on their own.
  static const String labelFamily = 'RoavvyCalibrationLabel';

  static const ui.Color ink = ui.Color(0xFF101010);
  static const ui.Color guide = ui.Color(0xFFD03020);
  static const ui.Color faint = ui.Color(0x40101010);

  /// One calibration sheet for [placement], on that placement's real canvas.
  static Future<ProductionArtwork> sheet(PrintPlacement placement) async {
    final spec = tshirtPrintSpec(placement);
    if (spec == null) {
      throw ProductionRenderException(
        'there is no print file for ${placement.name}, so nothing to calibrate',
      );
    }
    final sw = Stopwatch()..start();
    final canvasRect = ui.Rect.fromLTWH(
      0,
      0,
      spec.canvasWidthPx.toDouble(),
      spec.canvasHeightPx.toDouble(),
    );
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, canvasRect);

    final dpi = spec.dpi.toDouble();
    _inchGrid(canvas, canvasRect, dpi);
    _outline(canvas, canvasRect, faint, 4);
    _outline(canvas, spec.artworkArea, guide, 10);
    _crosshair(canvas, spec.artworkArea, guide, dpi);
    _edgeMarkers(canvas, spec.artworkArea, dpi);
    _edgeLabels(canvas, spec.artworkArea, dpi);
    _rulers(canvas, spec.artworkArea, dpi);
    _metadata(canvas, spec, canvasRect, dpi);

    final picture = recorder.endRecording();
    final ui.Image image;
    try {
      image = await picture.toImage(spec.canvasWidthPx, spec.canvasHeightPx);
    } finally {
      picture.dispose();
    }
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw ProductionRenderException('the calibration sheet would not encode');
      }
      final bytes = data.buffer.asUint8List();
      return ProductionArtwork(
        recipeId: 'calibration:${placement.name}',
        placement: placement,
        widthPx: spec.canvasWidthPx,
        heightPx: spec.canvasHeightPx,
        dpi: spec.dpi,
        format: spec.format,
        bytes: bytes,
        imageHash: fnv1aBytes(bytes),
        engineVersion: 'calibration',
        grammarVersion: 'calibration',
        assetsVersion: 'calibration',
        schemaVersion: 0,
        productKey: spec.productKey,
        elapsed: sw.elapsed,
      );
    } finally {
      image.dispose();
    }
  }

  /// A one-inch grid across the whole canvas, with every inch countable.
  static void _inchGrid(ui.Canvas canvas, ui.Rect area, double dpi) {
    final thin = ui.Paint()
      ..color = faint
      ..strokeWidth = 2;
    for (var x = dpi; x < area.width; x += dpi) {
      canvas.drawLine(ui.Offset(x, 0), ui.Offset(x, area.height), thin);
    }
    for (var y = dpi; y < area.height; y += dpi) {
      canvas.drawLine(ui.Offset(0, y), ui.Offset(area.width, y), thin);
    }
  }

  static void _outline(
    ui.Canvas canvas,
    ui.Rect r,
    ui.Color colour,
    double width,
  ) => canvas.drawRect(
    r.deflate(width / 2),
    ui.Paint()
      ..color = colour
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = width,
  );

  static void _crosshair(
    ui.Canvas canvas,
    ui.Rect r,
    ui.Color colour,
    double dpi,
  ) {
    final p = ui.Paint()
      ..color = colour
      ..strokeWidth = 4;
    canvas.drawLine(
      ui.Offset(r.center.dx, r.top),
      ui.Offset(r.center.dx, r.bottom),
      p,
    );
    canvas.drawLine(
      ui.Offset(r.left, r.center.dy),
      ui.Offset(r.right, r.center.dy),
      p,
    );
    // A one-inch square at dead centre: the scale check that needs no maths.
    _outline(
      canvas,
      ui.Rect.fromCenter(center: r.center, width: dpi, height: dpi),
      ink,
      5,
    );
  }

  /// Tick marks down the left edge and across the top, every inch, numbered.
  static void _rulers(ui.Canvas canvas, ui.Rect r, double dpi) {
    final p = ui.Paint()
      ..color = ink
      ..strokeWidth = 4;
    for (var i = 1; i * dpi < r.height; i++) {
      final y = r.top + i * dpi;
      canvas.drawLine(
        ui.Offset(r.left, y),
        ui.Offset(r.left + dpi * 0.35, y),
        p,
      );
      _text(canvas, '$i"', ui.Offset(r.left + dpi * 0.42, y - dpi * 0.16), 34);
    }
    for (var i = 1; i * dpi < r.width; i++) {
      final x = r.left + i * dpi;
      canvas.drawLine(
        ui.Offset(x, r.top),
        ui.Offset(x, r.top + dpi * 0.35),
        p,
      );
      _text(canvas, '$i"', ui.Offset(x + 6, r.top + dpi * 0.38), 34);
    }
  }

  /// Direction markers that need no font: a filled triangle pointing into the
  /// print area from the top, and one from each side.
  static void _edgeMarkers(ui.Canvas canvas, ui.Rect r, double dpi) {
    final p = ui.Paint()..color = guide;
    final s = dpi * 0.5;
    void triangle(ui.Offset tip, ui.Offset a, ui.Offset b) {
      canvas.drawPath(
        ui.Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy)
          ..close(),
        p,
      );
    }

    // TOP — points down, into the area.
    triangle(
      ui.Offset(r.center.dx, r.top + s),
      ui.Offset(r.center.dx - s / 2, r.top + 6),
      ui.Offset(r.center.dx + s / 2, r.top + 6),
    );
    // LEFT — points right.
    triangle(
      ui.Offset(r.left + s, r.center.dy),
      ui.Offset(r.left + 6, r.center.dy - s / 2),
      ui.Offset(r.left + 6, r.center.dy + s / 2),
    );
    // RIGHT — points left, and doubled so the two sides cannot be confused.
    for (final dy in [-s, s]) {
      triangle(
        ui.Offset(r.right - s, r.center.dy + dy),
        ui.Offset(r.right - 6, r.center.dy + dy - s / 2),
        ui.Offset(r.right - 6, r.center.dy + dy + s / 2),
      );
    }
  }

  static void _edgeLabels(ui.Canvas canvas, ui.Rect r, double dpi) {
    _text(canvas, 'TOP', ui.Offset(r.center.dx + 12, r.top + 10), 56);
    _text(canvas, 'LEFT', ui.Offset(r.left + 14, r.center.dy + 12), 56);
    _text(canvas, 'RIGHT', ui.Offset(r.right - dpi * 1.1, r.center.dy + 12), 56);
    _text(
      canvas,
      'BOTTOM',
      ui.Offset(r.center.dx + 12, r.bottom - dpi * 0.45),
      56,
    );
  }

  /// Everything a person needs to check what they are holding, printed on it.
  static void _metadata(
    ui.Canvas canvas,
    ProductionRenderSpec spec,
    ui.Rect canvasRect,
    double dpi,
  ) {
    final (wIn, hIn) = spec.physicalInches;
    final a = spec.artworkArea;
    final lines = [
      'ROAVVY PRINT CALIBRATION — ${spec.placement.name}',
      'canvas ${spec.canvasWidthPx}x${spec.canvasHeightPx}px '
          '@${spec.dpi}dpi = ${wIn.toStringAsFixed(2)}x${hIn.toStringAsFixed(2)}in',
      'artwork area ${a.width.round()}x${a.height.round()}px = '
          '${(a.width / dpi).toStringAsFixed(2)}x${(a.height / dpi).toStringAsFixed(2)}in',
      'offset from canvas top-left '
          '${(a.left / dpi).toStringAsFixed(2)}in, ${(a.top / dpi).toStringAsFixed(2)}in',
      'transparent=${spec.transparent}  product=${spec.productKey}  '
          'printfile=${TshirtPrintProfile.providerPrintfileId}',
      'grid = 1 inch. MEASURE THE PRINTED SHIRT AGAINST THESE NUMBERS.',
    ];
    var y = canvasRect.bottom - dpi * 1.5;
    for (final line in lines) {
      _text(canvas, line, ui.Offset(dpi * 0.2, y), 30);
      y += 38;
    }
  }

  static void _text(
    ui.Canvas canvas,
    String s,
    ui.Offset at,
    double size, {
    ui.Color colour = ink,
  }) {
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontFamily: labelFamily,
        fontSize: size,
        textDirection: ui.TextDirection.ltr,
      ),
    )
      ..pushStyle(
        ui.TextStyle(
          color: colour,
          fontSize: size,
          fontFamily: labelFamily,
        ),
      )
      ..addText(s);
    final p = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 4000));
    canvas.drawParagraph(p, at);
  }
}

/// Every calibration sheet there is: the four real placements.
Future<List<ProductionArtwork>> calibrationSheets() async => [
  for (final p in const [
    PrintPlacement.backFull,
    PrintPlacement.frontFull,
    PrintPlacement.frontLeftChest,
    PrintPlacement.frontRightChest,
  ])
    await PrintCalibration.sheet(p),
];

/// The bytes alone, for a caller that only wants to write files.
Future<Map<String, Uint8List>> calibrationFiles() async => {
  for (final sheet in await calibrationSheets())
    'calibration-${sheet.placement.name}.${sheet.format.extension}':
        sheet.bytes,
};
