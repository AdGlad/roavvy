import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/providers.dart';
import 'artwork_confirmation_service.dart';
import 'card_image_renderer.dart';

const _kAmber = Color(0xFFD4A017);

/// Result returned by [ArtworkConfirmationScreen] via [Navigator.pop].
///
/// [confirmationId] is the Firestore document ID of the newly-created
/// [ArtworkConfirmation]. [bytes] is the rendered PNG for display in the next
/// screen. Null when the user dismissed without confirming (ADR-103).
class ArtworkConfirmResult {
  const ArtworkConfirmResult({
    required this.confirmationId,
    required this.bytes,
  });

  final String confirmationId;
  final Uint8List bytes;
}

/// Shows the rendered card artwork and asks the user to confirm before
/// entering the product selection / purchase flow (ADR-103 / M51-E1).
///
/// When [preRenderedResult] is provided (ADR-112), it is used directly and no
/// re-render is triggered — this guarantees the user confirms and purchases
/// exactly the image they configured in [CardGeneratorScreen].
///
/// When [preRenderedResult] is null, falls back to rendering via
/// [CardImageRenderer] (used when pre-render fails).
///
/// On confirm, creates an [ArtworkConfirmation] in Firestore and pops with
/// [ArtworkConfirmResult]. On "Change something", pops without writing.
class ArtworkConfirmationScreen extends ConsumerStatefulWidget {
  const ArtworkConfirmationScreen({
    super.key,
    required this.templateType,
    required this.countryCodes,
    this.filteredTrips = const [],
    this.dateRangeStart,
    this.dateRangeEnd,
    this.aspectRatio = 3.0 / 2.0,
    this.entryOnly = false,
    this.showUpdatedBanner = false,
    this.preRenderedResult,
  });

  final CardTemplateType templateType;
  final List<String> countryCodes;
  final List<TripRecord> filteredTrips;
  final DateTime? dateRangeStart;
  final DateTime? dateRangeEnd;
  final double aspectRatio;
  final bool entryOnly;

  /// When `true`, shows an amber banner informing the user that their artwork
  /// has been updated and they should confirm the new version (M51-E3).
  final bool showUpdatedBanner;

  /// Pre-rendered result from [CardImageRenderer] produced in
  /// [CardGeneratorScreen] before navigation (ADR-112). When non-null, the
  /// screen skips its internal render and uses these bytes directly, ensuring
  /// the confirmed image is pixel-identical to what the user selected.
  final CardRenderResult? preRenderedResult;

  @override
  ConsumerState<ArtworkConfirmationScreen> createState() =>
      _ArtworkConfirmationScreenState();
}

class _ArtworkConfirmationScreenState
    extends ConsumerState<ArtworkConfirmationScreen> {
  CardRenderResult? _result;
  bool _rendering = true;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    // ADR-112: Use pre-rendered result when provided; skip internal render.
    if (widget.preRenderedResult != null) {
      _result = widget.preRenderedResult;
      _rendering = false;
    } else {
      _startRender();
    }
  }

  Future<void> _startRender() async {
    try {
      final result = await CardImageRenderer.render(
        context,
        widget.templateType,
        codes: widget.countryCodes,
        trips: widget.filteredTrips,
        forPrint: widget.templateType == CardTemplateType.passport,
        entryOnly: widget.entryOnly,
        cardAspectRatio: widget.aspectRatio,
      );
      if (mounted) {
        setState(() {
          _result = result;
          _rendering = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _rendering = false);
    }
  }

  String _computeDateLabel() {
    if (widget.filteredTrips.isEmpty) return '';
    final years =
        widget.filteredTrips.map((t) => t.startedOn.year).toSet();
    final minYear = years.reduce(math.min);
    final maxYear = years.reduce(math.max);
    return minYear == maxYear ? '$minYear' : '$minYear\u2013$maxYear';
  }

  Future<void> _onConfirm() async {
    final result = _result;
    if (result == null || _confirming) return;
    setState(() => _confirming = true);

    try {
      final uid = ref.read(currentUidProvider);
      if (uid == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please sign in to continue')),
          );
          setState(() => _confirming = false);
        }
        return;
      }
      if (!mounted) return;

      final confirmationId = 'ac-${DateTime.now().microsecondsSinceEpoch}';
      final effectiveEntryOnly =
          widget.entryOnly || result.wasForced;

      final confirmation = ArtworkConfirmation(
        confirmationId: confirmationId,
        userId: uid,
        templateType: widget.templateType,
        aspectRatio: widget.aspectRatio,
        countryCodes: widget.countryCodes,
        countryCount: widget.countryCodes.length,
        dateLabel: _computeDateLabel(),
        dateRangeStart: widget.dateRangeStart,
        dateRangeEnd: widget.dateRangeEnd,
        entryOnly: effectiveEntryOnly,
        imageHash: result.imageHash,
        renderSchemaVersion: 'v1',
        confirmedAt: DateTime.now().toUtc(),
        status: ArtworkConfirmationStatus.confirmed,
      );

      await ArtworkConfirmationService(FirebaseFirestore.instance)
          .create(confirmation);

      if (!mounted) return;
      Navigator.of(context).pop<ArtworkConfirmResult>(
        ArtworkConfirmResult(
          confirmationId: confirmationId,
          bytes: result.bytes,
        ),
      );
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final wasForced = result?.wasForced ?? false;
    final countryCount = widget.countryCodes.length;
    final dateLabel = _computeDateLabel();
    final canConfirm = !_rendering && result != null && !_confirming;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm your artwork'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Change something',
          onPressed: () => Navigator.of(context).pop<ArtworkConfirmResult>(null),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Updated banner (M51-E3)
            if (widget.showUpdatedBanner)
              Container(
                color: _kAmber.withValues(alpha: 0.15),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 16, color: _kAmber),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'Your artwork has been updated — please confirm the new version.',
                        style: TextStyle(fontSize: 13, color: _kAmber),
                      ),
                    ),
                  ],
                ),
              ),

            // Metadata header
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Text(
                    '$countryCount ${countryCount == 1 ? 'country' : 'countries'}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _kAmber,
                    ),
                  ),
                  if (dateLabel.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      dateLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // wasForced notice
            if (wasForced &&
                widget.templateType == CardTemplateType.passport)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _kAmber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: _kAmber.withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    'Too many stamps — showing entry stamps only',
                    style: TextStyle(fontSize: 12, color: _kAmber),
                  ),
                ),
              ),

            // Artwork preview
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: _rendering
                      ? const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator.adaptive(),
                            SizedBox(height: 12),
                            Text(
                              'Rendering your artwork…',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.white54),
                            ),
                          ],
                        )
                      : result != null
                          ? Image.memory(
                              result.bytes,
                              fit: BoxFit.contain,
                            )
                          : const Text(
                              'Could not render artwork.',
                              style: TextStyle(color: Colors.white54),
                            ),
                ),
              ),
            ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: canConfirm ? _onConfirm : null,
                      child: _confirming
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator.adaptive(
                                  strokeWidth: 2),
                            )
                          : const Text('Confirm artwork'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context)
                            .pop<ArtworkConfirmResult>(null),
                    child: const Text('Change something'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
