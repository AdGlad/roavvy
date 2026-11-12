import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:flutter/material.dart';

import '../render_service.dart';
import 'torn_flag_io.dart';

/// Standalone review studio for the `portrait_torn_flag` recipe.
///
/// Every image on this screen comes from the shared engine through
/// [RenderService] — the same class and calls the mobile Studio uses — so what
/// is approved here is what the phone renders for the same preset, seed and
/// size. Nothing about the design lives in this widget: it only edits a
/// [TornStrips] value, a flag code and a seed.
class TornFlagScreen extends StatefulWidget {
  const TornFlagScreen({
    super.key,
    required this.service,
    required this.io,
    required this.codes,
    this.countryNames = const {},
  });

  final RenderService service;
  final TornFlagIO io;
  final List<String> codes;
  final Map<String, String> countryNames;

  @override
  State<TornFlagScreen> createState() => _TornFlagScreenState();
}

enum _View { single, variations, compare }

enum _Backdrop {
  white('White', Color(0xFFFFFFFF)),
  black('Black', Color(0xFF111111)),
  heather('Heather', Color(0xFF9EA3A8)),
  navy('Navy', Color(0xFF1F2A44)),
  transparent('Transparent', null);

  const _Backdrop(this.label, this.colour);
  final String label;
  final Color? colour;
}

class _TornFlagScreenState extends State<TornFlagScreen> {
  static const int _previewLongSide = 1100;
  static const int _variationLongSide = 640;
  static const int _variationCount = 6;

  String _code = 'us';
  int _seed = 1;
  TornStrips _params = const TornStrips();
  String _presetName = 'US Classic';
  String? _presetNotes;

  _View _view = _View.single;
  _Backdrop _backdrop = _Backdrop.white;

  ui.Image? _image;
  int _renderMs = 0;
  bool _busy = false;
  int _generation = 0;
  Timer? _debounce;

  final Map<int, ui.Image> _variations = {};
  int _variationGeneration = 0;

  late String _referencePath = widget.io.defaultReference.path;
  ui.Image? _reference;

  late final TextEditingController _seedField =
      TextEditingController(text: '$_seed');

  DesignRecipe _recipeFor(int seed) =>
      portraitTornFlagRecipe(flagCode: _code, seed: seed, params: _params);

  TornFlagPreset get _preset => TornFlagPreset(
      name: _presetName, notes: _presetNotes, recipe: _recipeFor(_seed));

  @override
  void initState() {
    super.initState();
    final presets = widget.io.listPresets();
    if (presets.isNotEmpty) {
      _apply(widget.io.loadPreset(presets.first), render: false);
    }
    _render();
    _loadReference();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _seedField.dispose();
    super.dispose();
  }

  // ---- rendering ----------------------------------------------------------

