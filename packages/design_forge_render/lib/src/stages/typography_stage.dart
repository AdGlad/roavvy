import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';

import 'render_stage.dart';

/// Renders the title/footer text overlay described by [DesignRecipe.typography].
///
/// The [Typography] recipe group carries only the *treatment* (case, placement,
/// style hint) — the printed STRING is not part of the reproducible genome and
/// is supplied at render time via [RecipeContent.meta] under the `'title'` key.
/// When there is no `title` in `meta`, or `placement == none`, or no
/// [DesignRecipe.typography] at all, this stage is a no-op and the output is
/// byte-identical to the pipeline without it.
///
/// This stage runs LAST — a top overlay after the colour grade — so the grade
/// never washes out the text.
///
/// The display face is [Typography.titleStyle] — a font-family NAME resolved by
/// the host platform (e.g. a macOS system face like "Futura"). It falls back to
/// the platform default when the family is unavailable (e.g. Ahem under
/// flutter_test). To ship a specific licensed face across platforms, bundle an
/// OFL/Apache `.ttf` in `apps/design_lab/pubspec.yaml` and set its family as the
/// `titleStyle`; no code change here is needed.
class TypographyStage extends RenderStage {
  const TypographyStage();

  @override
  String get id => 'typography';

  @override
  Future<void> apply(DesignRecipe recipe, RenderContext ctx) async {
    if (recipe.composition.statementHero) {
      await _statementHero(recipe, ctx);
      return;
    }
    final typo = recipe.typography;
    if (typo == null || typo.placement == TextPlacement.none) return;

    final raw = recipe.content.meta['title'];
    if (raw is! String) return;
    final title = transformCase(raw.trim(), typo.textCase);
    if (title.isEmpty) return;

    final w = ctx.width.toDouble();
    final h = ctx.height.toDouble();
    final ink = _legibleInk(ctx.target.background);

    // A horizontal band across the top or bottom of the frame.
    final bandH = h * 0.16;
    final bandTop =
        typo.placement == TextPlacement.top ? h * 0.04 : h - bandH - h * 0.04;
    final margin = w * 0.08;
    final maxWidth = w - margin * 2;

    // Size the text to the band, then shrink to fit the width if it overflows.
    var fontSize = bandH * 0.62;
    ui.Paragraph build(double size) {
      final b = ui.ParagraphBuilder(ui.ParagraphStyle(
        fontSize: size,
        fontWeight: ui.FontWeight.w800,
        textAlign: ui.TextAlign.center,
        // The display face — a system font name (e.g. Futura). Falls back to the
        // platform default when unavailable (e.g. Ahem under flutter_test).
        fontFamily: typo.titleStyle,
      ))
        ..pushStyle(ui.TextStyle(color: ink))
        ..addText(title);
      return b.build()..layout(ui.ParagraphConstraints(width: maxWidth));
    }

    var para = build(fontSize);
    final longest =
        para.longestLine > 0 ? para.longestLine : para.maxIntrinsicWidth;
    if (longest > maxWidth && longest > 0) {
      fontSize *= maxWidth / longest;
      para = build(fontSize);
    }

    final origin = ui.Offset(margin, bandTop + (bandH - para.height) / 2);

    if (ctx.artwork == null) {
      ctx.artwork = await ctx.rasterise((canvas) {
        canvas.drawParagraph(para, origin);
      });
      return;
    }
    await ctx.transformArtwork((canvas, src) {
      canvas.drawImage(src, ui.Offset.zero, ui.Paint());
      canvas.drawParagraph(para, origin);
    });
  }

  /// Big-count hero (the mobile `statementHero`): the traveller's COUNT as the
  /// dominant element (e.g. "28" over "COUNTRIES"). The count comes from
  /// `meta['count']`, else the number of flags/entries; the label from
  /// `meta['countLabel']` (default "COUNTRIES").
  Future<void> _statementHero(DesignRecipe recipe, RenderContext ctx) async {
    final meta = recipe.content.meta;
    final cv = meta['count'];
    final count = cv is num
        ? cv.toInt()
        : (cv is String ? int.tryParse(cv) ?? _fallbackCount(recipe) : _fallbackCount(recipe));
    final label = (meta['countLabel'] is String
            ? meta['countLabel'] as String
            : 'COUNTRIES')
        .toUpperCase();
    final w = ctx.width.toDouble();
    final h = ctx.height.toDouble();
    final ink = _legibleInk(ctx.target.background);

    ui.Paragraph para(String s, double size, ui.FontWeight wt) {
      final b = ui.ParagraphBuilder(ui.ParagraphStyle(
        fontSize: size,
        fontWeight: wt,
        textAlign: ui.TextAlign.center,
      ))
        ..pushStyle(ui.TextStyle(color: ink))
        ..addText(s);
      return b.build()..layout(ui.ParagraphConstraints(width: w * 0.9));
    }

    final big = para('$count', h * 0.4, ui.FontWeight.w900);
    final sub = para(label, h * 0.08, ui.FontWeight.w700);
    final top = (h - big.height - sub.height) / 2;
    final x = w * 0.05;
    void paint(ui.Canvas canvas) {
      canvas.drawParagraph(big, ui.Offset(x, top));
      canvas.drawParagraph(sub, ui.Offset(x, top + big.height));
    }

    if (ctx.artwork == null) {
      ctx.artwork = await ctx.rasterise(paint);
    } else {
      await ctx.transformArtwork((canvas, src) {
        canvas.drawImage(src, ui.Offset.zero, ui.Paint());
        paint(canvas);
      });
    }
  }

  static int _fallbackCount(DesignRecipe r) => r.content.flags.isNotEmpty
      ? r.content.flags.length
      : r.content.entries.length;

  /// Applies the recipe's [TextCase] to [text]. Exposed for unit testing: under
  /// the Ahem test font upper/lower glyphs render as identical boxes, so the
  /// transformation is verified here rather than through pixels.
  static String transformCase(String text, TextCase c) {
    switch (c) {
      case TextCase.upper:
        return text.toUpperCase();
      case TextCase.lower:
        return text.toLowerCase();
      case TextCase.title:
        return _titleCase(text);
      case TextCase.asIs:
        return text;
    }
  }

  static String _titleCase(String text) =>
      text.replaceAllMapped(RegExp(r'\S+'), (m) {
        final word = m[0]!;
        return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
      });

  /// A legible default ink chosen from the (optional) garment background so the
  /// text stays readable without depending on the colour/garment stage.
  static ui.Color _legibleInk(ui.Color? background) {
    if (background == null) return const ui.Color(0xFF1A1A1A);
    final lum =
        0.2126 * background.r + 0.7152 * background.g + 0.0722 * background.b;
    return lum > 0.5 ? const ui.Color(0xFF1A1A1A) : const ui.Color(0xFFF5F5F5);
  }
}
