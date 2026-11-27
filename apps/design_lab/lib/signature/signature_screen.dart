import 'dart:async';
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:flutter/material.dart' hide Orientation;

import '../render_service.dart';
import 'signature_edit.dart';
import 'signature_io.dart';
import 'signature_sweep.dart';

/// The Signature Workbench (M191, ADR-181): tune one Signature Recipe against
/// every country at once, fix weak countries, and approve it.
///
/// Left: the recipe's parameters (base value + whether variations may vary
/// it). Centre: every country's hero with a QA dot. Right: the selected
/// country — large render on the orderable garments, QA detail, its first
/// variations, hero choice and per-country override.
class SignatureScreen extends StatefulWidget {
  const SignatureScreen({
    super.key,
    required this.service,
    required this.io,
    required this.codes,
    this.countryNames = const {},
    this.initialPack,
    this.sweepLongSide = SignatureSweep.defaultLongSide,
  });

  final RenderService service;
  final SignatureIO io;
  final List<String> codes;
  final Map<String, String> countryNames;
  final String? initialPack;
  final int sweepLongSide;

  @override
  State<SignatureScreen> createState() => SignatureScreenState();
}

enum _Filter { all, warnings, failures }

@visibleForTesting
class SignatureScreenState extends State<SignatureScreen> {
  static const int _inspectorLongSide = 600;
  static const int _variationCount = 12;

  late final SignatureSweep _sweep =
      SignatureSweep(widget.service, longSide: widget.sweepLongSide);

  List<String> _ids = const [];
  SignatureRecipe? _pack;
  bool _dirty = false;
  final List<SignatureRecipe> _undo = [];
  final List<SignatureRecipe> _redo = [];

  final Map<String, SweepCell> _cells = {};
  int _sweepGen = 0;
  int _pending = 0;

  _Filter _filter = _Filter.all;
  String _query = '';
  int _garment = 2; // Dark Heather: shows both light and dark ink

  String? _selected;
  ui.Image? _inspectorImage;
  final Map<int, SweepCell> _variations = {};
  int _inspectorGen = 0;

  @visibleForTesting
  SignatureRecipe? get pack => _pack;
  @visibleForTesting
  Map<String, SweepCell> get cells => _cells;
  @visibleForTesting
  bool get isSweeping => _pending > 0;

  @override
  void initState() {
    super.initState();
    _ids = widget.io.listIds();
    final id = widget.initialPack ?? (_ids.isEmpty ? null : _ids.first);
    if (id != null) _open(id);
  }

  // ---- pack state ----------------------------------------------------------

  void _open(String id) {
    try {
      final p = widget.io.load(id);
      setState(() {
        _pack = p;
        _dirty = false;
        _undo.clear();
        _redo.clear();
        _cells.clear();
        _selected = null;
      });
      _resweep();
    } on FormatException catch (e) {
      _toast('Cannot open $id: ${e.message}');
    }
  }

  /// Applies an edit; an invalid one is refused with a message.
  void _apply(SignatureRecipe Function(SignatureRecipe) edit) {
    final current = _pack;
    if (current == null) return;
    final SignatureRecipe next;
    try {
      next = edit(current);
    } on FormatException catch (e) {
      _toast(e.message);
      return;
    } on RecipePathError catch (e) {
      _toast('$e');
      return;
    }
    setState(() {
      _undo.add(current);
      _redo.clear();
      _pack = next;
      _dirty = true;
    });
    _resweep();
  }

  void _undoEdit() {
    if (_undo.isEmpty) return;
    setState(() {
      _redo.add(_pack!);
      _pack = _undo.removeLast();
      _dirty = true;
    });
    _resweep();
  }

  void _redoEdit() {
    if (_redo.isEmpty) return;
    setState(() {
      _undo.add(_pack!);
      _pack = _redo.removeLast();
      _dirty = true;
    });
    _resweep();
  }

  void _save() {
    final p = _pack;
    if (p == null) return;
    final f = widget.io.save(p);
    setState(() => _dirty = false);
    _toast('Saved ${f.path.split('/').last}');
  }

  // ---- rendering -----------------------------------------------------------

