import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';

import 'render_stage.dart';

/// Builds the artwork for the **data-driven** design families that read the
/// travel history in `recipe.content.entries` (country + label + trip dates +
/// visit weight), rather than just flags:
///   * [DesignFamily.timeline]  — a dated, chronological trip list with a spine;
///   * [DesignFamily.journeys]  — flag "stops" along a winding dotted route;
///   * [DesignFamily.wordCloud] — country names sized by visit frequency.
///
/// Everything is headless `ui.Canvas`; text uses `ui.Paragraph`. The result is a
/// transparent artwork image (so clip/edge/effects/colour stages still apply).
class DataLayouts {
  const DataLayouts._();

  static const _ink = ui.Color(0xFF23262B);
  static const _muted = ui.Color(0xFF6B7078);
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const _accent = ui.Color(0xFFC24D3A);

  /// True for families this builder handles.
  static bool handles(DesignFamily f) =>
      f == DesignFamily.timeline ||
      f == DesignFamily.journeys ||
      f == DesignFamily.wordCloud ||
      f == DesignFamily.badge ||
      f == DesignFamily.frontRibbon ||
      f == DesignFamily.achievements ||
      f == DesignFamily.stats;

  static Future<void> build(DesignRecipe recipe, RenderContext ctx) async {
    final entries = recipe.content.entries.isNotEmpty
        ? recipe.content.entries
        : [for (final f in recipe.content.flags) RecipeEntry(code: f.code)];
    if (entries.isEmpty) return;

    // Resolve each distinct flag once (chips), at a modest working size.
    final flags = <String, ui.Image>{};
    for (final e in entries) {
      flags[e.code] ??=
          await ctx.assets.resolveFlag(e.code, width: 256, height: 256);
    }

    switch (recipe.composition.family) {
      case DesignFamily.timeline:
        ctx.artwork = await _timeline(ctx, entries, flags);
        break;
      case DesignFamily.journeys:
        ctx.artwork = await _journey(ctx, entries, flags, recipe.seed);
        break;
      case DesignFamily.wordCloud:
        ctx.artwork = await _wordCloud(ctx, entries, flags, recipe.seed);
        break;
      case DesignFamily.badge:
        ctx.artwork = await _badge(ctx, entries, flags, recipe.content.meta);
        break;
      case DesignFamily.frontRibbon:
        ctx.artwork =
            await _frontRibbon(ctx, entries, flags, recipe.content.meta);
        break;
      case DesignFamily.achievements:
        ctx.artwork =
            await _achievements(ctx, entries, flags, recipe.content.meta);
        break;
      case DesignFamily.stats:
        ctx.artwork = await _stats(ctx, entries, flags, recipe.content.meta);
        break;
      default:
        break;
    }
  }

  // ── Badge (circular explorer emblem) ─────────────────────────────────────────

