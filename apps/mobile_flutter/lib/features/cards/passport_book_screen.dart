import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_models/shared_models.dart';
import 'package:turnable_page/turnable_page.dart';

import 'passport_pdf_service.dart';

/// Full-screen in-app preview of the Passport Book PDF.
///
/// Generates the PDF on open (serial page rendering — ADR-140 §5),
/// shows rendered pages in a horizontal [PageView], and provides a
/// "Share PDF" button that exports the assembled PDF via the system sheet.
class PassportBookScreen extends StatefulWidget {
  const PassportBookScreen({
    super.key,
    required this.trips,
    required this.countryCodes,
  });

  final List<TripRecord> trips;
  final List<String> countryCodes;

  @override
  State<PassportBookScreen> createState() => _PassportBookScreenState();
}

enum _BookState { loading, ready, error }

class _PassportBookScreenState extends State<PassportBookScreen> {
  _BookState _state = _BookState.loading;
  List<Uint8List> _pages = const [];
  Uint8List? _pdfBytes;
  int _currentPage = 0;
  bool _sharing = false;
  final _flipController = PageFlipController();

  @override
  void initState() {
    super.initState();
    _generate();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() => _state = _BookState.loading);
    try {
      final result = await PassportPdfService.generate(
        widget.trips,
        widget.countryCodes,
      );
      if (!mounted) return;
      setState(() {
        _pages = result.pages;
        _pdfBytes = result.pdfBytes;
        _state = _BookState.ready;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _state = _BookState.error);
    }
  }

  Future<void> _share() async {
    if (_sharing || _pdfBytes == null) return;
    setState(() => _sharing = true);
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/roavvy_passport.pdf');
      await file.writeAsBytes(_pdfBytes!);
      if (!mounted) return;
      final screenSize = MediaQuery.sizeOf(context);
      final topPadding = MediaQuery.paddingOf(context).top;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'My Passport Book — Roavvy',
        sharePositionOrigin: Rect.fromLTWH(
          screenSize.width - 48,
          topPadding + 8,
          44,
          44,
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1628),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Passport Book',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: switch (_state) {
        _BookState.loading => _buildLoading(),
        _BookState.error => _buildError(),
        _BookState.ready => _buildReady(),
      },
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator.adaptive(),
          SizedBox(height: 16),
          Text(
            'Generating your passport…',
            style: TextStyle(fontSize: 15, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.white38),
          const SizedBox(height: 12),
          const Text(
            'Failed to generate passport.',
            style: TextStyle(fontSize: 15, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _generate,
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  Widget _buildReady() {
    return Column(
      children: [
        Expanded(
          child: TurnablePage(
            controller: _flipController,
            pageCount: _pages.length,
            pageViewMode: PageViewMode.single,
            paperBoundaryDecoration: PaperBoundaryDecoration.modern,
            settings: FlipSettings(
              flippingTime: 600,
              swipeDistance: 60.0,
            ),
            onPageChanged: (left, right) =>
                setState(() => _currentPage = left),
            builder: (context, i, constraints) =>
                Image.memory(_pages[i], fit: BoxFit.fill),
          ),
        ),
        _BottomBar(
          current: _currentPage,
          total: _pages.length,
          sharing: _sharing,
          onShare: _share,
        ),
      ],
    );
  }
}

// ── Bottom bar ────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.current,
    required this.total,
    required this.sharing,
    required this.onShare,
  });

  final int current;
  final int total;
  final bool sharing;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding + 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Page ${current + 1} of $total',
              style: const TextStyle(fontSize: 13, color: Colors.white54),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: sharing ? null : onShare,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD4A017),
              foregroundColor: Colors.black,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            icon: sharing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black54,
                    ),
                  )
                : const Icon(Icons.picture_as_pdf_outlined, size: 16),
            label: const Text(
              'Share PDF',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
