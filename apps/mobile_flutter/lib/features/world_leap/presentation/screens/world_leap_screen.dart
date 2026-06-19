// lib/features/world_leap/presentation/screens/world_leap_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile_flutter/features/world_leap/application/world_leap_providers.dart';
import 'package:mobile_flutter/features/world_leap/application/world_leap_state.dart';
import 'package:mobile_flutter/features/world_leap/domain/services/world_leap_geo_service.dart';
import 'package:mobile_flutter/features/world_leap/presentation/widgets/world_leap_map_widget.dart';
import 'package:mobile_flutter/features/world_leap/presentation/widgets/slingshot_widget.dart';
import 'package:mobile_flutter/features/world_leap/presentation/widgets/quokka_widget.dart';
import 'package:mobile_flutter/features/world_leap/presentation/widgets/world_leap_hud.dart';
import 'package:mobile_flutter/features/world_leap/presentation/widgets/world_leap_score_panel.dart';
import 'world_leap_result_screen.dart';

// ── Zoom button ───────────────────────────────────────────────────────────────

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ZoomButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class WorldLeapScreen extends ConsumerStatefulWidget {
  const WorldLeapScreen({super.key});

  @override
  ConsumerState<WorldLeapScreen> createState() => _WorldLeapScreenState();
}

class _WorldLeapScreenState extends ConsumerState<WorldLeapScreen> {
  final _geo = WorldLeapGeoService();
  final _mapKey = GlobalKey<WorldLeapMapWidgetState>();

  @override
  void initState() {
    super.initState();
    // Allow landscape while in the game — more map real estate.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    // Restore portrait lock for the rest of the app.
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncController = ref.watch(worldLeapControllerProvider);

    return asyncController.when(
      loading: () => const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not start World Leap:\n$e',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      data: (controller) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final currentState = controller.state;

              // Controller-level error (e.g. missing daily doc, network failure)
              if (currentState is WorldLeapStateError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      currentState.message,
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              // Terminal states → result screen
              if (currentState is WorldLeapStateFailed ||
                  currentState is WorldLeapStateComplete ||
                  currentState is WorldLeapStateLocked) {
                final run = currentState is WorldLeapStateFailed
                    ? currentState.run
                    : currentState is WorldLeapStateComplete
                        ? currentState.run
                        : (currentState as WorldLeapStateLocked).run;
                return WorldLeapResultScreen(
                  run: run,
                  onPlayAgain: () {
                    controller.resetRun();
                  },
                );
              }

              // Loading / idle
              if (currentState is WorldLeapStateLoading ||
                  currentState is WorldLeapStateIdle) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }

              // Active game
              final isLandscape = MediaQuery.orientationOf(context) ==
                  Orientation.landscape;
              return Stack(
                children: [
                  // Background map
                  WorldLeapMapWidget(
                      key: _mapKey,
                      controller: controller,
                      geo: _geo),

                  // Slingshot gesture layer
                  SlingshotWidget(controller: controller),

                  // Zoom buttons
                  // Portrait: bottom-right. Landscape: bottom-left (right side is HUD panel).
                  Positioned(
                    bottom: isLandscape ? 12 : 170,
                    right: isLandscape ? null : 16,
                    left: isLandscape ? 16 : null,
                    child: Column(
                      children: [
                        _ZoomButton(
                          icon: Icons.add,
                          onTap: () => _mapKey.currentState?.zoomIn(),
                        ),
                        const SizedBox(height: 8),
                        _ZoomButton(
                          icon: Icons.remove,
                          onTap: () => _mapKey.currentState?.zoomOut(),
                        ),
                      ],
                    ),
                  ),

                  // Quokka mascot
                  // Portrait: bottom-left. Landscape: bottom-left (right of zoom).
                  Positioned(
                    bottom: isLandscape ? 8 : 80,
                    left: isLandscape ? 70 : 16,
                    child: QuokkaWidget(controller: controller),
                  ),

                  // HUD — orientation-aware (portrait=top pill, landscape=right panel)
                  WorldLeapHud(controller: controller),

                  // Score panel (Landed state)
                  if (currentState is WorldLeapStateLanded)
                    WorldLeapScorePanel(
                      launch: currentState.lastLaunch,
                      onDismiss: controller.dismissScorePanel,
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