  static Future<ui.Image> _badge(RenderContext ctx, List<RecipeEntry> entries,
      Map<String, ui.Image> flags, Map<String, Object?> meta) async {
    final w = ctx.width.toDouble(), h = ctx.height.toDouble();
    final cc = entries.map((e) => e.code).toList();
    final count = (meta['count'] as num?)?.toInt() ?? cc.length;
    final scope = (meta['scope'] as String?) ?? 'EXPLORER';
    return ctx.rasterise((canvas) {
      final centre = ui.Offset(w / 2, h / 2);
      final r = math.min(w, h) * 0.42;
      // Double ring + tick marks.
      final ring = ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..color = _ink
        ..strokeWidth = math.max(3, r * 0.03);
      canvas.drawCircle(centre, r, ring);
      canvas.drawCircle(
          centre,
          r * 0.86,
          ui.Paint()
            ..style = ui.PaintingStyle.stroke
            ..color = _ink
            ..strokeWidth = math.max(1.5, r * 0.012));
      const ticks = 60;
      for (var i = 0; i < ticks; i++) {
        final a = i * 2 * math.pi / ticks;
        final r1 = r * 0.90, r2 = r * (i % 5 == 0 ? 0.83 : 0.86);
        canvas.drawLine(
            centre + ui.Offset(math.cos(a) * r1, math.sin(a) * r1),
            centre + ui.Offset(math.cos(a) * r2, math.sin(a) * r2),
            ui.Paint()
              ..color = _muted
              ..strokeWidth = r * 0.006);
      }
      // Flag chips in an arc across the top.
      final show = cc.take(9).toList();
      final chip = r * 0.20;
      for (var i = 0; i < show.length; i++) {
        final t = show.length == 1 ? 0.5 : i / (show.length - 1);
        final a = math.pi * (1.15 - 0.30) - t * (math.pi * 0.85); // top arc
        final cx = centre.dx + math.cos(a) * r * 0.6;
        final cy = centre.dy - math.sin(a).abs() * r * 0.42 - r * 0.12;
        _flagCircle(canvas, flags[show[i]]!, ui.Offset(cx, cy), chip / 2);
      }
      // Big count + label at the centre.
      _text(canvas, '$count', ui.Offset(centre.dx - r, centre.dy - r * 0.12),
          r * 0.6, _accent, ui.FontWeight.w900,
          maxWidth: r * 2, center: true);
      _text(
          canvas,
          count == 1 ? 'COUNTRY' : 'COUNTRIES',
          ui.Offset(centre.dx - r, centre.dy + r * 0.34),
          r * 0.16,
          _ink,
          ui.FontWeight.w700,
          maxWidth: r * 2,
          center: true);
      _text(
          canvas,
          scope.toUpperCase(),
          ui.Offset(centre.dx - r, centre.dy + r * 0.56),
          r * 0.12,
          _muted,
          ui.FontWeight.w600,
          maxWidth: r * 2,
          center: true);
    });
  }

  // ── Front ribbon (the chest wordmark + flag grid) ───────────────────────────

