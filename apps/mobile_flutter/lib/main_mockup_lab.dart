// Dev harness (M174): the interactive t-shirt mockup canvas on its own.
//
//   flutter run -d macos -t lib/main_mockup_lab.dart
//
// The real mockup screen sits behind a scan → card → design → order flow that
// needs photo-library data, which macOS has no PhotoKit bridge for. This
// entrypoint skips all of it and drops straight onto the canvas with a bundled
// garment and a synthetic design, so the fabric shading, the gestures, the
// clipping and the HUD can be judged directly.
//
// Not shipped: nothing in `lib/` imports this, and it is not referenced by any
// build config — it exists purely to look at the thing.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'features/merch/local_mockup_image_cache.dart';
import 'features/merch/merch_variant_lookup.dart';
import 'features/merch/mockup_transform_controller.dart';
import 'features/merch/product_mockup_specs.dart';
import 'features/merch/tshirt_mockup_canvas.dart';

void main() => runApp(const MockupLabApp());

class MockupLabApp extends StatelessWidget {
  const MockupLabApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Roavvy Mockup Lab (M174)',
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(
      useMaterial3: true,
    ).copyWith(scaffoldBackgroundColor: const Color(0xFF0E0F12)),
    home: const _MockupLab(),
  );
}

class _MockupLab extends StatefulWidget {
  const _MockupLab();

  @override
  State<_MockupLab> createState() => _MockupLabState();
}

class _MockupLabState extends State<_MockupLab> {
  final _controller = MockupTransformController();

  String _colour = 'White';
  String _placement = 'front';
  String _frontPosition = 'center';
  ImageSize _imageSize = ImageSize.medium;
  double _shadingOpacity = 0.4;
  bool _transparentArtwork = true;
  bool _debugPrintArea = false;
  bool _interactive = true;

  ui.Image? _garment;
  ui.Image? _shading;
  ui.Image? _artwork;
  MockupTransform _live = MockupTransform.identity;

  static const _colours = ['White', 'Black', 'Blue', 'Grey', 'Red'];

  ProductMockupSpec get _spec => ProductMockupSpecs.specsFor(
    MerchProduct.tshirt,
    colour: _colour,
    placement: _placement,
    frontPosition: _frontPosition,
    imageSize: _imageSize,
  );

  @override
  void initState() {
    super.initState();
    _controller.transform.addListener(
      () => setState(() => _live = _controller.value),
    );
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _artwork?.dispose();
    LocalMockupImageCache.instance.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final (garment, shading) = await LocalMockupImageCache.instance
        .loadWithShading(_spec);
    final artwork = await _buildArtwork(_transparentArtwork);
    if (!mounted) return;
    setState(() {
      _garment = garment;
      _shading = shading;
      _artwork?.dispose();
      _artwork = artwork;
    });
  }

