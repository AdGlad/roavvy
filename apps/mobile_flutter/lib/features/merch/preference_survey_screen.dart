import 'package:design_forge/design_forge.dart' hide Clip;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'design_engine/preference_store.dart';
import 'design_engine/procedural/preference_profile.dart';

/// Mobile-optimised preference survey shown on first merch visit.
///
/// Three swipeable steps:
/// 1. Style vibe — pick 1–2 style clusters
/// 2. Shape preference — pick 1–3 shape families
/// 3. Garment & color — light/dark, vibrant/muted
///
/// Results are folded into the user's [UserDesignPreferenceProfile] via
/// forge [DesignPreferences] and persisted through the preference store.
class PreferenceSurveyScreen extends ConsumerStatefulWidget {
  const PreferenceSurveyScreen({super.key, this.onComplete});

  /// Called after the survey completes (or is skipped).
  final VoidCallback? onComplete;

  @override
  ConsumerState<PreferenceSurveyScreen> createState() =>
      _PreferenceSurveyScreenState();
}

class _PreferenceSurveyScreenState
    extends ConsumerState<PreferenceSurveyScreen> {
  final _controller = PageController();
  int _page = 0;

  final _selectedStyles = <StyleCluster>{};
  final _selectedShapes = <ShapePreference>{};
  bool? _darkGarment;
  bool? _vibrant;

  void _next() {
    if (_page < 2) {
      setState(() => _page++);
      _controller.animateToPage(_page,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_page > 0) {
      setState(() => _page--);
      _controller.animateToPage(_page,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _skip() {
    widget.onComplete?.call();
    Navigator.of(context).pop();
  }

  void _finish() {
    // Build forge preferences from survey answers.
    final styleWeights = <StyleCluster, double>{};
    for (final c in StyleCluster.values) {
      styleWeights[c] = _selectedStyles.contains(c) ? 2.5 : 0.6;
    }
    final shapeWeights = <ShapePreference, double>{};
    for (final s in ShapePreference.values) {
      shapeWeights[s] = _selectedShapes.contains(s) ? 2.5 : 0.6;
    }
    final forgePrefs = DesignPreferences(
      styleWeights: styleWeights,
      shapeWeights: shapeWeights,
      prefersDarkGarment: _darkGarment,
      prefersVibrant: _vibrant,
    );

    // Convert to mobile profile and persist.
    final existing = ref.read(preferenceProfileProvider);
    final updated =
        UserDesignPreferenceProfile.fromDesignPreferences(forgePrefs,
            existing: existing);
    // Persist the updated profile. The preference provider will load it on
    // next read.
    SharedPrefsPreferenceStore().save(updated);

    widget.onComplete?.call();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Design Preferences'),
        leading: _page > 0
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _back)
            : null,
        actions: [
          TextButton(onPressed: _skip, child: const Text('Skip')),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: i <= _page
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _StyleStep(
                    selected: _selectedStyles,
                    onToggle: (c) => setState(() {
                      if (_selectedStyles.contains(c)) {
                        _selectedStyles.remove(c);
                      } else {
                        _selectedStyles.add(c);
                      }
                    }),
                  ),
                  _ShapeStep(
                    selected: _selectedShapes,
                    onToggle: (s) => setState(() {
                      if (_selectedShapes.contains(s)) {
                        _selectedShapes.remove(s);
                      } else {
                        _selectedShapes.add(s);
                      }
                    }),
                  ),
                  _GarmentStep(
                    darkGarment: _darkGarment,
                    vibrant: _vibrant,
                    onDarkChanged: (v) => setState(() => _darkGarment = v),
                    onVibrantChanged: (v) => setState(() => _vibrant = v),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: FilledButton(
                onPressed: _next,
                child: Text(_page < 2 ? 'Next' : 'Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StyleStep extends StatelessWidget {
  const _StyleStep({required this.selected, required this.onToggle});
  final Set<StyleCluster> selected;
  final void Function(StyleCluster) onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text('What style speaks to you?', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('Pick 1–2 vibes', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 1.4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                for (final c in StyleCluster.values)
                  _SelectableCard(
                    label: c.label,
                    subtitle: _clusterHint(c),
                    selected: selected.contains(c),
                    onTap: () => onToggle(c),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _clusterHint(StyleCluster c) => switch (c) {
        StyleCluster.clean => 'Minimalist, premium',
        StyleCluster.vintage => 'Retro, worn-in',
        StyleCluster.bold => 'Street, grunge',
        StyleCluster.relaxed => 'Beach, surf, outdoor',
        StyleCluster.artistic => 'Maximal, creative',
        StyleCluster.typographic => 'Type-forward',
      };
}

class _ShapeStep extends StatelessWidget {
  const _ShapeStep({required this.selected, required this.onToggle});
  final Set<ShapePreference> selected;
  final void Function(ShapePreference) onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text('Preferred design shapes', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('Pick 1–3', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 1.4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                for (final s in ShapePreference.values)
                  _SelectableCard(
                    label: s.label,
                    subtitle: s.description,
                    selected: selected.contains(s),
                    onTap: () => onToggle(s),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GarmentStep extends StatelessWidget {
  const _GarmentStep({
    required this.darkGarment,
    required this.vibrant,
    required this.onDarkChanged,
    required this.onVibrantChanged,
  });
  final bool? darkGarment;
  final bool? vibrant;
  final void Function(bool?) onDarkChanged;
  final void Function(bool?) onVibrantChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text('Garment & color', style: theme.textTheme.titleLarge),
          const SizedBox(height: 24),
          Text('T-shirt color', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<bool?>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: null, label: Text('Either')),
              ButtonSegment(value: false, label: Text('Light')),
              ButtonSegment(value: true, label: Text('Dark')),
            ],
            selected: {darkGarment},
            onSelectionChanged: (s) => onDarkChanged(s.first),
          ),
          const SizedBox(height: 24),
          Text('Color intensity', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<bool?>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: null, label: Text('Either')),
              ButtonSegment(value: true, label: Text('Vibrant')),
              ButtonSegment(value: false, label: Text('Muted')),
            ],
            selected: {vibrant},
            onSelectionChanged: (s) => onVibrantChanged(s.first),
          ),
        ],
      ),
    );
  }
}

class _SelectableCard extends StatelessWidget {
  const _SelectableCard({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  )),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

/// Key used to check if the survey has been completed.
const kPreferenceSurveyCompletedKey = 'pref_survey_completed_v1';
