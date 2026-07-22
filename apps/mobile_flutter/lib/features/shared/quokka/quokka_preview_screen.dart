// lib/features/shared/quokka/quokka_preview_screen.dart
//
// DEV-ONLY: test screen for all quokka sprite animations.
// Navigate to /dev/quokka to view. Remove before shipping.

import 'package:flutter/material.dart';
import 'quokka_sprite.dart';

class QuokkaPreviewScreen extends StatefulWidget {
  const QuokkaPreviewScreen({super.key});

  @override
  State<QuokkaPreviewScreen> createState() => _QuokkaPreviewScreenState();
}

class _QuokkaPreviewScreenState extends State<QuokkaPreviewScreen> {
  QuokkaState _current = QuokkaState.idle;
  bool _completed = false;

  static const _bg     = Color(0xFF0D1B2A);
  static const _card   = Color(0xFF1A2E42);
  static const _border = Color(0xFF1F4068);
  static const _gold   = Color(0xFFf5c842);
  static const _dim    = Color(0xFF5A7A9A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _card,
        elevation: 0,
        title: const Text(
          'Quokka Mascot',
          style: TextStyle(
            color: _gold,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: _gold),
      ),
      body: Column(
        children: [
          // ── Hero display ────────────────────────────────────────────────
          Container(
            color: _card,
            padding: const EdgeInsets.symmetric(vertical: 24),
            width: double.infinity,
            child: Column(
              children: [
                QuokkaSprite(
                  key: ValueKey(_current),
                  state: _current,
                  size: 200,
                  onComplete: () => setState(() => _completed = true),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _bg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _current.name.toUpperCase(),
                        style: const TextStyle(
                          color: _gold,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _bg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _current.loops
                            ? 'looping'
                            : _completed
                                ? 'done ✓'
                                : 'playing…',
                        style: TextStyle(
                          color:
                              _completed ? const Color(0xFF66EE99) : _dim,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: _border),

          // ── State selector ───────────────────────────────────────────────
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              padding: const EdgeInsets.all(16),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: QuokkaState.values.map((s) {
                final selected = s == _current;
                return _StateCard(
                  state: s,
                  selected: selected,
                  onTap: () => setState(() {
                    _current = s;
                    _completed = false;
                  }),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.state,
    required this.selected,
    required this.onTap,
  });

  final QuokkaState state;
  final bool selected;
  final VoidCallback onTap;

  static const _bg     = Color(0xFF0D1B2A);
  static const _card   = Color(0xFF1A2E42);
  static const _border = Color(0xFF1F4068);
  static const _gold   = Color(0xFFf5c842);
  static const _dim    = Color(0xFF5A7A9A);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected ? _bg : _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _gold : _border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Tiny live preview of each pose
            QuokkaSprite(state: state, size: 64),
            const SizedBox(height: 6),
            Text(
              state.name,
              style: TextStyle(
                color: selected ? _gold : _dim,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              state.loops ? 'loop' : '1×',
              style: const TextStyle(color: Color(0xFF3A5A7A), fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