  void _changed() {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 40), _render);
  }

  Future<void> _render() async {
    final gen = ++_generation;
    setState(() => _busy = true);
    final sw = Stopwatch()..start();
    try {
      final img = await widget.service
          .imageFor(_recipeFor(_seed), _previewLongSide, transparent: true);
      if (!mounted || gen != _generation) return;
      setState(() {
        _image = img;
        _renderMs = sw.elapsedMilliseconds;
      });
    } catch (e) {
      if (mounted) _toast('Render failed: $e');
    } finally {
      if (mounted && gen == _generation) setState(() => _busy = false);
    }
    if (_view == _View.variations) _renderVariations();
  }

  Future<void> _renderVariations() async {
    final gen = ++_variationGeneration;
    final out = <int, ui.Image>{};
    for (var i = 0; i < _variationCount; i++) {
      final seed = _seed + i;
      final img = await widget.service
          .imageFor(_recipeFor(seed), _variationLongSide, transparent: true);
      if (!mounted || gen != _variationGeneration) return;
      out[seed] = img;
      setState(() => _variations
        ..clear()
        ..addAll(out));
    }
  }

  Future<void> _loadReference() async {
    final f = File(_referencePath);
    if (!f.existsSync()) {
      setState(() => _reference = null);
      return;
    }
    final codec = await ui.instantiateImageCodec(f.readAsBytesSync());
    final img = (await codec.getNextFrame()).image;
    if (mounted) setState(() => _reference = img);
  }

  // ---- presets ------------------------------------------------------------

  void _apply(TornFlagPreset p, {bool render = true}) {
    final r = p.recipe;
    _code = r.content.flags.isEmpty ? _code : r.content.flags.first.code;
    _seed = r.seed;
    _seedField.text = '$_seed';
    _params = r.tornStrips ?? const TornStrips();
    _presetName = p.name;
    _presetNotes = p.notes;
    if (render) _changed();
  }

  Future<void> _savePreset() async {
    final name = TextEditingController(text: _presetName);
    final notes = TextEditingController(text: _presetNotes ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save preset'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name')),
            TextField(
                controller: notes,
                decoration: const InputDecoration(labelText: 'Notes (optional)')),
            const SizedBox(height: 8),
            Text(
                'Saved as design_studio/recipes/portrait_torn_flag/'
                '${TornFlagIO.slug(name.text)}.preset.json — an existing '
                'preset with the same name is replaced.',
                style: const TextStyle(fontSize: 11)),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _presetName = name.text.trim().isEmpty ? 'Untitled' : name.text.trim();
      _presetNotes = notes.text.trim().isEmpty ? null : notes.text.trim();
    });
    final file = widget.io.savePreset(_preset);
    _toast('Saved ${file.path}', reveal: file.path);
  }

  // ---- exports ------------------------------------------------------------

  Future<void> _run(String label, Future<File> Function() job) async {
    _toast('$label…');
    try {
      final f = await job();
      _toast('$label → ${f.path}', reveal: f.path);
    } catch (e) {
      _toast('$label failed: $e');
    }
  }

  Future<void> _exportPrint() => _run(
      'Exporting ${TornFlagIO.printLongSide}px transparent PNG',
      () => widget.io.exportArtwork(widget.service, _preset));

  Future<void> _exportContactSheet() => _run(
        'Building contact sheet',
        () => widget.io.exportContactSheet(
          widget.service,
          [
            for (var i = 0; i < _variationCount; i++)
              TornFlagPreset(
                  name: _presetName, recipe: _recipeFor(_seed + i)),
          ],
          title: '${_presetName}_$_code',
          background: _backdrop.colour,
        ),
      );

  Future<void> _exportComparison() async {
    if (!File(_referencePath).existsSync()) {
      _toast('No reference image at $_referencePath');
      return;
    }
    await _run('Exporting comparison',
        () => widget.io.exportComparison(widget.service, _preset, File(_referencePath)));
  }

  Future<void> _openFullResolution() async {
    _toast('Rendering ${TornFlagIO.printLongSide}px…');
    final result = await widget.service
        .renderArtwork(_recipeFor(_seed), longSide: TornFlagIO.printLongSide);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _FullResolutionView(
        image: result.image,
        backdrop: _backdrop,
        title: '$_presetName · ${_code.toUpperCase()} · seed $_seed · '
            '${result.image.width}×${result.image.height}',
      ),
    ));
  }

  void _toast(String msg, {String? reveal}) {
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 6),
      action: reveal == null
          ? null
          : SnackBarAction(
              label: 'Show in Finder',
              onPressed: () => Process.run('open', ['-R', reveal])),
    ));
  }

  // ---- UI -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Torn Flag · $_presetName'),
        actions: [
          _presetMenu(),
          TextButton.icon(
              onPressed: _savePreset,
              icon: const Icon(Icons.save_outlined, size: 16),
              label: const Text('Save preset')),
          TextButton.icon(
              onPressed: _openFullResolution,
              icon: const Icon(Icons.zoom_in, size: 16),
              label: const Text('Full res')),
          TextButton.icon(
              onPressed: _exportPrint,
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Export PNG')),
          TextButton.icon(
              onPressed: _exportContactSheet,
              icon: const Icon(Icons.grid_view, size: 16),
              label: const Text('Contact sheet')),
          TextButton.icon(
              onPressed: _exportComparison,
              icon: const Icon(Icons.compare, size: 16),
              label: const Text('Export comparison')),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(children: [
        SizedBox(width: 340, child: _controls()),
        const VerticalDivider(width: 1),
        Expanded(child: _stage()),
      ]),
    );
  }

  Widget _presetMenu() => PopupMenuButton<File>(
        tooltip: 'Load preset',
        onSelected: (f) {
          try {
            _apply(widget.io.loadPreset(f));
          } catch (e) {
            _toast('Could not load ${f.path}: $e');
          }
        },
        itemBuilder: (_) {
          final files = widget.io.listPresets();
          if (files.isEmpty) {
            return [
              const PopupMenuItem(enabled: false, child: Text('No presets yet'))
            ];
          }
          return [
            for (final f in files)
              PopupMenuItem(value: f, child: Text(f.uri.pathSegments.last)),
          ];
        },
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            Icon(Icons.folder_open, size: 16),
            SizedBox(width: 6),
            Text('Load preset'),
          ]),
        ),
      );

  Widget _stage() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<_View>(
              segments: const [
                ButtonSegment(value: _View.single, label: Text('Design')),
                ButtonSegment(value: _View.variations, label: Text('Variations')),
                ButtonSegment(value: _View.compare, label: Text('Vs reference')),
              ],
              selected: {_view},
              onSelectionChanged: (s) {
                setState(() => _view = s.first);
                if (_view == _View.variations) _renderVariations();
              },
            ),
            SegmentedButton<_Backdrop>(
              segments: [
                for (final b in _Backdrop.values)
                  ButtonSegment(value: b, label: Text(b.label)),
              ],
              selected: {_backdrop},
              onSelectionChanged: (s) => setState(() => _backdrop = s.first),
            ),
            Text(
              _busy
                  ? 'Rendering…'
                  : '${_renderMs}ms · '
                      '${_recipeFor(_seed).recipeId.substring(0, 8)}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      Expanded(
        child: switch (_view) {
          _View.single => _artPanel(_image),
          _View.variations => _variationGrid(),
          _View.compare => _comparePanel(),
        },
      ),
    ]);
  }

  Widget _artPanel(ui.Image? image, {String? caption}) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Expanded(
            child: _Backdropped(
              backdrop: _backdrop,
              child: image == null
                  ? const Center(child: CircularProgressIndicator())
                  : RawImage(image: image, fit: BoxFit.contain),
            ),
          ),
          if (caption != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(caption, style: const TextStyle(fontSize: 12)),
            ),
        ]),
      );

  Widget _variationGrid() => LayoutBuilder(builder: (context, c) {
        const cols = 3;
        final cellW = (c.maxWidth - 32) / cols;
        final cellH = (c.maxHeight - 32) / 2;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(children: [
            for (var i = 0; i < _variationCount; i++)
              SizedBox(
                width: cellW,
                height: cellH,
                child: InkWell(
                  onTap: () {
                    _seed += i;
                    _seedField.text = '$_seed';
                    _view = _View.single;
                    _changed();
                  },
                  child: _artPanel(_variations[_seed + i],
                      caption: 'seed ${_seed + i}${i == 0 ? ' (current)' : ' — click to use'}'),
                ),
              ),
          ]),
        );
      });

  Widget _comparePanel() => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(children: [
            Expanded(
              child: TextFormField(
                initialValue: _referencePath,
                decoration: const InputDecoration(
                    isDense: true, labelText: 'Reference image path'),
                style: const TextStyle(fontSize: 12),
                onFieldSubmitted: (v) {
                  _referencePath = v.trim();
                  _loadReference();
                },
              ),
            ),
          ]),
        ),
        Expanded(
          child: Row(children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  Expanded(
                    child: _reference == null
                        ? const Center(child: Text('Reference image not found'))
                        : RawImage(image: _reference, fit: BoxFit.contain),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('Reference', style: TextStyle(fontSize: 12)),
                  ),
                ]),
              ),
            ),
            Expanded(child: _artPanel(_image, caption: 'Generated')),
          ]),
        ),
      ]);

  // ---- controls -----------------------------------------------------------

  Widget _controls() {
    final p = _params;
    void set(TornStrips next) {
      _params = next;
      _changed();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _flagPicker(),
        const SizedBox(height: 12),
        _seedRow(),
        _section('Cut lines', [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: TornStrips.cutsFromFlag,
                    label: Text('From flag'),
                    tooltip: 'Tear along the flag\'s own stripes; a flag '
                        'without lengthwise stripes frays at its end instead'),
                ButtonSegment(
                    value: TornStrips.cutsEven,
                    label: Text('Even'),
                    tooltip: 'Evenly spaced strips, ignoring the design'),
                ButtonSegment(
                    value: TornStrips.cutsFringe,
                    label: Text('Fringe'),
                    tooltip: 'Whole flag, frayed only at its end'),
              ],
              selected: {p.cutMode},
              onSelectionChanged: (sel) =>
                  set(p.copyWith(cutMode: sel.first)),
            ),
          ),
          if (p.cutMode == TornStrips.cutsEven)
            _slider('Strips', p.stripCount.toDouble(), 3, 24,
                (v) => set(p.copyWith(stripCount: v.round())),
                divisions: 21, digits: 0),
          if (p.cutMode == TornStrips.cutsFringe)
            _slider('Tongues', p.fringeCount.toDouble(), 2, 24,
                (v) => set(p.copyWith(fringeCount: v.round())),
                divisions: 22, digits: 0),
          _slider('Fringe depth', p.fringeDepth, 0.05, 0.8,
              (v) => set(p.copyWith(fringeDepth: v))),
          _slider('Spacing jitter', p.spacingJitter, 0, 1,
              (v) => set(p.copyWith(spacingJitter: v))),
        ]),
        _section('Layout', [
          _slider('Gap', p.gap, 0, 0.8, (v) => set(p.copyWith(gap: v))),
          _slider('Margin', p.margin, 0, 0.25, (v) => set(p.copyWith(margin: v))),
          _toggle('Official proportions (where available)',
              p.flagVariant == 'official',
              (v) => set(p.copyWith(flagVariant: v ? 'official' : ''))),
          _slider('Flag aspect (0 = artwork)', p.flagAspect, 0, 2.2,
              (v) => set(p.copyWith(flagAspect: v < 0.6 ? 0 : v))),
          _toggle('Rotate clockwise', p.rotateClockwise,
              (v) => set(p.copyWith(rotateClockwise: v))),
          _toggle('Mirror (canton left)', p.mirror,
              (v) => set(p.copyWith(mirror: v))),
        ]),
        _section('Strips', [
          _slider('Tear drift', p.widthWobble, 0, 1,
              (v) => set(p.copyWith(widthWobble: v))),
          _slider('Curvature', p.curvature, 0, 1,
              (v) => set(p.copyWith(curvature: v))),
          _slider('Waviness', p.waviness, 0, 1,
              (v) => set(p.copyWith(waviness: v))),
          _slider('Sway together', p.swayCoherence, 0, 1,
              (v) => set(p.copyWith(swayCoherence: v))),
          _slider('Edge roughness', p.edgeRoughness, 0, 1,
              (v) => set(p.copyWith(edgeRoughness: v))),
        ]),
        _section('Tears', [
          _slider('Tear length', p.tearLength, 0, 0.9,
              (v) => set(p.copyWith(tearLength: v))),
          _slider('Point', p.tearPoint, 0, 1,
              (v) => set(p.copyWith(tearPoint: v))),
          _slider('Jaggedness', p.tearJag, 0, 1,
              (v) => set(p.copyWith(tearJag: v))),
          _slider('Top variation', p.topVariation, 0, 0.6,
              (v) => set(p.copyWith(topVariation: v))),
          _slider('Break chance', p.breakChance, 0, 1,
              (v) => set(p.copyWith(breakChance: v))),
        ]),
        _section('Intact block (canton)', [
          _slider('Width', p.blockWidth, 0, 1,
              (v) => set(p.copyWith(blockWidth: v))),
          _slider('Height', p.blockHeight, 0, 0.9,
              (v) => set(p.copyWith(blockHeight: v))),
          _slider('Top tear', p.blockTear, 0, 1,
              (v) => set(p.copyWith(blockTear: v))),
        ]),
        _section('Distress', [
          _slider('Amount', p.distress, 0, 1,
              (v) => set(p.copyWith(distress: v))),
          _slider('Speckle size', p.distressScale, 0, 1,
              (v) => set(p.copyWith(distressScale: v))),
          _slider('Edge wear', p.edgeWear, 0, 1,
              (v) => set(p.copyWith(edgeWear: v))),
        ]),
        _section('Colour', [
          _slider('Saturation', p.saturation, 0, 1.5,
              (v) => set(p.copyWith(saturation: v))),
          _slider('Hue shift °', p.hueShift, -30, 30,
              (v) => set(p.copyWith(hueShift: v)), digits: 0),
          _slider('Brightness', p.brightness, -0.5, 0.5,
              (v) => set(p.copyWith(brightness: v))),
          _slider('Vintage', p.vintage, 0, 1, (v) => set(p.copyWith(vintage: v))),
          _toggle('Knock out white', p.knockoutWhite,
              (v) => set(p.copyWith(knockoutWhite: v))),
        ]),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => set(const TornStrips()),
          icon: const Icon(Icons.restart_alt, size: 16),
          label: const Text('Reset parameters to defaults'),
        ),
      ],
    );
  }

  Widget _flagPicker() {
    String label(String c) {
      final n = widget.countryNames[c.toUpperCase()] ?? widget.countryNames[c];
      return n == null ? c.toUpperCase() : '${c.toUpperCase()} — $n';
    }

    return DropdownMenu<String>(
      initialSelection: _code,
      label: const Text('Flag'),
      width: 308,
      enableFilter: true,
      requestFocusOnTap: true,
      menuHeight: 420,
      dropdownMenuEntries: [
        for (final c in widget.codes) DropdownMenuEntry(value: c, label: label(c)),
      ],
      onSelected: (c) {
        if (c == null) return;
        _code = c;
        _changed();
      },
    );
  }

  Widget _seedRow() => Row(children: [
        const Text('Seed'),
        const SizedBox(width: 12),
        IconButton(
            tooltip: 'Previous seed',
            onPressed: () => _setSeed(_seed - 1),
            icon: const Icon(Icons.chevron_left)),
        SizedBox(
          width: 90,
          child: TextField(
            controller: _seedField,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(isDense: true),
            onSubmitted: (v) => _setSeed(int.tryParse(v.trim()) ?? _seed),
          ),
        ),
        IconButton(
            tooltip: 'Next seed',
            onPressed: () => _setSeed(_seed + 1),
            icon: const Icon(Icons.chevron_right)),
        IconButton(
            tooltip: 'Random seed',
            onPressed: () => _setSeed(
                DateTime.now().microsecondsSinceEpoch % 1000000),
            icon: const Icon(Icons.casino_outlined)),
      ]);

  void _setSeed(int s) {
    _seed = s;
    _seedField.text = '$s';
    _changed();
  }

  Widget _section(String title, List<Widget> children) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            ...children,
          ],
        ),
      );

  Widget _slider(String label, double value, double min, double max,
      ValueChanged<double> onChanged,
      {int? divisions, int digits = 2}) {
    return Row(children: [
      SizedBox(
          width: 118, child: Text(label, style: const TextStyle(fontSize: 12))),
      Expanded(
        child: Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ),
      SizedBox(
        width: 38,
        child: Text(value.toStringAsFixed(digits),
            textAlign: TextAlign.right, style: const TextStyle(fontSize: 12)),
      ),
    ]);
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) =>
      SwitchListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(label, style: const TextStyle(fontSize: 12)),
        value: value,
        onChanged: onChanged,
      );
}

