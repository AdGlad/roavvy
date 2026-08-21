import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:flutter/material.dart';

import 'flag_source.dart';
import 'lab_generator.dart';
import 'lab_styles.dart';
import 'recipe_editor.dart';
import 'render_service.dart';

void main() => runApp(const DesignLabApp());

class DesignLabApp extends StatelessWidget {
  const DesignLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Roavvy Design Lab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0E0F12),
      ),
      home: const LabHome(),
    );
  }
}

class LabHome extends StatefulWidget {
  const LabHome({super.key});
  @override
  State<LabHome> createState() => _LabHomeState();
}

class _LabHomeState extends State<LabHome> {
  // Rebuilt when the style changes or once silhouette/continent assets are
  // indexed (see _boot) so the rotation can offer the country's own silhouettes.
  LabStyle _style = LabStyle.showcase;
  LabShowcaseGenerator _generator = const LabShowcaseGenerator();

  FlagSource? _source;
  RenderService? _service;
  List<String> _allCodes = [];
  Map<ClipShape, List<String>> _silhouettesByShape = {};
  List<String> _continents = [];
  Map<String, String> _countryNames = const {};
  final Set<String> _selectedFlags = {'us', 'gb'};
  String _flagQuery = '';

  int _baseSeed = 1;
  int _count = 48;

  List<DesignRecipe> _recipes = [];
  final Set<String> _favourites = {};
  DesignRecipe? _inspected;

  String _status = 'Locating flag assets…';

  @override
  void initState() {
    super.initState();
    _boot();
  }

  void _boot() {
    final source = FlagSource.locate();
    if (source == null) {
      setState(() => _status =
          'Could not find flag SVGs. Expected apps/mobile_flutter/assets/flags/svg.');
      return;
    }
    _source = source;
    _service = RenderService(source.resolver());
    _allCodes = source.codes();
    final byKind = source.silhouettesByKind();
    _silhouettesByShape = {
      ClipShape.animalSilhouette: byKind['animal'] ?? const [],
      ClipShape.plantSilhouette: byKind['plant'] ?? const [],
      ClipShape.landmarkSilhouette: byKind['landmark'] ?? const [],
    };
    _continents = source.continents();
    _countryNames = source.countryNames();
    _rebuildGenerator();
    _loadFavourites();
    setState(() => _status = '${_allCodes.length} flags loaded');
    _generate();
  }

  void _rebuildGenerator() {
    _generator = LabShowcaseGenerator(
      style: _style,
      silhouettesByShape: _silhouettesByShape,
      continents: _continents,
      countryNames: _countryNames,
    );
  }

  File get _favFile => File('${_source!.labOutputDir.path}/favourites.json');

  void _loadFavourites() {
    try {
      if (_favFile.existsSync()) {
        final list = jsonDecode(_favFile.readAsStringSync()) as List;
        _favourites.addAll(list.cast<String>());
      }
    } catch (_) {/* ignore */}
  }

  void _saveFavourites() {
    try {
      _favFile.writeAsStringSync(jsonEncode(_favourites.toList()));
    } catch (_) {/* ignore */}
  }

  DesignContext get _context => DesignContext(
        flagCodes: _selectedFlags.isEmpty ? ['us'] : _selectedFlags.toList(),
        scopeKey: 'lab:${_selectedFlags.join("+")}',
      );

  void _generate() {
    setState(() {
      _recipes = _generator.generate(_context, seed: _baseSeed, count: _count);
      _inspected = null;
      _status = 'Generated ${_recipes.length} designs (seed $_baseSeed)';
    });
  }

  void _variationsOf(DesignRecipe r) {
    // "More like this": same flags, seeds around the parent seed.
    final ctx = DesignContext(
      flagCodes: r.content.flags.map((f) => f.code).toList(),
      scopeKey: r.content.source,
    );
    setState(() {
      _recipes = _generator.generate(ctx, seed: r.seed, count: _count);
      _inspected = null;
      _status = 'Variations of ${r.recipeId}';
    });
  }

  Future<void> _reproduce(String seedText) async {
    final seed = int.tryParse(seedText.trim());
    if (seed == null) return;
    final r = _generator.generate(_context, seed: seed, count: 1).first;
    setState(() {
      _inspected = r;
      _status = 'Reproduced seed $seed → ${r.recipeId}';
    });
  }

  Future<void> _exportPng(DesignRecipe r) async {
    final res = await _service!.renderFull(r, 1600);
    final file = File('${_source!.labOutputDir.path}/${r.recipeId}.png');
    await file.writeAsBytes(res.pngBytes);
    _toast('Exported ${file.path}');
  }

  Future<void> _exportContactSheet() async {
    _toast('Building contact sheet…');
    final sheet = await const ContactSheetBuilder(columns: 6, cell: 240)
        .build(_recipes, _service!.renderer);
    final file = File(
        '${_source!.labOutputDir.path}/contact_sheet_seed${_baseSeed}_${_recipes.length}.png');
    await file.writeAsBytes(sheet);
    _toast('Contact sheet: ${file.path}');
  }