  /// Re-renders only the countries whose hero changed (a base edit changes
  /// all of them; an override or hero edit changes one).
  Future<void> _resweep() async {
    final p = _pack;
    if (p == null) return;
    final gen = ++_sweepGen;
    final todo = <String>[];
    for (final cc in widget.codes) {
      final old = _cells[cc];
      final DesignRecipe hero;
      try {
        hero = SignatureResolver.hero(p, cc);
      } catch (_) {
        todo.add(cc);
        continue;
      }
      if (old == null || old.recipe.recipeId != hero.recipeId) todo.add(cc);
    }
    if (_selected != null) _inspect(_selected!);
    setState(() => _pending = todo.length);
    for (final cc in todo) {
      final cell = await _sweep.cell(p, cc, 0);
      if (!mounted || gen != _sweepGen) return;
      setState(() {
        _cells[cc] = cell;
        _pending--;
      });
    }
  }

  Future<void> _inspect(String cc) async {
    final p = _pack!;
    final gen = ++_inspectorGen;
    setState(() {
      _selected = cc;
      _inspectorImage = null;
      _variations.clear();
    });
    try {
      final img = await widget.service.imageFor(
          SignatureResolver.hero(p, cc), _inspectorLongSide,
          transparent: true);
      if (!mounted || gen != _inspectorGen) return;
      setState(() => _inspectorImage = img);
    } catch (e) {
      if (mounted) _toast('Render failed: $e');
    }
    if (p.envelope.isEmpty) return;
    for (var i = 1; i <= _variationCount; i++) {
      final cell = await _sweep.cell(p, cc, i);
      if (!mounted || gen != _inspectorGen) return;
      setState(() => _variations[i] = cell);
    }
  }

  // ---- approval + review ---------------------------------------------------

  Future<void> _exportReview() async {
    final p = _pack;
    if (p == null) return;
    final heroes = [for (final cc in widget.codes) if (_cells[cc] != null) _cells[cc]!];
    final label = 'review-${SignatureIO.timestamp()}';
    final sheet = await SignatureSweep.contactSheet(heroes, names: widget.countryNames);
    final (png, _) = widget.io.writeReview(p.id, label,
        sheetPng: sheet, report: SignatureSweep.report(p, heroes, label: label));
    _toast('Wrote ${png.parent.path}');
  }