/// Paints [backdrop] (or a checkerboard for transparent) behind [child].
class _Backdropped extends StatelessWidget {
  const _Backdropped({required this.backdrop, required this.child});

  final _Backdrop backdrop;
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRect(
        child: CustomPaint(
          painter: _BackdropPainter(backdrop.colour),
          child: SizedBox.expand(child: child),
        ),
      );
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.colour);

  final Color? colour;

  @override
  void paint(Canvas canvas, Size size) {
    if (colour != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = colour!);
      return;
    }
    const cell = 12.0;
    final light = Paint()..color = const Color(0xFFEDEDED);
    final dark = Paint()..color = const Color(0xFFCFCFCF);
    for (var y = 0.0; y < size.height; y += cell) {
      for (var x = 0.0; x < size.width; x += cell) {
        final odd = ((x / cell).floor() + (y / cell).floor()).isOdd;
        canvas.drawRect(
            Rect.fromLTWH(x, y, cell, cell), odd ? dark : light);
      }
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => old.colour != colour;
}

/// The print-resolution render, pannable and zoomable to 1:1 pixels.
class _FullResolutionView extends StatelessWidget {
  const _FullResolutionView(
      {required this.image, required this.backdrop, required this.title});

  final ui.Image image;
  final _Backdrop backdrop;
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title, style: const TextStyle(fontSize: 14))),
        body: _Backdropped(
          backdrop: backdrop,
          child: InteractiveViewer(
            constrained: false,
            minScale: 0.05,
            maxScale: 4,
            child: SizedBox(
              width: image.width.toDouble(),
              height: image.height.toDouble(),
              child: RawImage(image: image),
            ),
          ),
        ),
      );
}
