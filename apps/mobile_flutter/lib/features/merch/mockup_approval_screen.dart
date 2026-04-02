import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/providers.dart';
import 'mockup_approval_service.dart';

/// Result returned by [MockupApprovalScreen] via [Navigator.pop].
///
/// Non-null when the user approved; null when they navigated back without
/// approving (ADR-105).
class MockupApprovalResult {
  const MockupApprovalResult({required this.mockupApprovalId});
  final String mockupApprovalId;
}

/// Asks the user to explicitly approve the product mockup before checkout is
/// initiated (ADR-105 / M53).
///
// DEPRECATED(M55): No longer in the primary commerce navigation path.
// Use LocalMockupPreviewScreen. Scheduled for deletion in M56.

/// Shows the card artwork image and three checkboxes (design, colour,
/// placement). The CTA is disabled until all visible checkboxes are checked.
/// On approval, writes a [MockupApproval] to Firestore and pops with
/// [MockupApprovalResult].
class MockupApprovalScreen extends ConsumerStatefulWidget {
  const MockupApprovalScreen({
    super.key,
    this.artworkImageBytes,
    this.artworkConfirmationId,
    required this.templateType,
    required this.variantId,
    this.placementType,
  });

  /// Rendered card artwork PNG from [ArtworkConfirmResult]. May be null when
  /// no prior artwork confirmation exists (legacy or poster-only path).
  final Uint8List? artworkImageBytes;
  final String? artworkConfirmationId;
  final CardTemplateType templateType;

  /// Shopify variant GID string (opaque, not parsed).
  final String variantId;

  /// `'front'` or `'back'` for t-shirts; null for posters. When null the
  /// placement checkbox is hidden and only 2 checkboxes are shown.
  final String? placementType;

  @override
  ConsumerState<MockupApprovalScreen> createState() =>
      _MockupApprovalScreenState();
}

class _MockupApprovalScreenState extends ConsumerState<MockupApprovalScreen> {
  bool _designChecked = false;
  bool _colourChecked = false;
  bool _placementChecked = false;
  bool _approving = false;

  bool get _showPlacement => widget.placementType != null;

  bool get _allChecked =>
      _designChecked &&
      _colourChecked &&
      (_showPlacement ? _placementChecked : true);

  Future<void> _onApprove() async {
    if (!_allChecked || _approving) return;
    setState(() => _approving = true);

    try {
      final uid = ref.read(currentUidProvider);
      if (uid == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please sign in to continue')),
          );
          setState(() => _approving = false);
        }
        return;
      }
      if (!mounted) return;

      final approvalId = 'ma-${DateTime.now().microsecondsSinceEpoch}';
      final approval = MockupApproval(
        mockupApprovalId: approvalId,
        userId: uid,
        artworkConfirmationId: widget.artworkConfirmationId,
        templateType: widget.templateType,
        variantId: widget.variantId,
        placementType: widget.placementType,
        confirmedAt: DateTime.now().toUtc(),
      );

      await MockupApprovalService(FirebaseFirestore.instance).create(approval);

      if (!mounted) return;
      Navigator.of(context).pop<MockupApprovalResult>(
        MockupApprovalResult(mockupApprovalId: approvalId),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong — please try again')),
      );
      setState(() => _approving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bytes = widget.artworkImageBytes;

    return Scaffold(
      appBar: AppBar(title: const Text('Approve your order')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Artwork preview
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: bytes != null && bytes.isNotEmpty
                          ? Image.memory(
                              bytes,
                              fit: BoxFit.contain,
                            )
                          : Container(
                              height: 120,
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: Center(
                                child: Text(
                                  'Preview unavailable',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Please confirm your choices before we create your order:',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),

                  // Design checkbox
                  CheckboxListTile(
                    value: _designChecked,
                    onChanged: (v) =>
                        setState(() => _designChecked = v ?? false),
                    title: const Text('My card design looks exactly right'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),

                  // Colour checkbox
                  CheckboxListTile(
                    value: _colourChecked,
                    onChanged: (v) =>
                        setState(() => _colourChecked = v ?? false),
                    title:
                        const Text('The colour and style I\'ve chosen is correct'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),

                  // Placement checkbox (t-shirts only)
                  if (_showPlacement)
                    CheckboxListTile(
                      value: _placementChecked,
                      onChanged: (v) =>
                          setState(() => _placementChecked = v ?? false),
                      title: const Text('The placement looks right'),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),

            // CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: FilledButton(
                onPressed: _allChecked && !_approving ? _onApprove : null,
                child: _approving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Approve and buy'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
