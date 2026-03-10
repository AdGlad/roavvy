import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import 'visit_store.dart';

/// Lets the user correct the detected visited-country list before it is saved.
///
/// - Swipe left or tap the delete icon to remove a country (creates a manual
///   tombstone so the next scan does not re-add it automatically).
/// - Tap the FAB to add a country that was not detected.
/// - Tap Save to persist the corrected list and return to the previous screen.
///
/// The screen operates on a local copy of [initialVisits]; nothing is written
/// until Save is tapped.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.initialVisits});

  /// The effective (already-merged) visits to start the review with.
  final List<CountryVisit> initialVisits;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  // Working copy — mutated locally until Save is tapped.
  late final List<CountryVisit> _visits;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Sort A→Z by country code for a stable, predictable order.
    _visits = [...widget.initialVisits]
      ..sort((a, b) => a.countryCode.compareTo(b.countryCode));
  }

  void _remove(int index) {
    final visit = _visits[index];
    setState(() {
      // Replace with a manual tombstone so the next scan does not re-surface it.
      _visits[index] = visit.copyWith(
        source: VisitSource.manual,
        isDeleted: true,
        updatedAt: DateTime.now().toUtc(),
      );
    });
  }

  void _undoRemove(int index) {
    setState(() {
      _visits[index] = _visits[index].copyWith(
        isDeleted: false,
        updatedAt: DateTime.now().toUtc(),
      );
    });
  }

  Future<void> _addCountry() async {
    final result = await showDialog<CountryVisit>(
      context: context,
      builder: (_) => const _AddCountryDialog(),
    );
    if (result == null) return;
    setState(() {
      // If the country already exists in the list (active or tombstone), update it.
      final existing = _visits.indexWhere((v) => v.countryCode == result.countryCode);
      if (existing >= 0) {
        _visits[existing] = result;
      } else {
        _visits.add(result);
        _visits.sort((a, b) => a.countryCode.compareTo(b.countryCode));
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    // Persist the full list including tombstones so they survive the next scan.
    await VisitStore.save(_visits);
    if (mounted) Navigator.of(context).pop(_visits);
  }

  @override
  Widget build(BuildContext context) {
    final active = _visits.where((v) => v.isActive).toList();
    final deleted = _visits.where((v) => v.isDeleted).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review countries'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCountry,
        tooltip: 'Add country',
        child: const Icon(Icons.add),
      ),
      body: active.isEmpty && deleted.isEmpty
          ? const Center(child: Text('No countries yet. Tap + to add one.'))
          : ListView(
              children: [
                if (active.isNotEmpty) ...[
                  _SectionHeader(
                    '${active.length} ${active.length == 1 ? 'country' : 'countries'} visited',
                  ),
                  ...active.map((v) {
                    final index = _visits.indexOf(v);
                    return _VisitTile(
                      visit: v,
                      onRemove: () => _remove(index),
                    );
                  }),
                ],
                if (deleted.isNotEmpty) ...[
                  const _SectionHeader('Removed (will not re-appear after scan)'),
                  ...deleted.map((v) {
                    final index = _visits.indexOf(v);
                    return _RemovedTile(
                      visit: v,
                      onUndo: () => _undoRemove(index),
                    );
                  }),
                ],
              ],
            ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: Colors.grey.shade600),
      ),
    );
  }
}

class _VisitTile extends StatelessWidget {
  const _VisitTile({required this.visit, required this.onRemove});
  final CountryVisit visit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Text(
        visit.countryCode,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
        tooltip: 'Remove ${visit.countryCode}',
        onPressed: onRemove,
      ),
      subtitle: visit.source == VisitSource.manual
          ? const Text('Added manually', style: TextStyle(fontSize: 11, color: Colors.grey))
          : null,
    );
  }
}

class _RemovedTile extends StatelessWidget {
  const _RemovedTile({required this.visit, required this.onUndo});
  final CountryVisit visit;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Text(
        visit.countryCode,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Colors.grey.shade400,
          decoration: TextDecoration.lineThrough,
        ),
      ),
      trailing: TextButton(
        onPressed: onUndo,
        child: const Text('Undo'),
      ),
    );
  }
}

// ── Add-country dialog ─────────────────────────────────────────────────────────

class _AddCountryDialog extends StatefulWidget {
  const _AddCountryDialog();

  @override
  State<_AddCountryDialog> createState() => _AddCountryDialogState();
}

class _AddCountryDialogState extends State<_AddCountryDialog> {
  final _codeController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _codeController.text.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(code)) {
      setState(() => _error = 'Enter a 2-letter ISO country code (e.g. GB, JP, US)');
      return;
    }
    final visit = CountryVisit(
      countryCode: code,
      source: VisitSource.manual,
      updatedAt: DateTime.now().toUtc(),
    );
    Navigator.of(context).pop(visit);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add country'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _codeController,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            maxLength: 2,
            decoration: InputDecoration(
              labelText: 'ISO code',
              hintText: 'e.g. GB',
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