  /// The shirt FRONT: the ROAVVY wordmark over a centred grid of flag tiles.
  ///
  /// This is the app's original front artwork (`FrontRibbonCard`) rebuilt for
  /// the forge renderer, and it is deliberately literal about it — the same
  /// wordmark band at 14% of the block width, the same 4:3 tiles at up to eight
  /// per row with the last row centred, the same hairline gap and corner
  /// rounding. A chest print is small, so the composition has to stay the one
  /// people already recognise rather than a new arrangement.
  ///
  /// Two overrides keep it a family rather than a single fixed lockup:
  ///   * `meta['frontWordmark']` replaces the wordmark; `''` drops it, leaving
  ///     flags alone.
  ///   * `meta['frontSubtitle']` adds a line beneath the flags (the traveller
  ///     level the original card carried). Absent by default.
  static Future<ui.Image> _frontRibbon(
      RenderContext ctx,
      List<RecipeEntry> entries,
      Map<String, ui.Image> flags,
      Map<String, Object?> meta) async {
    final cw = ctx.width.toDouble(), ch = ctx.height.toDouble();
    final cc = [for (final e in entries) e.code];
    if (cc.isEmpty) return ctx.rasterise((_) {});

    final wordmark = (meta['frontWordmark'] as String?)?.trim() ?? 'ROAVVY';
    final subtitle = (meta['frontSubtitle'] as String?)?.trim() ?? '';
    // Legible against the garment it will be printed on — the original card
    // took its text colour from the caller for the same reason.
    final ink = _legibleInk(ctx.target.background);

    // Laid out in TILE units (one tile wide = 1.0), then scaled to the canvas,
    // so the proportions hold at preview size and at print resolution alike.
    const tileH = 0.75; // 4:3 tiles, as the original
    const maxPerRow = 8;

    // How many tiles per row. The original always used eight, which suits the
    // wide full-front print it was drawn for; squeezed into a left-chest badge
    // that same row leaves the flags a few pixels tall. So the grid is shaped
    // to the print area it is actually given — eight across a wide front, fewer
    // and stacked on a chest badge — which keeps the composition legible at
    // every placement without changing what it is.
    final target = cw / math.max(1.0, ch);
    var perRow = math.min(maxPerRow, cc.length);
    var best = double.infinity;
    for (var n = 1; n <= math.min(maxPerRow, cc.length); n++) {
      final r = (cc.length / n).ceil();
      final w = n.toDouble();
      final h = (wordmark.isEmpty ? 0.0 : w * 0.14) +
          r * tileH +
          (subtitle.isEmpty ? 0.0 : w * 0.14);
      final diff = (math.log(w / h) - math.log(target)).abs();
      if (diff < best) {
        best = diff;
        perRow = n;
      }
    }

    final rows = (cc.length / perRow).ceil();
    final blockW = perRow.toDouble();
    final bandH = blockW * 0.14;
    final topH = wordmark.isEmpty ? 0.0 : bandH;
    final subH = subtitle.isEmpty ? 0.0 : bandH;
    final totalH = topH + rows * tileH + subH;

    final scale = math.min(cw / blockW, ch / totalH);
    final drawW = blockW * scale, drawH = totalH * scale;
    final ox = (cw - drawW) / 2, oy = (ch - drawH) / 2;
    final tile = scale; // one tile unit in pixels
    final gap = math.max(1.0, tile * 0.02);

    return ctx.rasterise((canvas) {
      canvas.save();
      canvas.translate(ox, oy);

      if (wordmark.isNotEmpty) {
        final size = bandH * scale * 0.45;
        _text(canvas, wordmark, ui.Offset(0, (topH * scale - size * 1.2) / 2),
            size, ink, ui.FontWeight.w800,
            maxWidth: drawW, center: true, letterSpacing: size * 0.22);
      }

      var i = 0;
      for (var r = 0; r < rows; r++) {
        // The last row may be short — centre it, as the original does.
        final inRow = math.min(perRow, cc.length - r * perRow);
        final rowW = tile * inRow;
        final startX = (drawW - rowW) / 2;
        for (var c = 0; c < inRow; c++) {
          final rect = ui.Rect.fromLTWH(
            startX + c * tile + gap / 2,
            topH * scale + r * tileH * scale + gap / 2,
            tile - gap,
            tileH * scale - gap,
          );
          _flagChip(canvas, flags[cc[i]]!, rect, gap);
          i++;
        }
      }

      if (subtitle.isNotEmpty) {
        final size = bandH * scale * 0.35;
        final y = topH * scale + rows * tileH * scale;
        _text(
            canvas,
            subtitle.toUpperCase(),
            ui.Offset(0, y + (subH * scale - size * 1.2) / 2),
            size,
            ink,
            ui.FontWeight.w600,
            maxWidth: drawW,
            center: true,
            letterSpacing: size * 0.18);
      }
      canvas.restore();
    });
  }

  /// Dark ink on a light garment, light ink on a dark one. Mirrors the
  /// typography stage so the front and the printed title agree.
  static ui.Color _legibleInk(ui.Color? background) {
    if (background == null) return _ink;
    final lum =
        0.2126 * background.r + 0.7152 * background.g + 0.0722 * background.b;
    return lum > 0.5 ? _ink : const ui.Color(0xFFF5F5F5);
  }

  // ── Achievements (milestone emblem) ──────────────────────────────────────────

