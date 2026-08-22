import 'dart:convert';
import 'dart:io';

import 'package:design_forge/design_forge.dart';
import 'package:flutter/material.dart';

import 'render_service.dart';

/// Travel persona for the simulator.
enum TravelPersona {
  soloDeepDive('Solo Deep-Dive', 'One country, explored thoroughly'),
  recentAdventurer('Recent Adventurer', '2–5 countries, recent trips'),
  continentHopper('Continent Hopper', 'Spread across 3+ continents'),
  regionExplorer('Region Explorer', '5–15 countries in one region'),
  globeTrotter('Globe Trotter', '20+ countries worldwide');

  const TravelPersona(this.label, this.description);
  final String label;
  final String description;
}

/// Simulated travel context for the Design Lab (no real travel data on macOS).
class SimulatedTravelContext {
  const SimulatedTravelContext({
    this.visitedCountries = const {},
    this.signatureCountries = const {},
    this.persona = TravelPersona.recentAdventurer,
  });

  final Set<String> visitedCountries;
  final Set<String> signatureCountries;
  final TravelPersona persona;

  Map<String, dynamic> toJson() => {
        'visitedCountries': visitedCountries.toList(),
        'signatureCountries': signatureCountries.toList(),
        'persona': persona.name,
      };

  factory SimulatedTravelContext.fromJson(Map<String, dynamic> j) {
    return SimulatedTravelContext(
      visitedCountries:
          (j['visitedCountries'] as List?)?.cast<String>().toSet() ?? {},
      signatureCountries:
          (j['signatureCountries'] as List?)?.cast<String>().toSet() ?? {},
      persona: TravelPersona.values
              .where((p) => p.name == j['persona'])
              .firstOrNull ??
          TravelPersona.recentAdventurer,
    );
  }
}

/// A multi-step preference survey dialog that produces [DesignPreferences].
class PreferenceSurveyDialog extends StatefulWidget {
  const PreferenceSurveyDialog({
    super.key,
    this.initial,
    required this.service,
    required this.allCodes,
  });

  final DesignPreferences? initial;
  final RenderService service;
  final List<String> allCodes;

  /// Shows the dialog and returns the resulting preferences, or null on cancel.
  static Future<DesignPreferences?> show(
    BuildContext context, {
    DesignPreferences? initial,
    required RenderService service,
    required List<String> allCodes,
  }) {
    return showDialog<DesignPreferences>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PreferenceSurveyDialog(
        initial: initial,
        service: service,
        allCodes: allCodes,
      ),
    );
  }

  @override
  State<PreferenceSurveyDialog> createState() => _PreferenceSurveyDialogState();
}

class _PreferenceSurveyDialogState extends State<PreferenceSurveyDialog> {
  int _step = 0;

  // Step 1: style clusters
  final _selectedStyles = <StyleCluster>{};

  // Step 2: shape preferences
  final _selectedShapes = <ShapePreference>{};

