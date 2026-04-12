import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

// --- CONFIGURATION ---
const String basePath = '/Users/adglad/git/roavvy/apps/mobile_flutter/assets';
final String metaPath = p.join(basePath, 'mobile_meta');
final String pngPath = p.join(basePath, 'mobile_png');
final String svgPath = p.join(basePath, 'mobile_svg');

void main() {
  runApp(const ProviderScope(child: StampEditorApp()));
}

class StampEditorApp extends StatelessWidget {
  const StampEditorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stamp Meta Editor',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const EditorScreen(),
    );
  }
}

// --- MODELS ---

class StampMetadata {
  final String name;
  final String pngAsset;
  final Map<String, dynamic> rawJson;
  final double x;
  final double y;
  final double rotation;
  final int fontSize;
  final String fontFamily;
  final int fontWeight;
  final double letterSpacing;
  final String anchor;
  final int imgWidth;
  final int imgHeight;
  final String dateFormat;

  StampMetadata({
    required this.name,
    required this.pngAsset,
    required this.rawJson,
    required this.x,
    required this.y,
    required this.rotation,
    required this.fontSize,
    required this.fontFamily,
    required this.fontWeight,
    required this.letterSpacing,
    required this.anchor,
    required this.imgWidth,
    required this.imgHeight,
    required this.dateFormat,
  });

  factory StampMetadata.fromJson(Map<String, dynamic> json) {
    final date = json['date'] as Map<String, dynamic>;
    final image = json['image'] as Map<String, dynamic>;
    return StampMetadata(
      name: json['name'],
      pngAsset: json['png_asset'],
      rawJson: json,
      x: (date['x'] as num).toDouble(),
      y: (date['y'] as num).toDouble(),
      rotation: (date['rotation'] as num).toDouble(),
      fontSize: (date['font_size'] as num).toInt(),
      fontFamily: date['font_family'],
      fontWeight: (date['font_weight'] as num).toInt(),
      letterSpacing: (date['letter_spacing'] as num).toDouble(),
      anchor: date['anchor'],
      imgWidth: (image['width'] as num).toInt(),
      imgHeight: (image['height'] as num).toInt(),
      dateFormat: date['date_format'] ?? 'dd MMM yyyy',
    );
  }

  StampMetadata copyWith({
    double? x,
    double? y,
    double? rotation,
    int? fontSize,
    double? letterSpacing,
    String? dateFormat,
  }) {
    final newJson = Map<String, dynamic>.from(rawJson);
    final newDate = Map<String, dynamic>.from(newJson['date']);
    if (x != null) newDate['x'] = x;
    if (y != null) newDate['y'] = y;
    if (rotation != null) newDate['rotation'] = rotation;
    if (fontSize != null) newDate['font_size'] = fontSize;
    if (letterSpacing != null) newDate['letter_spacing'] = letterSpacing;
    if (dateFormat != null) newDate['date_format'] = dateFormat;
    newJson['date'] = newDate;

    return StampMetadata.fromJson(newJson);
  }

  String toFormattedJson() {
    return const JsonEncoder.withIndent('  ').convert(rawJson);
  }
}

// --- STATE MANAGEMENT ---

final assetListProvider = FutureProvider<List<String>>((ref) async {
  final dir = Directory(metaPath);
  if (!await dir.exists()) return [];
  final files = await dir.list().toList();
  return files
      .whereType<File>()
      .where((f) => f.path.endsWith('.json') && !f.path.contains('stamp_manifest'))
      .map((f) => p.basenameWithoutExtension(f.path))
      .toList()
    ..sort();
});

class SelectedAssetNotifier extends StateNotifier<String?> {
  SelectedAssetNotifier() : super(null);
  void select(String name) => state = name;
}

final selectedAssetNameProvider =
    StateNotifierProvider<SelectedAssetNotifier, String?>((ref) => SelectedAssetNotifier());

final currentMetadataProvider = StateNotifierProvider<MetadataNotifier, StampMetadata?>((ref) {
  final selected = ref.watch(selectedAssetNameProvider);
  return MetadataNotifier(selected);
});

class MetadataNotifier extends StateNotifier<StampMetadata?> {
  final String? assetName;
  MetadataNotifier(this.assetName) : super(null) {
    _load();
  }