  static Future<ui.Image> _achievements(
      RenderContext ctx,
      List<RecipeEntry> entries,
      Map<String, ui.Image> flags,
      Map<String, Object?> meta) async {
    final w = ctx.width.toDouble(), h = ctx.height.toDouble();
    final milestone = (meta['milestone'] as String?) ?? 'EXPLORER';
    final sub = (meta['sub'] as String?) ?? '${entries.length} countries';
    final cc = entries.map((e) => e.code).toList();
    return ctx.rasterise((canvas) {
      final centre = ui.Offset(w / 2, h * 0.42);
      final r = math.min(w, h) * 0.30;
      // Star medallion.
      final star = _starPath(centre, r, r * 0.46, 12);
      canvas.drawPath(star, ui.Paint()..color = _accent);
      canvas.drawPath(
          star,
          ui.Paint()
            ..style = ui.PaintingStyle.stroke
            ..color = _ink
            ..strokeWidth = r * 0.04);
      // A hero flag (first country) in the medallion centre.
      if (cc.isNotEmpty) {
        _flagCircle(canvas, flags[cc.first]!, centre, r * 0.5);
      }
      // Milestone title + subtitle beneath.
      _text(canvas, milestone.toUpperCase(), ui.Offset(w * 0.1, h * 0.74),
          h * 0.075, _ink, ui.FontWeight.w900,
          maxWidth: w * 0.8, center: true);
      _text(canvas, sub.toUpperCase(), ui.Offset(w * 0.1, h * 0.83), h * 0.035,
          _muted, ui.FontWeight.w600,
          maxWidth: w * 0.8, center: true);
    });
  }

  // ── Stats (travel-story infographic) ─────────────────────────────────────────

  static Future<ui.Image> _stats(RenderContext ctx, List<RecipeEntry> entries,
      Map<String, ui.Image> flags, Map<String, Object?> meta) async {
    final w = ctx.width.toDouble(), h = ctx.height.toDouble();
    final countries = (meta['count'] as num?)?.toInt() ?? entries.length;
    final trips = (meta['trips'] as num?)?.toInt() ?? entries.length;
    final continents = (meta['continents'] as num?)?.toInt() ?? 0;
    final worldPct = (meta['worldPct'] as num?)?.toInt() ??
        ((countries / 195 * 100).round());
    final cc = entries.map((e) => e.code).toList();
    return ctx.rasterise((canvas) {
      // Three big stat blocks stacked, then a flag strip.
      final stats = <(String, String)>[
        ('$countries', countries == 1 ? 'COUNTRY' : 'COUNTRIES'),
        ('$continents', continents == 1 ? 'CONTINENT' : 'CONTINENTS'),
        ('$worldPct%', 'OF THE WORLD'),
      ];
      final rowH = h * 0.20;
      for (var i = 0; i < stats.length; i++) {
        final y = h * 0.10 + i * rowH;
        _text(canvas, stats[i].$1, ui.Offset(w * 0.10, y), rowH * 0.62, _accent,
            ui.FontWeight.w900,
            maxWidth: w * 0.8);
        _text(canvas, stats[i].$2, ui.Offset(w * 0.10, y + rowH * 0.62),
            rowH * 0.22, _muted, ui.FontWeight.w700,
            maxWidth: w * 0.8);
      }
      // '$trips trips' note.
      _text(canvas, '$trips ${trips == 1 ? 'TRIP' : 'TRIPS'}',
          ui.Offset(w * 0.10, h * 0.72), h * 0.045, _ink, ui.FontWeight.w700,
          maxWidth: w * 0.8);
      // Flag strip along the bottom.
      final show = cc.take(8).toList();
      if (show.isNotEmpty) {
        final chip = math.min(w * 0.85 / show.length, h * 0.12);
        final total = chip * 1.4 * show.length;
        var x = (w - total) / 2;
        for (final c in show) {
          _flagChip(canvas, flags[c]!,
              ui.Rect.fromLTWH(x, h * 0.85, chip * 1.3, chip), chip * 0.12);
          x += chip * 1.4;
        }
      }
    });
  }

