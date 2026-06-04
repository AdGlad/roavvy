import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/providers.dart';
import 'merch_preset.dart';

/// Opens the Layer 2 advanced customisation sheet and returns the updated
/// [MerchPresetConfig], or `null` if the user cancelled (ADR-147).
///
/// Usage:
/// ```dart
/// final updated = await showMerchCustomisationSheet(
///   context,
///   config: _currentConfig,
/// );
/// if (updated != null) _applyConfig(updated);
/// ```
Future<MerchPresetConfig?> showMerchCustomisationSheet(
  BuildContext context, {
  required MerchPresetConfig config,
}) {
  return showModalBottomSheet<MerchPresetConfig>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MerchCustomisationSheet(config: config),
  );
}

class _MerchCustomisationSheet extends ConsumerStatefulWidget {
  const _MerchCustomisationSheet({required this.config});

  final MerchPresetConfig config;

  @override
  ConsumerState<_MerchCustomisationSheet> createState() =>
      _MerchCustomisationSheetState();
}

class _MerchCustomisationSheetState
    extends ConsumerState<_MerchCustomisationSheet> {
  late MerchPresetConfig _config;

  @override
  void initState() {
    super.initState();
    _config = widget.config;
  }

  void _applyPreset(MerchPreset preset) {
    setState(() => _config = preset.config);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final landmarkAvailable =
        ref.watch(imagePlaygroundAvailableProvider).valueOrNull ?? false;

    return DraggableScrollableSheet(
      initialChildSize: 0.70,
      minChildSize: 0.40,
      maxChildSize: 0.92,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    Text(
                      'Customise Design',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    // ── Preset picker ──────────────────────────────────────
                    _SectionLabel('Style preset', theme),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          kMerchPresets.map((preset) {
                            // Highlight the chip if the current layout+source match.
                            final isActive =
                                _config.layout == preset.config.layout &&
                                _config.source == preset.config.source;
                            return ChoiceChip(
                              label: Text(preset.label),
                              selected: isActive,
                              onSelected: (_) => _applyPreset(preset),
                              selectedColor: theme.colorScheme.primaryContainer,
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // ── Layout ────────────────────────────────────────────
                    _SectionLabel('Layout', theme),
                    const SizedBox(height: 8),
                    _OptionRow(
                      options: [
                        'Passport',
                        'Grid',
                        if (landmarkAvailable) 'Landmark',
                      ],
                      selected: switch (_config.layout) {
                        CardTemplateType.passport => 'Passport',
                        CardTemplateType.grid => 'Grid',
                        CardTemplateType.landmark =>
                          landmarkAvailable ? 'Landmark' : 'Grid',
                        _ => 'Grid',
                      },
                      onChanged:
                          (v) => setState(() {
                            _config = _config.copyWithOverrides(
                              layout: switch (v) {
                                'Passport' => CardTemplateType.passport,
                                'Landmark' => CardTemplateType.landmark,
                                _ => CardTemplateType.grid,
                              },
                            );
                          }),
                    ),
                    const SizedBox(height: 20),

                    // ── Jitter ────────────────────────────────────────────
                    _SectionLabel('Arrangement', theme),
                    const SizedBox(height: 8),
                    _OptionRow(
                      options: const ['Structured', 'Spread', 'Scattered'],
                      selected:
                          _config.jitter < 0.35
                              ? 'Structured'
                              : _config.jitter < 0.65
                              ? 'Spread'
                              : 'Scattered',
                      onChanged:
                          (v) => setState(() {
                            _config = _config.copyWithOverrides(
                              jitter: switch (v) {
                                'Structured' => 0.2,
                                'Scattered' => 0.8,
                                _ => 0.5,
                              },
                            );
                          }),
                    ),
                    const SizedBox(height: 20),

                    // ── Density ───────────────────────────────────────────
                    _SectionLabel('Fill style', theme),
                    const SizedBox(height: 8),
                    _OptionRow(
                      options: const ['Airy', 'Balanced', 'Packed'],
                      selected: switch (_config.density) {
                        MerchDensity.sparse => 'Airy',
                        MerchDensity.balanced => 'Balanced',
                        MerchDensity.dense => 'Packed',
                      },
                      onChanged:
                          (v) => setState(() {
                            _config = _config.copyWithOverrides(
                              density: switch (v) {
                                'Airy' => MerchDensity.sparse,
                                'Packed' => MerchDensity.dense,
                                _ => MerchDensity.balanced,
                              },
                            );
                          }),
                    ),
                    const SizedBox(height: 20),

                    // ── Stamp mode ────────────────────────────────────────
                    _SectionLabel('Stamps per country', theme),
                    const SizedBox(height: 8),
                    _OptionRow(
                      options: const ['One per country', 'Entry and exit'],
                      selected:
                          _config.stampMode == MerchStampMode.entryOnly
                              ? 'One per country'
                              : 'Entry and exit',
                      onChanged:
                          (v) => setState(() {
                            _config = _config.copyWithOverrides(
                              stampMode:
                                  v == 'One per country'
                                      ? MerchStampMode.entryOnly
                                      : MerchStampMode.entryExit,
                            );
                          }),
                    ),
                  ],
                ),
              ),
              // Apply button
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(_config),
                      child: const Text('Apply'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, this.theme);

  final String label;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          options.map((opt) {
            final isSelected = opt == selected;
            return ChoiceChip(
              label: Text(opt),
              selected: isSelected,
              onSelected: (_) => onChanged(opt),
              selectedColor: theme.colorScheme.primaryContainer,
            );
          }).toList(),
    );
  }
}
