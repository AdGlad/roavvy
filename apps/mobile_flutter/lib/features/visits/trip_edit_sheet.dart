import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/providers.dart';

/// Modal bottom sheet for adding or editing a manual trip.
///
/// Pass [existingTrip] to open in edit mode (pre-populates the date fields
/// and reuses the existing trip id on save). Omit it for add mode.
///
/// The sheet pops with `true` on a successful save and `null` on cancel.
class TripEditSheet extends ConsumerStatefulWidget {
  const TripEditSheet({
    super.key,
    required this.countryCode,
    this.existingTrip,
    this.initialStartDate,
    this.initialEndDate,
  });

  final String countryCode;
  final TripRecord? existingTrip;

  /// Bypass the date picker in widget tests by pre-setting a start date.
  final DateTime? initialStartDate;

  /// Bypass the date picker in widget tests by pre-setting an end date.
  final DateTime? initialEndDate;

  @override
  ConsumerState<TripEditSheet> createState() => _TripEditSheetState();
}

class _TripEditSheetState extends ConsumerState<TripEditSheet> {
  late DateTime? _startDate;
  late DateTime? _endDate;
  String? _error;
  bool _saving = false;

  bool get _isEditMode => widget.existingTrip != null;

  @override
  void initState() {
    super.initState();
    _startDate = widget.existingTrip?.startedOn.toLocal() ?? widget.initialStartDate;
    _endDate = widget.existingTrip?.endedOn.toLocal() ?? widget.initialEndDate;
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _startDate = picked;
      _error = null;
    });
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _endDate = picked;
      _error = null;
    });
  }

  Future<void> _save() async {
    final start = _startDate;
    final end = _endDate;

    if (start == null) {
      setState(() => _error = 'Please select a start date');
      return;
    }
    if (end == null) {
      setState(() => _error = 'Please select an end date');
      return;
    }
    if (end.isBefore(start)) {
      setState(() => _error = 'End date must be on or after start date');
      return;
    }

    setState(() => _saving = true);

    final id = _isEditMode ? widget.existingTrip!.id : 'manual_${_randomHex()}';
    final trip = TripRecord(
      id: id,
      countryCode: widget.countryCode,
      startedOn: DateTime.utc(start.year, start.month, start.day),
      endedOn: DateTime.utc(end.year, end.month, end.day),
      photoCount: 0,
      isManual: true,
    );

    await ref.read(tripRepositoryProvider).upsertAll([trip]);
    if (mounted) Navigator.of(context).pop(true);
  }

  static String _randomHex() {
    final r = Random();
    return List.generate(8, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _fmtDate(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditMode ? 'Edit trip' : 'Add trip',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            _DateRow(
              label: 'Start date',
              date: _startDate,
              formatDate: _fmtDate,
              onTap: _pickStart,
            ),
            const SizedBox(height: 12),
            _DateRow(
              label: 'End date',
              date: _endDate,
              formatDate: _fmtDate,
              onTap: _pickEnd,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ─────────────────────────────────────────────────────────────

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.date,
    required this.formatDate,
    required this.onTap,
  });

  final String label;
  final DateTime? date;
  final String Function(DateTime) formatDate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 2),
                  Text(
                    date != null ? formatDate(date!) : 'Tap to select',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            const Icon(Icons.calendar_today_outlined),
          ],
        ),
      ),
    );
  }
}
