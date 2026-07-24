// lib/features/world_leap/presentation/screens/world_leap_lobby_screen.dart
//
// Landing tab for World Leap. Shows game info and a Play button.
// The actual game (WorldLeapScreen) is pushed as a route only when the
// user taps Play, so the controller is never created until then.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'world_leap_screen.dart';

class WorldLeapLobbyScreen extends StatefulWidget {
  const WorldLeapLobbyScreen({super.key});

  @override
  State<WorldLeapLobbyScreen> createState() => _WorldLeapLobbyScreenState();
}

class _WorldLeapLobbyScreenState extends State<WorldLeapLobbyScreen> {
  // Beginner mode lets the player re-aim as many times as they like before
  // firing; classic fires the instant the drag is released. Chosen here so
  // the controller is constructed with the right behaviour from the start.
  bool _beginnerMode = false;

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('EEEE, d MMMM').format(DateTime.now());
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final modeToggle = _ModeToggle(
      beginnerMode: _beginnerMode,
      onChanged: (v) => setState(() => _beginnerMode = v),
    );

    final playButton = SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => WorldLeapScreen(beginnerMode: _beginnerMode),
            fullscreenDialog: true,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.amber,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Play',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1A),
      body: SafeArea(
        child: isLandscape
            ? _LandscapeLayout(
                today: today, modeToggle: modeToggle, playButton: playButton)
            : _PortraitLayout(
                today: today, modeToggle: modeToggle, playButton: playButton),
      ),
    );
  }
}

// ── Beginner / Classic mode toggle ─────────────────────────────────────────────

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.beginnerMode, required this.onChanged});

  final bool beginnerMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeOption(
            label: 'Beginner',
            subtitle: 'Adjust aim, then fire',
            selected: beginnerMode,
            onTap: () => onChanged(true),
          ),
          _ModeOption(
            label: 'Classic',
            subtitle: 'Fires on release',
            selected: !beginnerMode,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.amber : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: selected
                    ? Colors.black.withValues(alpha: 0.7)
                    : Colors.white54,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PortraitLayout extends StatelessWidget {
  const _PortraitLayout({
    required this.today,
    required this.modeToggle,
    required this.playButton,
  });

  final String today;
  final Widget modeToggle;
  final Widget playButton;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🌍', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 24),
            const Text(
              'World Leap',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              today,
              style: const TextStyle(color: Colors.white54, fontSize: 15),
            ),
            const SizedBox(height: 24),
            const Text(
              'Launch your quokka across the globe!\nHit the target country before time runs out.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            modeToggle,
            const SizedBox(height: 28),
            playButton,
          ],
        ),
      ),
    );
  }
}

class _LandscapeLayout extends StatelessWidget {
  const _LandscapeLayout({
    required this.today,
    required this.modeToggle,
    required this.playButton,
  });

  final String today;
  final Widget modeToggle;
  final Widget playButton;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left: globe + title
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🌍', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 12),
                const Text(
                  'World Leap',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  today,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        // Right: description + mode toggle + play button
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Launch your quokka across the globe!\nHit the target country before time runs out.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                modeToggle,
                const SizedBox(height: 20),
                playButton,
              ],
            ),
          ),
        ),
      ],
    );
  }
}