  // Step 3: garment & color
  bool? _darkGarment;
  bool? _vibrant;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      final p = widget.initial!;
      for (final c in StyleCluster.values) {
        if (p.weightFor(c) > 1.2) _selectedStyles.add(c);
      }
      for (final s in ShapePreference.values) {
        if (p.shapeWeightFor(s) > 1.2) _selectedShapes.add(s);
      }
      _darkGarment = p.prefersDarkGarment;
      _vibrant = p.prefersVibrant;
    }
  }

  DesignPreferences _build() {
    final styleWeights = <StyleCluster, double>{};
    for (final c in StyleCluster.values) {
      styleWeights[c] = _selectedStyles.contains(c) ? 2.5 : 0.6;
    }
    final shapeWeights = <ShapePreference, double>{};
    for (final s in ShapePreference.values) {
      shapeWeights[s] = _selectedShapes.contains(s) ? 2.5 : 0.6;
    }
    return DesignPreferences(
      styleWeights: styleWeights,
      shapeWeights: shapeWeights,
      prefersDarkGarment: _darkGarment,
      prefersVibrant: _vibrant,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        ['Style Vibe', 'Shape Preference', 'Garment & Color'][_step],
      ),
      content: SizedBox(
        width: 500,
        height: 340,
        child: [_styleStep(), _shapeStep(), _garmentStep()][_step],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        if (_step > 0)
          TextButton(
            onPressed: () => setState(() => _step--),
            child: const Text('Back'),
          ),
        FilledButton(
          onPressed: () {
            if (_step < 2) {
              setState(() => _step++);
            } else {
              Navigator.of(context).pop(_build());
            }
          },
          child: Text(_step < 2 ? 'Next' : 'Done'),
        ),
      ],
    );
  }

  Widget _styleStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Pick 1–2 styles you gravitate toward:'),
        const SizedBox(height: 12),
        Expanded(
          child: GridView.count(
            crossAxisCount: 3,
            childAspectRatio: 1.6,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: [
              for (final c in StyleCluster.values) _clusterChip(c),
            ],
          ),
        ),
      ],
    );
  }

  Widget _clusterChip(StyleCluster c) {
    final selected = _selectedStyles.contains(c);
    return InkWell(
      onTap: () => setState(() {
        if (selected) {
          _selectedStyles.remove(c);
        } else {
          _selectedStyles.add(c);
        }
      }),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? Colors.tealAccent : Colors.white24,
            width: selected ? 2 : 1,
          ),
          color: selected ? Colors.tealAccent.withValues(alpha: 0.1) : null,
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(c.label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                )),
            const SizedBox(height: 2),
            Text(
              _clusterHint(c),
              style: const TextStyle(fontSize: 10, color: Colors.white54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _clusterHint(StyleCluster c) {
    switch (c) {
      case StyleCluster.clean:
        return 'Minimalist, premium';
      case StyleCluster.vintage:
        return 'Retro, worn-in';
      case StyleCluster.bold:
        return 'Street, grunge, extreme';
      case StyleCluster.relaxed:
        return 'Beach, surf, outdoor';
      case StyleCluster.artistic:
        return 'Maximal, showcase';
      case StyleCluster.typographic:
        return 'Type-forward, lettering';
    }
  }

  Widget _shapeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Pick 1–3 shape families you like:'),
        const SizedBox(height: 12),
        Expanded(
          child: GridView.count(
            crossAxisCount: 3,
            childAspectRatio: 1.6,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: [
              for (final s in ShapePreference.values) _shapeChip(s),
            ],
          ),
        ),
      ],
    );
  }

  Widget _shapeChip(ShapePreference s) {
    final selected = _selectedShapes.contains(s);
    return InkWell(
      onTap: () => setState(() {
        if (selected) {
          _selectedShapes.remove(s);
        } else {
          _selectedShapes.add(s);
        }
      }),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? Colors.tealAccent : Colors.white24,
            width: selected ? 2 : 1,
          ),
          color: selected ? Colors.tealAccent.withValues(alpha: 0.1) : null,
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(s.label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                )),
            const SizedBox(height: 2),
            Text(s.description,
                style: const TextStyle(fontSize: 10, color: Colors.white54),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _garmentStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Garment tone'),
        const SizedBox(height: 8),
        SegmentedButton<bool?>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: null, label: Text('No preference')),
            ButtonSegment(value: false, label: Text('Light')),
            ButtonSegment(value: true, label: Text('Dark')),
          ],
          selected: {_darkGarment},
          onSelectionChanged: (s) => setState(() => _darkGarment = s.first),
        ),
        const SizedBox(height: 20),
        const Text('Color intensity'),
        const SizedBox(height: 8),
        SegmentedButton<bool?>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: null, label: Text('No preference')),
            ButtonSegment(value: true, label: Text('Vibrant')),
            ButtonSegment(value: false, label: Text('Muted / Vintage')),
          ],
          selected: {_vibrant},
          onSelectionChanged: (s) => setState(() => _vibrant = s.first),
        ),
        const Spacer(),
        const Text(
          'These preferences weight the recommendation engine. '
          'You can re-take this survey any time from the Profile panel.',
          style: TextStyle(fontSize: 11, color: Colors.white38),
        ),
      ],
    );
  }
}

/// Persists and loads [DesignPreferences] + [SimulatedTravelContext] to disk.
class PreferencePersistence {
  PreferencePersistence(this._dir);
  final Directory _dir;

  File get _prefsFile => File('${_dir.path}/preferences.json');
  File get _profileFile => File('${_dir.path}/travel_profile.json');

  Future<DesignPreferences?> loadPreferences() async {
    if (!await _prefsFile.exists()) return null;
    final json = await _prefsFile.readAsString();
    return DesignPreferences.decode(json);
  }

  Future<void> savePreferences(DesignPreferences p) async {
    await _prefsFile.writeAsString(p.encode());
  }

  Future<SimulatedTravelContext?> loadProfile() async {
    if (!await _profileFile.exists()) return null;
    final raw = await _profileFile.readAsString();
    return SimulatedTravelContext.fromJson(
        jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveProfile(SimulatedTravelContext p) async {
    await _profileFile.writeAsString(jsonEncode(p.toJson()));
  }
}