  bool _hasChanges = false;
  bool get hasChanges => _hasChanges;

  Future<void> _load() async {
    if (assetName == null) return;
    final file = File(p.join(metaPath, '$assetName.json'));
    if (await file.exists()) {
      final content = await file.readAsString();
      state = StampMetadata.fromJson(jsonDecode(content));
      _hasChanges = false;
    }
  }

  void update(StampMetadata next) {
    state = next;
    _hasChanges = true;
  }

  Future<void> save() async {
    if (state == null) return;
    final file = File(p.join(metaPath, '${state!.name}.json'));
    await file.writeAsString(state!.toFormattedJson());
    _hasChanges = false;
    state = state; // trigger rebuild
  }
}

// --- UI COMPONENTS ---

class EditorScreen extends ConsumerWidget {
  const EditorScreen({super.key});

  void _navigate(WidgetRef ref, int delta) {
    ref.read(assetListProvider).whenData((list) {
      final selected = ref.read(selectedAssetNameProvider);
      if (selected == null) {
        if (list.isNotEmpty) ref.read(selectedAssetNameProvider.notifier).select(list.first);
        return;
      }
      final index = list.indexOf(selected);
      final nextIndex = (index + delta).clamp(0, list.length - 1);
      ref.read(selectedAssetNameProvider.notifier).select(list[nextIndex]);
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assets = ref.watch(assetListProvider);
    final selected = ref.watch(selectedAssetNameProvider);
    final meta = ref.watch(currentMetadataProvider);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () => ref.read(currentMetadataProvider.notifier).save(),
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () => ref.read(currentMetadataProvider.notifier).save(),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => _navigate(ref, 1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _navigate(ref, -1),
      },
      child: Scaffold(
        body: Row(
          children: [
          // Sidebar
          Container(
            width: 250,
            color: Colors.black26,
            child: assets.when(
              data: (list) => ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final name = list[i];
                  return ListTile(
                    selected: selected == name,
                    title: Text(name, style: const TextStyle(fontSize: 12)),
                    onTap: () async {
                      if (ref.read(currentMetadataProvider.notifier).hasChanges) {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Unsaved Changes'),
                            content: const Text('You have unsaved changes. Discard?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
                            ],
                          ),
                        );
                        if (confirm != true) return;
                      }
                      ref.read(selectedAssetNameProvider.notifier).select(name);
                    },
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text(e.toString())),
            ),
          ),

          // Main Preview
          Expanded(
            child: Column(
              children: [
                AppBar(
                  title: Text(selected ?? 'Select a stamp'),
                  actions: [
                    if (meta != null)
                      IconButton(
                        icon: const Icon(Icons.save),
                        onPressed: () => ref.read(currentMetadataProvider.notifier).save(),
                        tooltip: 'Save (Cmd+S)',
                      ),
                  ],
                ),
                Expanded(
                  child: selected == null
                      ? const Center(child: Text('No asset selected'))
                      : const StampPreview(),
                ),
              ],
            ),
          ),

          // Right Controls
          if (meta != null)
            Container(
              width: 350,
              color: Colors.black26,
              padding: const EdgeInsets.all(16),
              child: const MetadataEditorPanel(),
            ),
        ],
      ),
    ));
  }
}

class StampPreview extends ConsumerStatefulWidget {
  const StampPreview({super.key});
  @override
  ConsumerState<StampPreview> createState() => _StampPreviewState();
}

class _StampPreviewState extends ConsumerState<StampPreview> {
  double _zoom = 1.0;
  Color _previewColor = Colors.blue;