  void _toast(String msg) {
    setState(() => _status = msg);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));
  }

  @override
  Widget build(BuildContext context) {
    if (_service == null) {
      return Scaffold(body: Center(child: Text(_status)));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Roavvy Design Lab'),
        backgroundColor: const Color(0xFF16181D),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(child: Text(_status, style: const TextStyle(fontSize: 12))),
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _leftPanel(),
          const VerticalDivider(width: 1),
          Expanded(child: _gallery()),
          if (_inspected != null) ...[
            const VerticalDivider(width: 1),
            RecipeEditorPanel(
              recipe: _inspected!,
              service: _service!,
              silhouettesByShape: _silhouettesByShape,
              continents: _continents,
              countryNames: _countryNames,
              onExportPng: _exportPng,
              onVariations: _variationsOf,
              onClose: () => setState(() => _inspected = null),
            ),
          ],
        ],
      ),
    );
  }

  // ---- Left panel: flag selection + controls ----
  Widget _leftPanel() {
    final filtered = _flagQuery.isEmpty
        ? _allCodes
        : _allCodes.where((c) => c.contains(_flagQuery)).toList();
    return SizedBox(
      width: 280,
      child: Container(
        color: const Color(0xFF16181D),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('FLAGS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final c in _selectedFlags)
                  Chip(
                    label: Text(c.toUpperCase()),
                    onDeleted: () => setState(() => _selectedFlags.remove(c)),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'search code (e.g. jp)…',
                prefixIcon: Icon(Icons.search, size: 18),
              ),
              onChanged: (v) => setState(() => _flagQuery = v.toLowerCase().trim()),
            ),
            const SizedBox(height: 6),
            Expanded(
              flex: 3,
              child: ListView(
                children: [
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final c in filtered.take(200))
                        FilterChip(
                          label: Text(c.toUpperCase(), style: const TextStyle(fontSize: 11)),
                          selected: _selectedFlags.contains(c),
                          visualDensity: VisualDensity.compact,
                          onSelected: (s) => setState(() {
                            if (s) {
                              _selectedFlags.add(c);
                            } else {
                              _selectedFlags.remove(c);
                            }
                          }),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(),
            Row(
              children: [
                const Text('Style '),
                Expanded(
                  child: DropdownButton<LabStyle>(
                    isExpanded: true,
                    isDense: true,
                    value: _style,
                    items: [
                      for (final s in LabStyle.values)
                        DropdownMenuItem(value: s, child: Text(s.label)),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _style = v;
                        _rebuildGenerator();
                      });
                      _generate();
                    },
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const Text('Seed '),
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: '$_baseSeed'),
                    decoration: const InputDecoration(isDense: true),
                    keyboardType: TextInputType.number,
                    onSubmitted: (v) => _baseSeed = int.tryParse(v) ?? _baseSeed,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const Text('Count '),
                Expanded(
                  child: Slider(
                    value: _count.toDouble(),
                    min: 6,
                    max: 240,
                    divisions: 39,
                    label: '$_count',
                    onChanged: (v) => setState(() => _count = v.round()),
                  ),
                ),
                Text('$_count'),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                FilledButton.icon(
                  onPressed: _generate,
                  icon: const Icon(Icons.grid_view, size: 16),
                  label: const Text('Generate'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _baseSeed += _count);
                    _generate();
                  },
                  icon: const Icon(Icons.casino, size: 16),
                  label: const Text('Next batch'),
                ),
                OutlinedButton.icon(
                  onPressed: _exportContactSheet,
                  icon: const Icon(Icons.dashboard, size: 16),
                  label: const Text('Contact sheet'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Reproduce from seed',
                suffixIcon: Icon(Icons.replay, size: 18),
              ),
              keyboardType: TextInputType.number,
              onSubmitted: _reproduce,
            ),
          ],
        ),
      ),
    );
  }

  // ---- Center: gallery ----
  Widget _gallery() {
    if (_recipes.isEmpty) {
      return const Center(child: Text('Select flags and press Generate'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 1,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _recipes.length,
      itemBuilder: (context, i) {
        final r = _recipes[i];
        final fav = _favourites.contains(r.recipeId);
        final isSel = _inspected?.recipeId == r.recipeId;
        return GestureDetector(
          onTap: () => setState(() => _inspected = r),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSel ? Colors.tealAccent : const Color(0xFF2A2D33),
                    width: isSel ? 2 : 1,
                  ),
                  color: const Color(0xFFF2F2F2),
                ),
                child: _RecipeTile(service: _service!, recipe: r, size: 200),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: IconButton(
                  iconSize: 18,
                  icon: Icon(fav ? Icons.star : Icons.star_border,
                      color: fav ? Colors.amber : Colors.white70),
                  onPressed: () => setState(() {
                    if (fav) {
                      _favourites.remove(r.recipeId);
                    } else {
                      _favourites.add(r.recipeId);
                    }
                    _saveFavourites();
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

}

/// A gallery tile that renders its recipe once (cached in [RenderService]).
class _RecipeTile extends StatefulWidget {
  const _RecipeTile({required this.service, required this.recipe, required this.size});
  final RenderService service;
  final DesignRecipe recipe;
  final int size;

  @override
  State<_RecipeTile> createState() => _RecipeTileState();
}

class _RecipeTileState extends State<_RecipeTile> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _RecipeTile old) {
    super.didUpdateWidget(old);
    if (old.recipe.recipeId != widget.recipe.recipeId) _load();
  }

  Future<void> _load() async {
    final img = await widget.service.imageFor(widget.recipe, widget.size);
    if (mounted) setState(() => _image = img);
  }

  @override
  Widget build(BuildContext context) {
    final img = _image;
    if (img == null) {
      return const Center(
          child: SizedBox(
              width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
    }
    return RawImage(image: img, fit: BoxFit.contain);
  }
}