  static ui.Path _starPath(
      ui.Offset c, double rOuter, double rInner, int points) {
    final p = ui.Path();
    for (var i = 0; i < points * 2; i++) {
      final r = i.isEven ? rOuter : rInner;
      final a = -math.pi / 2 + i * math.pi / points;
      final pt = c + ui.Offset(math.cos(a) * r, math.sin(a) * r);
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  // ── Timeline ───────────────────────────────────────────────────────────────

  static Future<ui.Image> _timeline(RenderContext ctx,
      List<RecipeEntry> entries, Map<String, ui.Image> flags) async {
    final w = ctx.width.toDouble(), h = ctx.height.toDouble();
    // Chronological; cap so rows stay legible.
    final rows = [...entries]..sort(
        (a, b) => (a.start ?? DateTime(0)).compareTo(b.start ?? DateTime(0)));
    final shown = rows.take(10).toList();
    return ctx.rasterise((canvas) {
      final padX = w * 0.08, padY = h * 0.08;
      final spineX = padX + w * 0.06;
      final rowH = (h - padY * 2) / shown.length;
      // Spine.
      canvas.drawLine(
          ui.Offset(spineX, padY + rowH * 0.5),
          ui.Offset(spineX, padY + rowH * (shown.length - 0.5)),
          ui.Paint()
            ..color = _muted
            ..strokeWidth = math.max(2, w * 0.004));
      for (var i = 0; i < shown.length; i++) {
        final e = shown[i];
        final cy = padY + rowH * (i + 0.5);
        // Node dot.
        canvas.drawCircle(ui.Offset(spineX, cy), math.max(4, w * 0.012),
            ui.Paint()..color = _ink);
        // Flag chip (rounded) just right of the spine.
        final chip = math.min(rowH * 0.62, w * 0.14);
        final chipRect = ui.Rect.fromCenter(
            center: ui.Offset(spineX + w * 0.09, cy),
            width: chip * 1.5,
            height: chip);
        _flagChip(canvas, flags[e.code]!, chipRect, chip * 0.16);
        // Text: name (bold) + date range.
        final tx = chipRect.right + w * 0.03;
        final name = e.label.isEmpty ? e.code.toUpperCase() : e.label;
        _text(canvas, name.toUpperCase(), ui.Offset(tx, cy - rowH * 0.30),
            rowH * 0.30, _ink, ui.FontWeight.w800,
            maxWidth: w - tx - padX);
        _text(canvas, _range(e), ui.Offset(tx, cy + rowH * 0.02), rowH * 0.22,
            _muted, ui.FontWeight.w500,
            maxWidth: w - tx - padX);
      }
    });
  }

  // ── Journeys (winding route with stops) ──────────────────────────────────────

  static Future<ui.Image> _journey(RenderContext ctx, List<RecipeEntry> entries,
      Map<String, ui.Image> flags, int seed) async {
    final w = ctx.width.toDouble(), h = ctx.height.toDouble();
    final stops = entries.take(12).toList();
    return ctx.rasterise((canvas) {
      final n = stops.length;
      final padY = h * 0.12;
      final usableH = h - padY * 2;
      // A vertical serpentine: y descends, x sine-wobbles.
      ui.Offset at(int i) {
        final t = n == 1 ? 0.5 : i / (n - 1);
        final y = padY + usableH * t;
        final x = w * 0.5 + math.sin(t * math.pi * 2.2) * (w * 0.30);
        return ui.Offset(x, y);
      }

      // Dotted route.
      final dot = ui.Paint()..color = _muted;
      for (var i = 0; i < n - 1; i++) {
        final a = at(i), b = at(i + 1);
        const steps = 14;
        for (var s = 1; s < steps; s++) {
          final p = ui.Offset.lerp(a, b, s / steps)!;
          canvas.drawCircle(p, math.max(1.5, w * 0.004), dot);
        }
      }
      // Stops: circular flag chips + label.
      final chip = math.min(w * 0.16, usableH / n * 0.9);
      for (var i = 0; i < n; i++) {
        final e = stops[i];
        final c = at(i);
        _flagCircle(canvas, flags[e.code]!, c, chip / 2);
        final name = e.label.isEmpty ? e.code.toUpperCase() : e.label;
        _text(
            canvas,
            name.toUpperCase(),
            ui.Offset(c.dx - w * 0.18, c.dy + chip * 0.55),
            chip * 0.26,
            _ink,
            ui.FontWeight.w700,
            maxWidth: w * 0.36,
            center: true);
      }
    });
  }

  // ── Word cloud (names sized by visit frequency, spiral-packed) ───────────────

  static Future<ui.Image> _wordCloud(RenderContext ctx,
      List<RecipeEntry> entries, Map<String, ui.Image> flags, int seed) async {
    final w = ctx.width.toDouble(), h = ctx.height.toDouble();
    // Largest weight first — big words claim the centre, smaller ones fill in.
    final words = [...entries]..sort((a, b) => b.weight.compareTo(a.weight));
    final maxW = words.first.weight.clamp(1, 1 << 20).toDouble();
    final n = words.length;
    // Per-word colour sampled from its flag so the cloud stays travel-themed.
    final colours = <String, ui.Color>{};
    for (final e in words) {
      colours[e.code] ??= await _dominantColour(flags[e.code]!);
    }

    // Frequency → font size (like the mobile word_cloud mintextsize/maxtextsize).
    final minSize = h * (n <= 3 ? 0.07 : 0.030);
    final maxSize = h *
        (n <= 3
            ? 0.15
            : n <= 10
                ? 0.11
                : 0.085);
    final rng = DeterministicRng(seed).stream('wordcloud');

    return ctx.rasterise((canvas) {
      final placed = <ui.Rect>[];
      final centre = ui.Offset(w / 2, h / 2);
      // Archimedean-spiral packing: each word spirals out from the centre until
      // it finds a spot that fits the frame and doesn't overlap earlier words.
      final step = math.min(w, h) * 0.010;
      for (final e in words) {
        final name =
            (e.label.isEmpty ? e.code.toUpperCase() : e.label).toUpperCase();
        final uniform = maxW <= 1; // no real frequency → vary a little by rank
        final f = uniform
            ? 0.45 + rng.nextDouble() * 0.55
            : math.sqrt((e.weight / maxW).clamp(0.0, 1.0));
        var size = minSize + (maxSize - minSize) * f;
        double measureW(ui.Paragraph p) =>
            p.longestLine <= 0 ? p.maxIntrinsicWidth : p.longestLine;
        var para = _para(name, size, colours[e.code]!, ui.FontWeight.w800)
          ..layout(const ui.ParagraphConstraints(width: 100000));
        // Shrink oversized words so every one fits the frame width and can be
        // packed (a long name never spills off or fails placement).
        final maxBoxW = w * 0.92;
        var tw0 = measureW(para) + size * 0.28;
        if (tw0 > maxBoxW) {
          size *= maxBoxW / tw0;
          para = _para(name, size, colours[e.code]!, ui.FontWeight.w800)
            ..layout(const ui.ParagraphConstraints(width: 100000));
        }
        final tw = measureW(para);
        final th = para.height;
        // Pack boxes tightly: trim the font's line leading (~0.66·height ≈ the
        // glyph band) so words nest into a dense cloud rather than a spaced list.
        final boxW = tw + size * 0.28, boxH = th * 0.66;

        ui.Rect? spot;
        final startAng = rng.nextDouble() * math.pi * 2;
        for (var t = 0.0; t < 260 && spot == null; t += 0.3) {
          final ang = startAng + t;
          final rad = step * t;
          // Squash vertically so the cloud fills a landscape-ish oval.
          final cx = centre.dx + rad * math.cos(ang);
          final cy = centre.dy + rad * math.sin(ang) * 0.72;
          final rect = ui.Rect.fromCenter(
              center: ui.Offset(cx, cy), width: boxW, height: boxH);
          if (rect.left < 2 ||
              rect.top < 2 ||
              rect.right > w - 2 ||
              rect.bottom > h - 2) {
            continue;
          }
          var ok = true;
          for (final p in placed) {
            if (rect.overlaps(p)) {
              ok = false;
              break;
            }
          }
          if (ok) spot = rect;
        }
        spot ??= ui.Rect.fromCenter(center: centre, width: boxW, height: boxH);
        placed.add(spot);
        canvas.drawParagraph(
            para, ui.Offset(spot.center.dx - tw / 2, spot.center.dy - th / 2));
      }
    });
  }

  // ── shared drawing helpers ───────────────────────────────────────────────────

  static void _flagChip(
      ui.Canvas canvas, ui.Image img, ui.Rect rect, double radius) {
    canvas.save();
    canvas.clipRRect(
        ui.RRect.fromRectAndRadius(rect, ui.Radius.circular(radius)));
    _cover(canvas, img, rect);
    canvas.restore();
  }

  static void _flagCircle(
      ui.Canvas canvas, ui.Image img, ui.Offset c, double r) {
    final rect = ui.Rect.fromCircle(center: c, radius: r);
    canvas.save();
    canvas.clipPath(ui.Path()..addOval(rect));
    _cover(canvas, img, rect);
    canvas.restore();
    canvas.drawCircle(
        c,
        r,
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = r * 0.09
          ..color = const ui.Color(0xFFFFFFFF));
  }

  static void _cover(ui.Canvas canvas, ui.Image img, ui.Rect rect) {
    final iw = img.width.toDouble(), ih = img.height.toDouble();
    final s = math.max(rect.width / iw, rect.height / ih);
    final dw = iw * s, dh = ih * s;
    canvas.drawImageRect(
        img,
        ui.Rect.fromLTWH(0, 0, iw, ih),
        ui.Rect.fromCenter(center: rect.center, width: dw, height: dh),
        ui.Paint()..filterQuality = ui.FilterQuality.medium);
  }

  static ui.Paragraph _para(
      String text, double size, ui.Color color, ui.FontWeight weight,
      {bool center = false, double letterSpacing = 0}) {
    final b = ui.ParagraphBuilder(ui.ParagraphStyle(
      fontSize: size,
      fontWeight: weight,
      textAlign: center ? ui.TextAlign.center : ui.TextAlign.left,
    ))
      ..pushStyle(ui.TextStyle(color: color, letterSpacing: letterSpacing))
      ..addText(text);
    return b.build();
  }

  static void _text(ui.Canvas canvas, String text, ui.Offset topLeft,
      double size, ui.Color color, ui.FontWeight weight,
      {double maxWidth = 100000,
      bool center = false,
      double letterSpacing = 0}) {
    final para = _para(text, size, color, weight,
        center: center, letterSpacing: letterSpacing);
    para.layout(ui.ParagraphConstraints(width: maxWidth));
    canvas.drawParagraph(para, topLeft);
  }

  static String _range(RecipeEntry e) {
    String fmt(DateTime d) => '${_months[d.month - 1]} ${d.year}';
    if (e.start == null) return '';
    if (e.end == null || fmt(e.start!) == fmt(e.end!)) return fmt(e.start!);
    return '${fmt(e.start!)} – ${fmt(e.end!)}';
  }

  /// Average colour of a flag image (a few strides), darkened slightly for text.
  static Future<ui.Color> _dominantColour(ui.Image img) async {
    final data = (await img.toByteData())?.buffer.asUint8List();
    if (data == null) return _ink;
    var r = 0, g = 0, b = 0, n = 0;
    final total = img.width * img.height;
    final step = math.max(1, total ~/ 400);
    for (var i = 0; i < total; i += step) {
      final o = i * 4;
      if (data[o + 3] < 40) continue;
      r += data[o];
      g += data[o + 1];
      b += data[o + 2];
      n++;
    }
    if (n == 0) return _ink;
    // Darken toward ink so light flags stay legible on a light page.
    double mix(int v) => (v / n) * 0.82;
    return ui.Color.fromARGB(
        255, mix(r).round(), mix(g).round(), mix(b).round());
  }
}