  /// A stand-in design. [transparent] leaves a wide transparent margin and
  /// hollow counters — the shape that exposes the "grey box" failure if the
  /// fabric shading is not masked to the artwork's own alpha.
  Future<ui.Image> _buildArtwork(bool transparent) async {
    const size = 900.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    if (!transparent) {
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, size, size),
        ui.Paint()..color = const ui.Color(0xFFFFFFFF),
      );
    }

    final ink = Paint()..color = const ui.Color(0xFF1B1F24);
    // A ring + bars: plenty of edges and holes to judge fold shading against.
    canvas.drawCircle(
      const ui.Offset(size / 2, size * 0.38),
      size * 0.20,
      Paint()
        ..color = ink.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.045,
    );
    for (var i = 0; i < 3; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size * 0.22,
            size * (0.62 + i * 0.09),
            size * 0.56,
            size * 0.055,
          ),
          Radius.circular(size * 0.03),
        ),
        ink,
      );
    }

    final para =
        (ui.ParagraphBuilder(
                ui.ParagraphStyle(
                  textAlign: TextAlign.center,
                  fontSize: size * 0.09,
                  fontWeight: FontWeight.w900,
                ),
              )
              ..pushStyle(ui.TextStyle(color: ink.color, letterSpacing: 4))
              ..addText('ROAVVY'))
            .build()
          ..layout(const ui.ParagraphConstraints(width: size));
    canvas.drawParagraph(para, const ui.Offset(0, size * 0.44));

    return recorder.endRecording().toImage(size.round(), size.round());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mockup Lab — M174'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'x ${_live.translation.dx.toStringAsFixed(2)}  '
                'y ${_live.translation.dy.toStringAsFixed(2)}  '
                '${_live.scale.toStringAsFixed(2)}×  '
                '${_controller.rotationDegrees}°',
                style: const TextStyle(
                  fontFeatures: [ui.FontFeature.tabularFigures()],
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 800 / 1066,
                child:
                    _garment == null
                        ? const Center(child: CircularProgressIndicator())
                        : TshirtMockupCanvas(
                          spec: _spec,
                          controller: _controller,
                          garmentImage: _garment,
                          shadingImage: _shading,
                          artworkImage: _artwork,
                          artworkBlendMode:
                              _transparentArtwork
                                  ? ui.BlendMode.srcOver
                                  : ui.BlendMode.multiply,
                          shadingOpacity: _shadingOpacity,
                          interactive: _interactive,
                          debugPrintArea: _debugPrintArea,
                        ),
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          SizedBox(width: 260, child: _controls()),
        ],
      ),
    );
  }

  Widget _controls() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const _Label('Garment colour'),
      Wrap(
        spacing: 6,
        children: [
          for (final c in _colours)
            ChoiceChip(
              label: Text(c),
              selected: _colour == c,
              onSelected: (_) {
                setState(() => _colour = c);
                _load();
              },
            ),
        ],
      ),
      const SizedBox(height: 16),
      const _Label('Face'),
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'front', label: Text('Front')),
          ButtonSegment(value: 'back', label: Text('Back')),
        ],
        selected: {_placement},
        onSelectionChanged: (s) {
          setState(() => _placement = s.first);
          _load();
        },
      ),
      if (_placement == 'front') ...[
        const SizedBox(height: 16),
        const _Label('Front position'),
        Wrap(
          spacing: 6,
          children: [
            for (final p in const ['left_chest', 'center', 'right_chest'])
              ChoiceChip(
                label: Text(p.replaceAll('_', ' ')),
                selected: _frontPosition == p,
                onSelected: (_) => setState(() => _frontPosition = p),
              ),
          ],
        ),
      ],
      const SizedBox(height: 16),
      const _Label('Image size'),
      Wrap(
        spacing: 6,
        children: [
          for (final s in ImageSize.values)
            ChoiceChip(
              label: Text(s.name),
              selected: _imageSize == s,
              onSelected: (_) => setState(() => _imageSize = s),
            ),
        ],
      ),
      const SizedBox(height: 16),
      _Label('Fabric shading  ${_shadingOpacity.toStringAsFixed(2)}'),
      Slider(
        value: _shadingOpacity,
        max: 1.0,
        divisions: 20,
        onChanged: (v) => setState(() => _shadingOpacity = v),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text(
          'Transparent artwork',
          style: TextStyle(fontSize: 13),
        ),
        subtitle: const Text(
          'srcOver + alpha-masked shading',
          style: TextStyle(fontSize: 11),
        ),
        value: _transparentArtwork,
        onChanged: (v) {
          setState(() => _transparentArtwork = v);
          _load();
        },
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Interactive', style: TextStyle(fontSize: 13)),
        value: _interactive,
        onChanged: (v) => setState(() => _interactive = v),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Show print area', style: TextStyle(fontSize: 13)),
        value: _debugPrintArea,
        onChanged: (v) => setState(() => _debugPrintArea = v),
      ),
      const Divider(height: 32),
      const Text(
        'Drag to move. Trackpad pinch to scale, two-finger rotate to turn.\n\n'
        'Check: folds darken the ink, the shirt stays clean around it, and the '
        'design never crosses the print area (turn the outline on).',
        style: TextStyle(fontSize: 11, color: Colors.white54, height: 1.5),
      ),
    ],
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.white70,
      ),
    ),
  );
}
