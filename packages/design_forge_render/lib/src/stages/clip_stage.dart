import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';

import '../asset_resolver.dart';
import '../clip/passport_stamp_fallback.dart';
import '../clip/shape_geometry.dart';
import '../clip/text_mask.dart';
import '../fonts/varsity_font.dart';
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
      final stamps = _parsePassportTrips(clip.code ?? '', clip.stampMode);
      if (stamps.isEmpty) return;
      final collage = await ctx.assets.resolvePassportCollage(
        stamps,
        width: ctx.width,
        height: ctx.height,
        seed: recipe.seed,
        scatter: clip.scatter.clamp(0.0, 1.0),
        stampScale: clip.scale <= 0 ? 1.0 : clip.scale,
        ink: _resolveInk(clip.ink, recipe, ctx.target.background),
      );
      if (collage != null) {
        ctx.artwork = collage;
        return;
      }
      // No real stamp artwork for these countries (or the host bundles none):
      // draw the built-in stamp geometry instead. Passport NEVER degrades into a
      // plain flag print — it stays passport stamps, with the same entry/exit and
      // trip-date semantics.
      await _applyMask(
          ctx,
          await PassportStampFallback.build(stamps,
              width: ctx.width,
              height: ctx.height,
              seed: recipe.seed,
              scatter: clip.scatter.clamp(0.0, 1.0),
              stampScale: clip.scale <= 0 ? 1.0 : clip.scale));
      return;
    }

    final rect = _targetRect(clip, meta, ctx.width, ctx.height);

    switch (meta.source) {
      case ClipShapeSource.procedural:
        final path = ShapeGeometry.build(clip.shapeId, rect, clip.cornerRadius);
        if (path == null) return;
        final placed = _rotate(path, rect.center, clip.rotationDeg);
        if (clip.flagFit == Clip.fitStretch) {
          await _stretchFlagToBox(recipe, ctx, placed.getBounds());
        }
        await _clipToPath(ctx, placed, clip.feather);
        break;
      case ClipShapeSource.text:
        if ((clip.text ?? '').trim().isEmpty) return;
        final varsity = clip.font == VarsityFont.id;
        if (varsity) await VarsityFont.ensureLoaded();
        final mask = await TextMask.build(
          w: ctx.width,
          h: ctx.height,
          rect: rect,
          rotationDeg: clip.rotationDeg,
          text: clip.text!,
          fontFamily: varsity ? VarsityFont.family : null,
          fontWeight: varsity ? ui.FontWeight.w400 : ui.FontWeight.w800,
        );
        if (clip.flagFit == Clip.fitStretch) {
          await _stretchFlagTo(recipe, ctx, mask);
        }
        await _applyMask(ctx, mask);
        break;
      case ClipShapeSource.resolver:
        final mask = await ctx.assets.resolveClipMask(
          meta.resolverKind ?? ClipShape.none,
          clip.code,
          width: ctx.width,
          height: ctx.height,
        );
        if (mask == null) {
          // A single real stamp the resolver can't supply still renders as a
          // passport stamp (built-in geometry), never as an unclipped flag.
          final ref = meta.resolverKind == ClipShape.passportStampOutline
              ? _parseStampRef(clip.code ?? '')
              : null;
          if (ref != null) {
            await _applyMask(
                ctx,
                await PassportStampFallback.build([ref],
                    width: ctx.width,
                    height: ctx.height,
                    seed: recipe.seed,
                    scatter: 0,
                    stampScale: clip.scale <= 0 ? 1.0 : clip.scale));
          }
          return;
        }
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

  /// Resolve the passport ink. Multi‑colour: 'flag'/null → each stamp filled
  /// with its own flag. Mono: 'mono'/'auto' → a single ink chosen for contrast
  /// with the t‑shirt — black on light garments, white on dark ones (from the
  /// recipe's garment colour, else the render background). 'black'/'white' force
  /// a specific mono ink.
  static PassportInk _resolveInk(
      String? inkId, DesignRecipe recipe, ui.Color? background) {
    if (inkId == 'mono' || inkId == 'auto') {
      final lum = _garmentLuminance(recipe.palette?.garmentColour, background);
      return lum > 0.5 ? PassportInk.black : PassportInk.white;
    }
    return PassportInk.fromId(inkId);
  }

  static double _garmentLuminance(String? hex, ui.Color? background) {
    final c = _parseHex(hex) ?? background;
    if (c == null) return 1.0; // unknown → assume light → black ink
    return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
  }

  static ui.Color? _parseHex(String? hex) {
    if (hex == null) return null;
    var h = hex.replaceFirst('#', '').trim();
    if (h.length == 6) h = 'ff$h';
    if (h.length != 8) return null;
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : ui.Color(v);
  }

  /// Parse a single real-stamp code (`<slug>` or `<slug>|DATE`, e.g.
  /// `au_entry|12 MAR 24`) into a stamp ref. Null when there is no slug.
  static PassportStampRef? _parseStampRef(String code) {
    final bar = code.indexOf('|');
    final slug = (bar < 0 ? code : code.substring(0, bar)).trim();
    if (slug.isEmpty) return null;
    final date = bar < 0 ? '' : code.substring(bar + 1).trim();
    return PassportStampRef(slug, date.isEmpty ? null : date);
  }

  /// Parse a passport-page code into per-trip entry/exit stamp refs. Format is
  /// `cc|ENTRY|EXIT` segments joined by `;` (a country may repeat for multiple
  /// trips); a legacy plain `cc,cc,cc` list (no dates) is also accepted.
  ///
  /// [mode] (the mobile `stampMode`) selects which stamps to emit: null/
  /// 'entryExit' = both, 'entryOnly' = arrival only, 'exitOnly' = departure only.
  List<PassportStampRef> _parsePassportTrips(String code, String? mode) {
    final wantEntry = mode != 'exitOnly';
    final wantExit = mode != 'entryOnly';
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
        if (wantEntry) out.add(PassportStampRef('${c}_entry', entry));
        if (wantExit) out.add(PassportStampRef('${c}_exit', exit));
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

  /// Redraws the artwork as the recipe's first flag stretched to exactly
  /// fill the bounding box of [mask]'s ink (Clip.flagFit 'stretch').
  Future<void> _stretchFlagTo(
      DesignRecipe recipe, RenderContext ctx, ui.Image mask) async {
    if (recipe.content.flags.isEmpty) return;
    final data = await mask.toByteData(format: ui.ImageByteFormat.rawRgba);
    final px = data!.buffer.asUint8List();
    final w = mask.width, h = mask.height;
    var minX = w, minY = h, maxX = -1, maxY = -1;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (px[(y * w + x) * 4 + 3] > 8) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }
    if (maxX < 0) return;
    await _stretchFlagToBox(recipe, ctx,
        ui.Rect.fromLTRB(minX - 1.0, minY - 1.0, maxX + 2.0, maxY + 2.0));
  }

  /// Redraws the artwork as the recipe's first flag stretched to exactly
  /// fill [box] (Clip.flagFit 'stretch').
  Future<void> _stretchFlagToBox(
      DesignRecipe recipe, RenderContext ctx, ui.Rect box) async {
    if (recipe.content.flags.isEmpty || box.isEmpty) return;
    final flag = await ctx.assets.resolveFlag(recipe.content.flags.first.code,
        width: box.width.round().clamp(16, 4096),
        height: box.height.round().clamp(16, 4096));
    // Non-rectangular flags (Nepal's pennant) are transparent around the
    // design; back them with the flag's main colour so no letter is empty.
    final backing = await _dominantColour(flag);
    ctx.artwork = await ctx.rasterise((canvas) {
      if (backing != null) {
        canvas.drawRect(box, ui.Paint()..color = backing);
      }
      canvas.drawImageRect(
          flag,
          ui.Rect.fromLTWH(0, 0, flag.width.toDouble(), flag.height.toDouble()),
          box,
          ui.Paint()..filterQuality = ui.FilterQuality.high);
    });
  }

  /// The most common opaque colour of [img] (coarsely quantised), or null
  /// when the image has no transparency worth backing.
  static Future<ui.Color?> _dominantColour(ui.Image img) async {
    final data = await img.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    final px = data!.buffer.asUint8List();
    final counts = <int, int>{};
    var transparent = 0;
    for (var i = 0; i < px.length; i += 16) {
      if (px[i + 3] < 128) {
        transparent++;
        continue;
      }
      final key = (px[i] >> 4) << 8 | (px[i + 1] >> 4) << 4 | (px[i + 2] >> 4);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    if (transparent * 50 < px.length / 16 || counts.isEmpty) return null;
    final key = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    return ui.Color.fromARGB(255, ((key >> 8) & 0xF) * 17,
        ((key >> 4) & 0xF) * 17, (key & 0xF) * 17);
  }

  Future<void> _applyMask(RenderContext ctx, ui.Image mask) async {
    await ctx.transformArtwork((canvas, src) {
      canvas.drawImage(src, ui.Offset.zero, ui.Paint());
      canvas.drawImage(
          mask, ui.Offset.zero, ui.Paint()..blendMode = ui.BlendMode.dstIn);
    });
  }
}
