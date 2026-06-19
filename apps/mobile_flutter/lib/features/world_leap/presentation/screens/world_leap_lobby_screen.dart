// lib/features/world_leap/presentation/screens/world_leap_lobby_screen.dart
//
// Landing tab for World Leap. Shows game info and a Play button.
// The actual game (WorldLeapScreen) is pushed as a route only when the
// user taps Play, so the controller is never created until then.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'world_leap_screen.dart';

class WorldLeapLobbyScreen extends StatelessWidget {
  const WorldLeapLobbyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('EEEE, d MMMM').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1A),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '🌍',
                  style: TextStyle(fontSize: 72),
                ),
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
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 15,
                  ),
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
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const WorldLeapScreen(),
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