  Future<void> _approve() async {
    final p = _pack;
    if (p == null) return;
    final locksField = TextEditingController(
        text: (p.locks.keys.isNotEmpty
                ? ({...SignatureSweep.defaultLockCountries, ...p.locks.keys})
                : SignatureSweep.defaultLockCountries)
            .join(', '));
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Approve ${p.title} v${p.version}?'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Checks every country\'s hero and its first '
                  '${SignatureSweep.approvalVariations} variations '
                  '(${widget.codes.length * (SignatureSweep.approvalVariations + 1)} renders, '
                  'several minutes). Any hard failure blocks approval.'),
              const SizedBox(height: 12),
              TextField(
                controller: locksField,
                decoration: const InputDecoration(
                    labelText: 'Lock countries (goldens)', isDense: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Check & approve')),
        ],
      ),
    );
    if (go != true || !mounted) return;
    final lockCountries = [
      for (final s in locksField.text.split(','))
        if (s.trim().isNotEmpty) s.trim().toLowerCase(),
    ];
    final unknown = lockCountries.where((c) => !widget.codes.contains(c)).toList();
    if (unknown.isNotEmpty || lockCountries.isEmpty) {
      _toast(lockCountries.isEmpty
          ? 'Name at least one lock country'
          : 'Unknown lock countries: ${unknown.join(', ')}');
      return;
    }

    final progress = ValueNotifier<(int, int)>((0, 0));
    var cancelled = false;
    final total = widget.codes.length * (SignatureSweep.approvalVariations + 1);
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Checking every country…'),
        content: ValueListenableBuilder<(int, int)>(
          valueListenable: progress,
          builder: (_, v, _) => Column(mainAxisSize: MainAxisSize.min, children: [
            LinearProgressIndicator(value: v.$1 / total),
            const SizedBox(height: 8),
            Text('${v.$1} / $total · ${v.$2} hard failures'),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () {
                cancelled = true;
                Navigator.pop(ctx);
              },
              child: const Text('Cancel')),
        ],
      ),
    ));
    final cells = <SweepCell>[];
    var fails = 0;
    await for (final c in _sweep.run(p, widget.codes,
        variations: SignatureSweep.approvalVariations,
        keepImages: false,
        cancelled: () => cancelled)) {
      cells.add(c);
      if (c.report.status == QaStatus.fail) fails++;
      progress.value = (cells.length, fails);
    }
    if (!mounted || cancelled) return;
    Navigator.of(context).pop();

    final blockers = SignatureSweep.blockers(cells);
    if (blockers.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Not approved: ${blockers.length} hard failures'),
          content: SizedBox(
            width: 480,
            height: 320,
            child: ListView(children: [
              for (final b in blockers)
                Text('${b.country.toUpperCase()} '
                    '${b.isHero ? 'hero' : 'v${b.index}'}: '
                    '${b.report.hard.map((f) => f.message).join('; ')}'),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
      return;
    }

    final approved = SignatureEdit.approve(p,
        lockCountries: lockCountries, approvedAt: DateTime.now());
    widget.io.save(approved);
    final heroes = [for (final cc in widget.codes) if (_cells[cc] != null) _cells[cc]!];
    final label = 'v${approved.version}';
    final sheet = await SignatureSweep.contactSheet(heroes, names: widget.countryNames);
    widget.io.writeReview(approved.id, label,
        sheetPng: sheet, report: SignatureSweep.report(approved, cells, label: label));
    if (!mounted) return;
    setState(() {
      _undo.add(p);
      _pack = approved;
      _dirty = false;
    });
    await _offerGoldens(approved);
  }

  Future<void> _offerGoldens(SignatureRecipe approved) async {
    var running = false;
    String? output;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('${approved.title} v${approved.version} approved'),
          content: SizedBox(
            width: 520,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Saved the pack with locks for '
                  '${approved.locks.keys.join(', ').toUpperCase()} and wrote the '
                  'review sheet to design_studio/contact_sheets/signature/'
                  '${approved.id}/v${approved.version}/.'),
              const SizedBox(height: 8),
              const Text('Goldens are written by (in packages/design_forge_render):'),
              const SelectableText(SignatureIO.goldenCommand,
                  style: TextStyle(fontFamily: 'Menlo', fontSize: 12)),
              if (running) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
              if (output != null)
                SizedBox(
                  height: 160,
                  child: SingleChildScrollView(
                      child: SelectableText(output!, style: const TextStyle(fontFamily: 'Menlo', fontSize: 11))),
                ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: running
                  ? null
                  : () async {
                      setLocal(() => running = true);
                      final (code, out) = await widget.io.updateGoldens();
                      setLocal(() {
                        running = false;
                        output = 'exit $code\n${out.trim().split('\n').take(40).join('\n')}';
                      });
                    },
              child: const Text('Update goldens now'),
            ),
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
          ],
        ),
      ),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 4)));
  }

  // ---- layout --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final p = _pack;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Signature Workbench'),
        actions: [
          if (_ids.isNotEmpty)
            DropdownButton<String>(
              value: p?.id,
              underline: const SizedBox.shrink(),
              items: [for (final id in _ids) DropdownMenuItem(value: id, child: Text(id))],
              onChanged: (id) {
                if (id != null && id != p?.id) _open(id);
              },
            ),
          const SizedBox(width: 8),
          if (p != null) _statusChip(p),
          IconButton(tooltip: 'Undo', onPressed: _undo.isEmpty ? null : _undoEdit, icon: const Icon(Icons.undo)),
          IconButton(tooltip: 'Redo', onPressed: _redo.isEmpty ? null : _redoEdit, icon: const Icon(Icons.redo)),
          TextButton.icon(
            onPressed: p == null || !_dirty ? null : _save,
            icon: const Icon(Icons.save_outlined, size: 16),
            label: const Text('Save draft'),
          ),
          TextButton.icon(
            onPressed: p == null || _pending > 0 ? null : _exportReview,
            icon: const Icon(Icons.grid_view, size: 16),
            label: const Text('Export sheet'),
          ),
          FilledButton.icon(
            onPressed: p == null || _pending > 0 || p.isApproved && !_dirty ? null : _approve,
            icon: const Icon(Icons.verified_outlined, size: 16),
            label: const Text('Approve…'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: p == null
          ? const Center(child: Text('No signature packs in packages/design_studio/assets/signature'))
          : Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(width: 340, child: _paramsPanel(p)),
              const VerticalDivider(width: 1),
              Expanded(child: _sheetPanel(p)),
              if (_selected != null) ...[
                const VerticalDivider(width: 1),
                SizedBox(width: 400, child: _inspector(p, _selected!)),
              ],
            ]),
    );
  }

  bool _landscape(SignatureRecipe p) {
    try {
      return SignatureResolver.hero(p, 'us').composition.canvasOrientation ==
          Orientation.landscape;
    } catch (_) {
      return false;
    }
  }

  Widget _statusChip(SignatureRecipe p) => Chip(
        visualDensity: VisualDensity.compact,
        backgroundColor: p.isApproved ? const Color(0xFFD6F0DC) : const Color(0xFFFFF1C9),
        label: Text('${p.status.name} v${p.version}${_dirty ? ' · unsaved' : ''}'),
      );

  // Left: parameters.
  Widget _paramsPanel(SignatureRecipe p) {
    final paths = SignatureEdit.editablePaths(p);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(p.title, style: Theme.of(context).textTheme.titleMedium),
        if (p.notes != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(p.notes!, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ),
        const SizedBox(height: 8),
        const Text('Value applies to every country. "Vary" lets variations move '
            'it within the range.', style: TextStyle(fontSize: 11)),
        const Divider(),
        for (final path in paths) _ParamRow(
          key: ValueKey('param-$path-${p.version}-${identityHashCode(p)}'),
          path: path,
          value: SignatureEdit.baseValue(p, path),
          range: p.envelope.ranges[path],
          onValue: (v) => _apply((s) => SignatureEdit.setBase(s, path, v)),
          onRange: (r) => _apply((s) => SignatureEdit.setRange(s, path, r)),
          parseError: _toast,
        ),
      ],
    );
  }

  // Centre: all countries.
  Widget _sheetPanel(SignatureRecipe p) {
    final counts = {for (final s in QaStatus.values) s: 0};
    for (final c in _cells.values) {
      counts[c.report.status] = counts[c.report.status]! + 1;
    }
    final q = _query.toLowerCase();
    final shown = [
      for (final cc in widget.codes)
        if ((q.isEmpty ||
                cc.contains(q) ||
                (widget.countryNames[cc]?.toLowerCase().contains(q) ?? false)) &&
            switch (_filter) {
              _Filter.all => true,
              _Filter.warnings => _cells[cc]?.report.status == QaStatus.warn,
              _Filter.failures => _cells[cc]?.report.status == QaStatus.fail,
            })
          cc,
    ];
    final garment = QaThresholds.orderableGarments[_garment];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SegmentedButton<_Filter>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: _Filter.all, label: Text('All ${widget.codes.length}')),
              ButtonSegment(value: _Filter.warnings, label: Text('Warnings ${counts[QaStatus.warn]}')),
              ButtonSegment(value: _Filter.failures, label: Text('Failures ${counts[QaStatus.fail]}')),
            ],
            selected: {_filter},
            onSelectionChanged: (s) => setState(() => _filter = s.first),
          ),
          SizedBox(
            width: 180,
            child: TextField(
              decoration: const InputDecoration(hintText: 'Search country', isDense: true, prefixIcon: Icon(Icons.search, size: 16)),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          DropdownButton<int>(
            value: _garment,
            items: [
              for (var i = 0; i < QaThresholds.orderableGarments.length; i++)
                DropdownMenuItem(value: i, child: Text('On ${QaThresholds.orderableGarments[i].$2}')),
            ],
            onChanged: (v) => setState(() => _garment = v ?? _garment),
          ),
          Text(_pending > 0
              ? 'Rendering… ${widget.codes.length - _pending}/${widget.codes.length}'
              : '${counts[QaStatus.pass]} pass · ${counts[QaStatus.warn]} warn · ${counts[QaStatus.fail]} fail'),
        ]),
      ),
      Expanded(
        child: GridView.builder(
          padding: const EdgeInsets.all(12),
          // Tiles take the design's shape, so a rotated (landscape) design
          // is shown at full size rather than letterboxed in a tall tile.
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: _landscape(p) ? 190 : 150,
              childAspectRatio: _landscape(p) ? 1.08 : 0.68,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8),
          itemCount: shown.length,
          itemBuilder: (_, i) {
            final cc = shown[i];
            final cell = _cells[cc];
            final overridden = p.overrides.containsKey(cc);
            final hero = p.heroes.containsKey(cc);
            return InkWell(
              key: ValueKey('tile-$cc'),
              onTap: () => _inspect(cc),
              child: Container(
                decoration: BoxDecoration(
                  color: garment.$1,
                  border: Border.all(
                      color: _selected == cc ? Colors.blueAccent : Colors.black12,
                      width: _selected == cc ? 2 : 1),
                ),
                child: Column(children: [
                  Expanded(
                    child: Stack(children: [
                      Positioned.fill(
                        child: cell?.image == null
                            ? const Center(child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)))
                            : RawImage(image: cell!.image, fit: BoxFit.contain),
                      ),
                      if (cell != null)
                        Positioned(
                          left: 4,
                          top: 4,
                          child: Tooltip(
                            message: [...cell.report.hard, ...cell.report.soft].map((f) => f.message).join('\n').ifEmpty('All checks pass'),
                            child: CircleAvatar(radius: 5, backgroundColor: SignatureSweep.statusColour(cell.report.status)),
                          ),
                        ),
                    ]),
                  ),
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      '${cc.toUpperCase()} ${widget.countryNames[cc] ?? ''}${overridden ? ' ✎' : ''}${hero ? ' ★' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }

  // Right: selected country.
  Widget _inspector(SignatureRecipe p, String cc) {
    final cell = _cells[cc];
    final override = p.overrides[cc];
    final hero = p.heroes[cc];
    return ListView(padding: const EdgeInsets.all(12), children: [
      Row(children: [
        Expanded(
          child: Text('${cc.toUpperCase()} ${widget.countryNames[cc] ?? ''}',
              style: Theme.of(context).textTheme.titleMedium),
        ),
        IconButton(onPressed: () => setState(() => _selected = null), icon: const Icon(Icons.close)),
      ]),
      // The hero on every orderable garment.
      SizedBox(
        height: 300,
        child: _inspectorImage == null
            ? const Center(child: CircularProgressIndicator())
            : Container(
                color: QaThresholds.orderableGarments[_garment].$1,
                child: RawImage(image: _inspectorImage, fit: BoxFit.contain),
              ),
      ),
      const SizedBox(height: 6),
      Wrap(spacing: 4, runSpacing: 4, children: [
        for (var i = 0; i < QaThresholds.orderableGarments.length; i++)
          Tooltip(
            message: QaThresholds.orderableGarments[i].$2,
            child: InkWell(
              onTap: () => setState(() => _garment = i),
              child: Container(
                width: 58,
                height: 72,
                decoration: BoxDecoration(
                  color: QaThresholds.orderableGarments[i].$1,
                  border: Border.all(color: i == _garment ? Colors.blueAccent : Colors.black26, width: i == _garment ? 2 : 1),
                ),
                child: cell?.image == null ? null : RawImage(image: cell!.image, fit: BoxFit.contain),
              ),
            ),
          ),
      ]),
      const SizedBox(height: 8),
      if (cell != null) ...[
        for (final f in cell.report.hard)
          Text('✖ ${f.message}', style: const TextStyle(color: Color(0xFFD7263D), fontSize: 12)),
        for (final f in cell.report.soft)
          Text('▲ ${f.message}', style: const TextStyle(color: Color(0xFF9A6E00), fontSize: 12)),
        if (cell.report.status == QaStatus.pass)
          const Text('✔ All checks pass', style: TextStyle(color: Color(0xFF2E9E4F), fontSize: 12)),
        Text('recipeId ${cell.recipe.recipeId}', style: const TextStyle(fontSize: 10, color: Colors.black45)),
      ],
      const Divider(),
      Row(children: [
        Text('Variations', style: Theme.of(context).textTheme.titleSmall),
        const Spacer(),
        if (hero != null)
          TextButton(
            onPressed: () => _apply((s) => SignatureEdit.setHero(s, cc, null)),
            child: const Text('Reset hero'),
          ),
      ]),
      if (p.envelope.isEmpty)
        const Text('No parameter varies yet. Tick "Vary" on the left to give '
            'this recipe variations.', style: TextStyle(fontSize: 12))
      else
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (var i = 1; i <= _variationCount; i++)
            _variationTile(p, cc, i),
        ]),
      const Divider(),
      Text('Override for this country', style: Theme.of(context).textTheme.titleSmall),
      _OverrideEditor(
        key: ValueKey('override-$cc-${identityHashCode(p)}'),
        paths: SignatureEdit.editablePaths(p),
        current: override,
        valueOf: (path) => SignatureEdit.baseValue(p, path),
        onSave: (o) => _apply((s) => SignatureEdit.setOverride(s, cc, o)),
        onError: _toast,
      ),
    ]);
  }

  Widget _variationTile(SignatureRecipe p, String cc, int i) {
    final v = _variations[i];
    return Container(
      width: 112,
      decoration: BoxDecoration(border: Border.all(color: Colors.black12)),
      child: Column(children: [
        Container(
          height: 130,
          color: QaThresholds.orderableGarments[_garment].$1,
          child: v?.image == null
              ? const Center(child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)))
              : Stack(children: [
                  Positioned.fill(child: RawImage(image: v!.image, fit: BoxFit.contain)),
                  Positioned(
                    left: 3,
                    top: 3,
                    child: CircleAvatar(radius: 4, backgroundColor: SignatureSweep.statusColour(v.report.status)),
                  ),
                ]),
        ),
        TextButton(
          onPressed: v == null
              ? null
              : () => _apply((s) => SignatureEdit.setHero(s, cc, SignatureEdit.heroValuesOf(s, v.recipe))),
          child: Text('v$i → hero', style: const TextStyle(fontSize: 11)),
        ),
      ]),
    );
  }
}

