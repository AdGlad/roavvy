import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/country_names.dart';
import '../../data/achievement_repository.dart';
import '../../data/firestore_sync_service.dart';
import '../../data/trip_repository.dart';
import '../../data/visit_repository.dart';

/// Lets the user correct the detected visited-country list before it is saved.
///
/// - Tap the delete icon to remove a country (writes a [UserRemovedCountry]
///   tombstone so the next scan does not re-add it automatically).
/// - Tap the FAB to add a country that was not detected (writes a
///   [UserAddedCountry] record).
/// - Tap Save to persist only the delta (new adds and removals) and return.
///
/// The screen operates on a local copy of [initialVisits]; nothing is written
/// until Save is tapped.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    required this.initialVisits,
    required this.repository,
    this.syncService,
    this.uid,
    this.achievementRepo,
    this.tripRepo,
  });

  /// The effective (already-merged) visits to start the review with.
  final List<EffectiveVisitedCountry> initialVisits;

  /// Repository used to persist the delta on Save.
  final VisitRepository repository;

  /// Sync service used to flush dirty records after saving edits (ADR-030).
  /// Pass [NoOpSyncService] in widget tests. When null, no sync is triggered.
  final SyncService? syncService;

  /// Firebase UID of the current user. When null, no sync is triggered.
  final String? uid;

  /// Achievement repository used to evaluate and persist newly unlocked
  /// achievements after saves. When null, no achievement evaluation runs.
  final AchievementRepository? achievementRepo;

  /// Trip repository used to flush dirty trips to Firestore after saves.
  /// When null, trip sync is skipped.
  final TripRepository? tripRepo;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late final List<_ReviewItem> _items;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _items = widget.initialVisits
        .map(_ReviewItem.fromEffective)
        .toList()
      ..sort((a, b) => a.countryCode.compareTo(b.countryCode));
  }

  void _remove(int index) {
    setState(() => _items[index].isPendingRemoval = true);
  }

  void _undoRemove(int index) {
    setState(() => _items[index].isPendingRemoval = false);
  }

  Future<void> _addCountry() async {
    final code = await showDialog<String>(
      context: context,
      builder: (_) => const _AddCountryDialog(),
    );
    if (code == null) return;
    setState(() {
      final existing = _items.indexWhere((i) => i.countryCode == code);
      if (existing >= 0) {
        // If it was pending removal, undo that instead of adding a duplicate.
        _items[existing].isPendingRemoval = false;
      } else {
        _items.add(_ReviewItem.newCountry(code));
        _items.sort((a, b) => a.countryCode.compareTo(b.countryCode));
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final now = DateTime.now().toUtc();

    try {
      // Snapshot prior achievement IDs before writing the delta.
      final achievementRepo = widget.achievementRepo;
      final priorIds = achievementRepo != null
          ? (await achievementRepo.loadAll()).toSet()
          : const <String>{};

      for (final item in _items) {
        if (item.isNewlyAdded && !item.isPendingRemoval) {
          await widget.repository.saveAdded(
            UserAddedCountry(countryCode: item.countryCode, addedAt: now),
          );
        } else if (!item.isNewlyAdded && item.isPendingRemoval) {
          await widget.repository.saveRemoved(
            UserRemovedCountry(countryCode: item.countryCode, removedAt: now),
          );
        }
      }

      // Evaluate achievements against the updated effective visit list.
      final effective = await widget.repository.loadEffective();
      Set<String> newlyUnlockedIds = {};
      if (achievementRepo != null) {
        final unlockedIds = AchievementEngine.evaluate(effective);
        newlyUnlockedIds = unlockedIds.difference(priorIds);
        if (newlyUnlockedIds.isNotEmpty) {
          await achievementRepo.upsertAll(newlyUnlockedIds, now);
        }
      }

      // Flush dirty records to Firestore fire-and-forget (ADR-030).
      final uid = widget.uid;
      final syncService = widget.syncService;
      if (uid != null && syncService != null) {
        unawaited(syncService.flushDirty(uid, widget.repository,
            achievementRepo: achievementRepo, tripRepo: widget.tripRepo));
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _items.where((i) => i.isActive).toList();
    final removed = _items.where((i) => i.isPendingRemoval).toList();

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
      body: active.isEmpty && removed.isEmpty
          ? const Center(child: Text('No countries yet. Tap + to add one.'))
          : ListView(
              children: [
                if (active.isNotEmpty) ...[
                  _SectionHeader(
                    '${active.length} ${active.length == 1 ? 'country' : 'countries'} visited',
                  ),
                  ...active.map((item) {
                    final index = _items.indexOf(item);
                    return _VisitTile(
                      item: item,
                      onRemove: () => _remove(index),
                    );
                  }),
                ],
                if (removed.isNotEmpty) ...[
                  const _SectionHeader('Removed (will not re-appear after scan)'),
                  ...removed.map((item) {
                    final index = _items.indexOf(item);
                    return _RemovedTile(
                      item: item,
                      onUndo: () => _undoRemove(index),
                    );
                  }),
                ],
              ],
            ),
    );
  }
}

// ── Internal model ────────────────────────────────────────────────────────────

class _ReviewItem {
  _ReviewItem.fromEffective(EffectiveVisitedCountry v)
      : countryCode = v.countryCode,
        isManual = !v.hasPhotoEvidence,
        isNewlyAdded = false,
        isPendingRemoval = false;

  _ReviewItem.newCountry(String code)
      : countryCode = code,
        isManual = true,
        isNewlyAdded = true,
        isPendingRemoval = false;

  final String countryCode;

  /// True when the country has no photo evidence (manually added previously
  /// or newly added in this session). Drives the "Added manually" subtitle.
  final bool isManual;

  /// True when the user added this country during the current review session.
  final bool isNewlyAdded;

  /// True when the user has marked this country for removal in this session.
  bool isPendingRemoval;

  bool get isActive => !isPendingRemoval;
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
  const _VisitTile({required this.item, required this.onRemove});
  final _ReviewItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final name = kCountryNames[item.countryCode] ?? item.countryCode;
    return ListTile(
      title: Text(name),
      subtitle: Text(
        item.isManual ? '${item.countryCode} · Added manually' : item.countryCode,
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
        tooltip: 'Remove ${item.countryCode}',
        onPressed: onRemove,
      ),
    );
  }
}

class _RemovedTile extends StatelessWidget {
  const _RemovedTile({required this.item, required this.onUndo});
  final _ReviewItem item;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final name = kCountryNames[item.countryCode] ?? item.countryCode;
    return ListTile(
      title: Text(
        name,
        style: TextStyle(
          color: Colors.grey.shade400,
          decoration: TextDecoration.lineThrough,
        ),
      ),
      subtitle: Text(
        item.countryCode,
        style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
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
    Navigator.of(context).pop(code);
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