  @override
  Widget build(BuildContext context) {
    final meta = ref.watch(currentMetadataProvider);
    if (meta == null) return const SizedBox.shrink();

    String previewDate;
    try {
      previewDate = DateFormat(meta.dateFormat).format(DateTime.now()).toUpperCase();
    } catch (e) {
      previewDate = 'INVALID FORMAT';
    }

    final pngFile = File(p.join(pngPath, meta.pngAsset));

    return Column(
      children: [
        // Preview Controls
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              const Text('Zoom: '),
              Expanded(
                child: Slider(
                  value: _zoom,
                  min: 0.5,
                  max: 5.0,
                  onChanged: (v) => setState(() => _zoom = v),
                ),
              ),
              Text('${(_zoom * 100).toInt()}%'),
            ],
          ),
        ),
        Row(
          children: [
            const SizedBox(width: 8),
            const Text('Color: '),
            DropdownButton<Color>(
              value: _previewColor,
              items: [Colors.blue, Colors.red, Colors.green, Colors.black, Colors.purple]
                  .map((c) => DropdownMenuItem(value: c, child: Container(width: 20, height: 20, color: c)))
                  .toList(),
              onChanged: (v) => setState(() => _previewColor = v!),
            ),
            const SizedBox(width: 8),
            Text('Preview Date (from ${meta.dateFormat}): '),
            Text(previewDate, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
          ],
        ),

        // Preview Area
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: Container(
                  margin: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.white12),
                    boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black45)],
                  ),
                  child: Stack(
                    children: [
                      // Background Image
                      Image.file(
                        pngFile,
                        width: meta.imgWidth * _zoom,
                        height: meta.imgHeight * _zoom,
                        fit: BoxFit.contain,
                      ),

                      // Injected Date
                      Positioned(
                        left: meta.x * _zoom,
                        top: meta.y * _zoom,
                        child: Transform.rotate(
                          angle: meta.rotation * math.pi / 180,
                          child: FractionalTranslation(
                            translation: meta.anchor == 'middle' ? const Offset(-0.5, -0.5) : Offset.zero,
                            child: Text(
                              previewDate,
                              style: TextStyle(
                                color: _previewColor,
                                fontSize: meta.fontSize * _zoom,
                                fontWeight: meta.fontWeight == 700 ? FontWeight.bold : FontWeight.normal,
                                letterSpacing: meta.letterSpacing * _zoom,
                                fontFamily: 'monospace', // Placeholder for actual font
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class MetadataEditorPanel extends ConsumerWidget {
  const MetadataEditorPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = ref.watch(currentMetadataProvider);
    if (meta == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Coordinates', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _NumericControl(
            label: 'X Position',
            value: meta.x,
            onChanged: (v) => ref.read(currentMetadataProvider.notifier).update(meta.copyWith(x: v)),
          ),
          _NumericControl(
            label: 'Y Position',
            value: meta.y,
            onChanged: (v) => ref.read(currentMetadataProvider.notifier).update(meta.copyWith(y: v)),
          ),
          _NumericControl(
            label: 'Rotation',
            value: meta.rotation,
            onChanged: (v) => ref.read(currentMetadataProvider.notifier).update(meta.copyWith(rotation: v)),
          ),
          const Divider(),
          const Text('Styling', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _NumericControl(
            label: 'Font Size',
            value: meta.fontSize.toDouble(),
            onChanged: (v) => ref.read(currentMetadataProvider.notifier).update(meta.copyWith(fontSize: v.toInt())),
          ),
          _NumericControl(
            label: 'Letter Spacing',
            value: meta.letterSpacing,
            onChanged: (v) => ref.read(currentMetadataProvider.notifier).update(meta.copyWith(letterSpacing: v)),
          ),
          const SizedBox(height: 8),
          const Text('Date Format (Intl)', style: TextStyle(fontSize: 12)),
          TextField(
            controller: TextEditingController(text: meta.dateFormat)..selection = TextSelection.collapsed(offset: meta.dateFormat.length),
            style: const TextStyle(fontSize: 12),
            onChanged: (v) => ref.read(currentMetadataProvider.notifier).update(meta.copyWith(dateFormat: v)),
          ),
          const Divider(),
          const Text('Raw JSON', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            height: 300,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(4)),
            child: SingleChildScrollView(
              child: SelectableText(
                meta.toFormattedJson(),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Linked Files:', style: Theme.of(context).textTheme.labelSmall),
          Text('PNG: ${meta.pngAsset}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
          Text('SVG: ${meta.name}_mobile.svg', style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _NumericControl extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _NumericControl({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(label, style: const TextStyle(fontSize: 12))),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.remove, size: 16), onPressed: () => onChanged(value - 1)),
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: value.toStringAsFixed(1)),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                    onSubmitted: (v) => onChanged(double.tryParse(v) ?? value),
                  ),
                ),
                IconButton(icon: const Icon(Icons.add, size: 16), onPressed: () => onChanged(value + 1)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