/// One parameter: its base value, and its envelope range when it varies.
class _ParamRow extends StatefulWidget {
  const _ParamRow({
    super.key,
    required this.path,
    required this.value,
    required this.range,
    required this.onValue,
    required this.onRange,
    required this.parseError,
  });

  final String path;
  final Object? value;
  final ParamRange? range;
  final ValueChanged<Object?> onValue;
  final ValueChanged<ParamRange?> onRange;
  final ValueChanged<String> parseError;

  @override
  State<_ParamRow> createState() => _ParamRowState();
}

class _ParamRowState extends State<_ParamRow> {
  late final TextEditingController _value = TextEditingController(text: '${widget.value}');
  late final TextEditingController _lo = TextEditingController(text: _rangeText(0));
  late final TextEditingController _hi = TextEditingController(text: _rangeText(1));
  double? _drag;

  String _rangeText(int end) => switch (widget.range) {
        NumRange(:final min, :final max) => '${end == 0 ? min : max}',
        ValueSet(:final values) => end == 0 ? values.join(', ') : '',
        null => '',
      };

  bool get _unit => widget.value is double && (widget.value as double) >= 0 && (widget.value as double) <= 1;

  @override
  void dispose() {
    _value.dispose();
    _lo.dispose();
    _hi.dispose();
    super.dispose();
  }

