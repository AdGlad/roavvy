import 'package:flutter/material.dart';

import 'card_templates.dart';

/// All ISO 3166-1 alpha-2 codes for European sovereign states and territories.
const List<String> kEuropeanCodes = [
  'AL', 'AD', 'AT', 'BY', 'BE', 'BA', 'BG', 'HR', 'CY', 'CZ',
  'DK', 'EE', 'FI', 'FR', 'DE', 'GR', 'HU', 'IS', 'IE', 'IT',
  'LV', 'LI', 'LT', 'LU', 'MT', 'MD', 'MC', 'ME', 'NL', 'MK',
  'NO', 'PL', 'PT', 'RO', 'SM', 'RS', 'SK', 'SI', 'ES', 'SE',
  'CH', 'UA', 'GB', 'VA',
];

/// Split [codes] into chunks of at most [pageSize] each.
List<List<String>> _chunkCodes(List<String> codes, int pageSize) {
  final result = <List<String>>[];
  for (var i = 0; i < codes.length; i += pageSize) {
    result.add(codes.sublist(
      i,
      (i + pageSize).clamp(0, codes.length),
    ));
  }
  return result;
}

/// Preview screen: renders all European country stamps across multiple passport
/// pages, using [PassportLayoutEngine] via [PassportStampsCard].
///
/// Swipe horizontally to move between pages. Each page holds up to 15 stamps
/// so the layout engine has room to scatter them without too much overlap.
class StampPreviewScreen extends StatefulWidget {
  const StampPreviewScreen({super.key});

  @override
  State<StampPreviewScreen> createState() => _StampPreviewScreenState();
}

class _StampPreviewScreenState extends State<StampPreviewScreen> {
  static const _perPage = 15;
  final _controller = PageController();
  int _page = 0;

  late final List<List<String>> _pages = _chunkCodes(kEuropeanCodes, _perPage);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('European Stamps'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Page ${_page + 1} / ${_pages.length}',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (i) => setState(() => _page = i),
              itemCount: _pages.length,
              itemBuilder: (context, index) {
                final codes = _pages[index];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: PassportStampsCard(
                            countryCodes: codes,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _CodeChips(codes: codes),
                    ],
                  ),
                );
              },
            ),
          ),
          _PageIndicator(count: _pages.length, current: _page),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: i == current ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: i == current
                ? const Color(0xFFD4A017)
                : Colors.white24,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class _CodeChips extends StatelessWidget {
  const _CodeChips({required this.codes});

  final List<String> codes;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: codes
          .map(
            (c) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                c,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontFamily: 'Courier New',
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
