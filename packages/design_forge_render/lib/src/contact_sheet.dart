import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';

import 'render_target.dart';
import 'renderer.dart';

/// Composites many rendered recipes into a single contact-sheet PNG — for
/// batch review and before/after comparison. Reusable by the Lab and headless
/// harnesses alike.
class ContactSheetBuilder {
  const ContactSheetBuilder({
    this.columns = 6,
    this.cell = 220,
    this.padding = 10,
    this.background = const ui.Color(0xFF14161A),
    this.tileBackground = const ui.Color(0xFFF2F2F2),
  });

  final int columns;
  final int cell;
  final int padding;
  final ui.Color background;
  final ui.Color tileBackground;

  Future<Uint8List> build(List<DesignRecipe> recipes, Renderer renderer) async {
    final n = recipes.length;
    final cols = n < columns ? (n == 0 ? 1 : n) : columns;
    final rows = (n / cols).ceil();
    final w = cols * cell + (cols + 1) * padding;
    final h = rows * cell + (rows + 1) * padding;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    );
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      ui.Paint()..color = background,
    );

    for (var i = 0; i < n; i++) {
      final r = i ~/ cols;
      final c = i % cols;
      final x = padding + c * (cell + padding);
      final y = padding + r * (cell + padding);
      final result = await renderer.render(
        recipes[i],
        RenderTarget.preview(size: cell, background: tileBackground),
      );
      canvas.drawImage(result.image, ui.Offset(x.toDouble(), y.toDouble()),
          ui.Paint());
    }

    final image = await recorder.endRecording().toImage(w, h);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }
}