  void _submitValue(String text) {
    try {
      widget.onValue(SignatureEdit.parseLike(widget.value, text));
    } on FormatException catch (e) {
      widget.parseError(e.message);
    }
  }

  void _submitRange() {
    try {
      final v = widget.value;
      if (widget.range is ValueSet || v is bool || v is String) {
        final values = [
          for (final s in _lo.text.split(','))
            if (s.trim().isNotEmpty) SignatureEdit.parseLike(v, s),
        ];
        widget.onRange(ValueSet(values));
      } else {
        final lo = SignatureEdit.parseLike(v, _lo.text) as num;
        final hi = SignatureEdit.parseLike(v, _hi.text) as num;
        widget.onRange(NumRange(lo, hi, integer: v is int));
      }
    } on FormatException catch (e) {
      widget.parseError(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final range = widget.range;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(widget.path, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
          const Text('Vary', style: TextStyle(fontSize: 11)),
          Checkbox(
            key: ValueKey('vary-${widget.path}'),
            visualDensity: VisualDensity.compact,
            value: range != null,
            onChanged: (on) => widget.onRange(
                on == true ? SignatureEdit.defaultRange(widget.path, widget.value) : null),
          ),
        ]),
        if (widget.value is bool)
          Switch(value: widget.value as bool, onChanged: (b) => widget.onValue(b))
        else if (_unit)
          Row(children: [
            Expanded(
              child: Slider(
                value: _drag ?? (widget.value as double),
                onChanged: (d) => setState(() => _drag = d),
                onChangeEnd: (d) {
                  _drag = null;
                  widget.onValue((d * 1000).roundToDouble() / 1000);
                },
              ),
            ),
            SizedBox(width: 44, child: Text((_drag ?? widget.value as double).toStringAsFixed(3), style: const TextStyle(fontSize: 11))),
          ])
        else
          TextField(
            controller: _value,
            decoration: const InputDecoration(isDense: true),
            style: const TextStyle(fontSize: 12),
            onSubmitted: _submitValue,
          ),
        if (range != null)
          Row(children: [
            const Text('range ', style: TextStyle(fontSize: 11, color: Colors.black54)),
            Expanded(
              child: TextField(
                controller: _lo,
                decoration: InputDecoration(isDense: true, hintText: range is ValueSet ? 'a, b, c' : 'min'),
                style: const TextStyle(fontSize: 11),
                onSubmitted: (_) => _submitRange(),
              ),
            ),
            if (range is NumRange) ...[
              const Text(' – '),
              Expanded(
                child: TextField(
                  controller: _hi,
                  decoration: const InputDecoration(isDense: true, hintText: 'max'),
                  style: const TextStyle(fontSize: 11),
                  onSubmitted: (_) => _submitRange(),
                ),
              ),
            ],
          ]),
      ]),
    );
  }
}

