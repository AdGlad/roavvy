import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Displays a country flag visible only through the silhouette shape.
///
/// The silhouette SVG (black fill, fill-rule=evenodd) is used as an alpha mask
/// over the flag — flag is visible where the silhouette is opaque, transparent
/// where the silhouette has holes (internal detail areas).
///
/// Falls back to a plain flag if no silhouette asset exists.
class SilhouetteFlagWidget extends StatefulWidget {
  const SilhouetteFlagWidget({
    super.key,
    required this.isoCode,
    required this.silhouetteId,
    this.size = 200,
  });

  final String isoCode;
  final String silhouetteId;
  final double size;

  @override
  State<SilhouetteFlagWidget> createState() => _SilhouetteFlagWidgetState();
}

class _SilhouetteFlagWidgetState extends State<SilhouetteFlagWidget> {
  ui.Image? _flagImage;
  ui.Image? _silhouetteImage;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(SilhouetteFlagWidget old) {
    super.didUpdateWidget(old);
    if (old.isoCode != widget.isoCode || old.silhouetteId != widget.silhouetteId) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final size = widget.size;

    final flagPath = 'assets/flags/svg/${widget.isoCode.toLowerCase()}.svg';
    final silPath = 'assets/silhouettes/${widget.silhouetteId}.svg';

    final flagImg = await _svgToImage(flagPath, size);
    final silImg = await _svgToImage(silPath, size);

    if (mounted) {
      setState(() {
        _flagImage = flagImg;
        _silhouetteImage = silImg;
        _loading = false;
      });
    }
  }

  Future<ui.Image?> _svgToImage(String assetPath, double size) async {
    try {
      final loader = SvgAssetLoader(assetPath);
      final pictureInfo = await vg.loadPicture(loader, null);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final src = pictureInfo.size;
      final scale = src.width > 0 ? size / src.width : 1.0;
      canvas.scale(scale, scale);
      canvas.drawPicture(pictureInfo.picture);
      pictureInfo.picture.dispose();
      final picture = recorder.endRecording();
      final imgH = src.height > 0
          ? (size * src.height / src.width).round().clamp(1, 4096)
          : size.round();
      final image = await picture.toImage(size.round(), imgH);
      picture.dispose();
      return image;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    // Fallback: plain flag if either image failed to load
    if (_flagImage == null || _silhouetteImage == null) {
      return SvgPicture.asset(
        'assets/flags/svg/${widget.isoCode.toLowerCase()}.svg',
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
      );
    }

    return CustomPaint(
      size: Size(widget.size, widget.size),
      painter: _SilhouetteMaskPainter(
        flag: _flagImage!,
        silhouette: _silhouetteImage!,
      ),
    );
  }
}

class _SilhouetteMaskPainter extends CustomPainter {
  const _SilhouetteMaskPainter({required this.flag, required this.silhouette});

  final ui.Image flag;
  final ui.Image silhouette;

  @override
  void paint(Canvas canvas, Size size) {
    final dst = Offset.zero & size;

    // saveLayer so blendMode only composites within this layer
    canvas.saveLayer(dst, Paint());

    // Draw flag (cover-fit)
    _drawCover(canvas, flag, dst);

    // Silhouette as alpha mask: dstIn keeps flag pixels where silhouette is opaque
    _drawCover(canvas, silhouette, dst, blendMode: BlendMode.dstIn);

    canvas.restore();
  }

  void _drawCover(Canvas canvas, ui.Image image, Rect dst,
      {BlendMode blendMode = BlendMode.srcOver}) {
    final iw = image.width.toDouble();
    final ih = image.height.toDouble();
    if (iw <= 0 || ih <= 0) return;
    final scale = iw / ih > dst.width / dst.height
        ? dst.height / ih
        : dst.width / iw;
    final sw = dst.width / scale;
    final sh = dst.height / scale;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH((iw - sw) / 2, (ih - sh) / 2, sw, sh),
      dst,
      Paint()
        ..filterQuality = FilterQuality.high
        ..blendMode = blendMode,
    );
  }

  @override
  bool shouldRepaint(_SilhouetteMaskPainter old) =>
      old.flag != flag || old.silhouette != silhouette;
}
