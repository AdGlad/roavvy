import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';

import '../asset_resolver.dart';
import '../clip/shape_geometry.dart';
import '../clip/text_mask.dart';
import 'render_stage.dart';

/// Clips the artwork to a shape (the geometry/mask stage). This stage is
/// **shape-agnostic**: it looks the shape up in the catalog ([clipShapeMetaById])
/// and resolves it to either a procedural [ui.Path] ([ShapeGeometry]) or an alpha
/// mask (typography via [TextMask], or an asset via `AssetResolver`), then applies
/// one placement transform (scale / aspect / position / rotation) and clips.
///
/// Adding a shape requires NO change here — only a catalog entry plus a path
/// builder (procedural) or an asset (svg/resolver).
class ClipStage extends RenderStage {
  const ClipStage();

  @override
  String get id => 'clip';

  @override
  Future<void> apply(DesignRecipe recipe, RenderContext ctx) async {
    final clip = recipe.clip;
    if (clip == null || clip.shapeId == 'none' || ctx.artwork == null) return;
    final meta = clipShapeMetaById(clip.shapeId);
    if (meta == null) return; // unknown shape → skip rather than blank out

    // Passport page is a self-contained COLLAGE (one or many countries, one or
    // many trips): each trip's real entry + exit stamps, each filled with its OWN
    // flag and stamped with the trip DATE, scattered on the page. It replaces the
    // artwork rather than masking it.
    if (meta.resolverKind == ClipShape.passportPage) {
      final stamps = _parsePassportTrips(clip.code ?? '');
      if (stamps.isEmpty) return;
      final collage = await ctx.assets.resolvePassportCollage(
        stamps,
        width: ctx.width,
        height: ctx.height,
        seed: recipe.seed,
        scatter: clip.scatter.clamp(0.0, 1.0),
        stampScale: clip.scale <= 0 ? 1.0 : clip.scale,
        ink: PassportInk.fromId(clip.ink),
      );
      if (collage != null) ctx.artwork = collage;
      return;
    }

    final rect = _targetRect(clip, meta, ctx.width, ctx.height);

    switch (meta.source) {
      case ClipShapeSource.procedural:
        final path = ShapeGeometry.build(clip.shapeId, rect, clip.cornerRadius);
        if (path == null) return;
        await _clipToPath(ctx, _rotate(path, rect.center, clip.rotationDeg),
            clip.feather);
        break;
      case ClipShapeSource.text:
        if ((clip.text ?? '').trim().isEmpty) return;
        final mask = await TextMask.build(
          w: ctx.width,
          h: ctx.height,
          rect: rect,
          rotationDeg: clip.rotationDeg,
          text: clip.text!,
        );
        await _applyMask(ctx, mask);
        break;
      case ClipShapeSource.resolver:
        final mask = await ctx.assets.resolveClipMask(
          meta.resolverKind ?? ClipShape.none,
          clip.code,
          width: ctx.width,
          height: ctx.height,
        );
        if (mask == null) return;
        await _applyMask(ctx, mask);
        break;
      case ClipShapeSource.svgAsset:
        // Custom SVG assets route through the resolver too (by code); if the
        // resolver can't supply one, skip.
        final mask = await ctx.assets.resolveClipMask(
          ClipShape.none,
          clip.code,
          width: ctx.width,
          height: ctx.height,
        );
        if (mask != null) await _applyMask(ctx, mask);
        break;
    }
  }

  /// Parse a passport-page code into per-trip entry/exit stamp refs. Format is
  /// `cc|ENTRY|EXIT` segments joined by `;` (a country may repeat for multiple
  /// trips); a legacy plain `cc,cc,cc` list (no dates) is also accepted.
  List<PassportStampRef> _parsePassportTrips(String code) {
    final out = <PassportStampRef>[];
    for (final seg in code.split(';')) {
      final s = seg.trim();
      if (s.isEmpty) continue;
      final parts = s.split('|');
      final entry = parts.length > 1 && parts[1].trim().isNotEmpty
          ? parts[1].trim()
          : null;
      final exit = parts.length > 2 && parts[2].trim().isNotEmpty
          ? parts[2].trim()
          : null;
      for (final cc in parts[0].split(',')) {
        final c = cc.trim().toLowerCase();
        if (c.isEmpty) continue;
        out.add(PassportStampRef('${c}_entry', entry));
        out.add(PassportStampRef('${c}_exit', exit));
      }
    }
    return out;
  }

  /// The box the shape occupies: its aspect (recipe override or catalog natural)
  /// fitted into `scale × frame`, centred at the clip position.
  ui.Rect _targetRect(Clip clip, ClipShapeMeta meta, int w, int h) {
    final aspect =
        clip.aspectRatio > 0 ? clip.aspectRatio : (meta.aspectRatio <= 0 ? 1.0 : meta.aspectRatio);
    final scale = clip.scale <= 0 ? 1.0 : clip.scale.clamp(0.05, 1.4);
    final maxW = scale * w, maxH = scale * h;
    double tw, th;
    if (maxW / aspect <= maxH) {
      tw = maxW;
      th = maxW / aspect;
    } else {
      th = maxH;
      tw = maxH * aspect;
    }
    final cx = (clip.position?.anchorX ?? 0.5) * w;
    final cy = (clip.position?.anchorY ?? 0.5) * h;
    return ui.Rect.fromCenter(
        center: ui.Offset(cx, cy), width: tw, height: th);
  }

  ui.Path _rotate(ui.Path path, ui.Offset center, double deg) {
    if (deg == 0) return path;
    final rad = deg * math.pi / 180;
    final c = math.cos(rad), s = math.sin(rad);
    // 4x4 column-major matrix: rotate about `center`.
    final m = Float64List(16)
      ..[0] = c
      ..[1] = s
      ..[4] = -s
      ..[5] = c
      ..[10] = 1
      ..[15] = 1
      ..[12] = center.dx - c * center.dx + s * center.dy
      ..[13] = center.dy - s * center.dx - c * center.dy;
    return path.transform(m);
  }

  Future<void> _clipToPath(RenderContext ctx, ui.Path path, double feather) async {
    await ctx.transformArtwork((canvas, src) {
      if (feather > 0) {
        canvas.saveLayer(ctx.fullRect, ui.Paint());
        final sigma = feather * ctx.width * 0.05;
        canvas.drawPath(
          path,
          ui.Paint()
            ..color = const ui.Color(0xFFFFFFFF)
            ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, sigma),
        );
        canvas.drawImage(
            src, ui.Offset.zero, ui.Paint()..blendMode = ui.BlendMode.srcIn);
        canvas.restore();
      } else {
        canvas.save();
        canvas.clipPath(path, doAntiAlias: true);
        canvas.drawImage(src, ui.Offset.zero, ui.Paint());
        canvas.restore();
      }
    });
  }

  Future<void> _applyMask(RenderContext ctx, ui.Image mask) async {
    await ctx.transformArtwork((canvas, src) {
      canvas.drawImage(src, ui.Offset.zero, ui.Paint());
      canvas.drawImage(
          mask, ui.Offset.zero, ui.Paint()..blendMode = ui.BlendMode.dstIn);
    });
  }
}