/// Adds or edits this country's override (one parameter at a time, with a
/// required reason), or removes it.
class _OverrideEditor extends StatefulWidget {
  const _OverrideEditor({
    super.key,
    required this.paths,
    required this.current,
    required this.valueOf,
    required this.onSave,
    required this.onError,
  });

  final List<String> paths;
  final CountryOverride? current;
  final Object? Function(String path) valueOf;
  final ValueChanged<CountryOverride?> onSave;
  final ValueChanged<String> onError;

  @override
  State<_OverrideEditor> createState() => _OverrideEditorState();
}

class _OverrideEditorState extends State<_OverrideEditor> {
  String? _path;
  late final TextEditingController _value = TextEditingController();
  late final TextEditingController _reason =
      TextEditingController(text: widget.current?.reason ?? '');

  @override
  void dispose() {
    _value.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _add() {
    final path = _path;
    if (path == null) return;
    try {
      final v = SignatureEdit.parseLike(widget.valueOf(path), _value.text);
      widget.onSave(CountryOverride(
        params: {...?widget.current?.params, path: v},
        reason: _reason.text,
      ));
    } on FormatException catch (e) {
      widget.onError(e.message);
    }
  }

  void _remove(String path) {
    final rest = {...widget.current!.params}..remove(path);
    widget.onSave(rest.isEmpty ? null : CountryOverride(params: rest, reason: widget.current!.reason));
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.current;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (current != null)
        for (final e in current.params.entries)
          Row(children: [
            Expanded(child: Text('${e.key} = ${e.value}', style: const TextStyle(fontSize: 12))),
            IconButton(
              tooltip: 'Remove',
              visualDensity: VisualDensity.compact,
              onPressed: () => _remove(e.key),
              icon: const Icon(Icons.close, size: 16),
            ),
          ]),
      DropdownButton<String>(
        isExpanded: true,
        hint: const Text('Parameter', style: TextStyle(fontSize: 12)),
        value: _path,
        items: [for (final p in widget.paths) DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 12)))],
        onChanged: (p) => setState(() {
          _path = p;
          if (p != null) _value.text = '${widget.valueOf(p)}';
        }),
      ),
      TextField(controller: _value, decoration: const InputDecoration(labelText: 'Value', isDense: true)),
      TextField(
        controller: _reason,
        decoration: const InputDecoration(labelText: 'Reason (required)', isDense: true),
      ),
      const SizedBox(height: 6),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.tonal(onPressed: _path == null ? null : _add, child: const Text('Save override')),
      ),
    ]);
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
