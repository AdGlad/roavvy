import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/globe_overlay.dart';
import '../../core/providers.dart';
import 'travel_replay_engine.dart';

/// Bottom sheet that lets the user pick a replay mode and start the replay.
///
/// M110: calls [ReplayTimelineBuilder] to pre-compute achievement and stat
/// overlay events before launching [GlobeReplayWidget].
///
/// M111: calls [ReplayPacingRules.buildPacingList] to pre-compute per-leg
/// cinematic timing based on great-circle arc distance.
///
/// Call via [showReplayEntrySheet].
class ReplayEntrySheet extends ConsumerStatefulWidget {
  const ReplayEntrySheet({super.key});

  @override
  ConsumerState<ReplayEntrySheet> createState() => _ReplayEntrySheetState();
}

class _ReplayEntrySheetState extends ConsumerState<ReplayEntrySheet> {
  TravelReplayMode _mode = TravelReplayMode.allTime;

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(tripListProvider);
    final unlockedAsync = ref.watch(unlockedAchievementIdsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle.
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Travel Replay',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            const Text(
              'Watch your journey unfold on the globe',
              style: TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Mode picker.
            _ModePicker(
              selected: _mode,
              onChanged: (m) => setState(() => _mode = m),
            ),

            const SizedBox(height: 12),

            // Leg count preview.
            tripsAsync.when(
              data: (trips) {
                final script = TravelReplayScriptBuilder.build(
                    trips: trips, mode: _mode);
                return Text(
                  '${script.legs.length} travel ${script.legs.length == 1 ? 'leg' : 'legs'}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 20),

            // Play button — waits for both trips and unlocked IDs.
            tripsAsync.when(
              data: (trips) {
                final unlockedIds = unlockedAsync.valueOrNull ?? const <String>{};
                final baseScript = TravelReplayScriptBuilder.build(
                    trips: trips, mode: _mode);

                // Pre-compute overlay events.
                final timeline = ReplayTimelineBuilder.build(
                  legs: baseScript.legs,
                  allTrips: trips,
                  unlockedIds: unlockedIds,
                  mode: _mode,
                );
                // Pre-compute distance-aware pacing (M111).
                final pacing = ReplayPacingRules.buildPacingList(baseScript);
                final script = TravelReplayScript(
                  legs: baseScript.legs,
                  mode: baseScript.mode,
                  label: baseScript.label,
                  overlayEvents: timeline.events,
                  summaryStats: timeline.summary,
                  legPacing: pacing,
                );

                return FilledButton.icon(
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Play Replay'),
                  onPressed: script.isEmpty
                      ? null
                      : () {
                          // M134: show replay via MainShell overlay — no route push.
                          Navigator.of(context).pop(); // close sheet
                          ref.read(globeOverlayProvider.notifier).showReplay(
                            script,
                            onDone: () =>
                                ref.read(globeOverlayProvider.notifier).hide(),
                          );
                        },
                );
              },
              loading: () => FilledButton.icon(
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Play Replay'),
                onPressed: null,
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModePicker extends StatelessWidget {
  const _ModePicker({required this.selected, required this.onChanged});
  final TravelReplayMode selected;
  final ValueChanged<TravelReplayMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _chip(context, TravelReplayMode.allTime, 'All Time'),
        const SizedBox(width: 8),
        _chip(context, TravelReplayMode.year, '${DateTime.now().year}'),
      ],
    );
  }

  Widget _chip(BuildContext context, TravelReplayMode mode, String label) {
    final isSelected = selected == mode;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onChanged(mode),
    );
  }
}

/// Shows [ReplayEntrySheet] as a modal bottom sheet.
Future<void> showReplayEntrySheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const ReplayEntrySheet(),
  );
}
