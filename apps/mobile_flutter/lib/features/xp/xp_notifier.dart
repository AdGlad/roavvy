import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/xp_repository.dart';
import 'xp_event.dart';

/// Manages XP state, level computation, and award notifications.
///
/// Callers should use `unawaited(ref.read(xpNotifierProvider.notifier).award(event))`
/// to award XP without blocking or risking caller failure (ADR Task 83).
class XpNotifier extends StateNotifier<XpState> {
  XpNotifier(this._repo) : super(XpState.zero) {
    _init();
  }

  final XpRepository _repo;

  /// Emits the amount of XP earned each time [award] is called successfully.
  final _xpEarnedController = StreamController<int>.broadcast(sync: true);
  Stream<int> get xpEarned => _xpEarnedController.stream;

  Future<void> _init() async {
    try {
      final total = await _repo.totalXp();
      if (mounted) state = xpStateFromTotal(total);
    } catch (_) {
      // XP load failure is non-fatal; start at zero.
    }
  }

  /// Awards [event] and updates state.
  ///
  /// Safe to call with `unawaited()` — never throws to the caller.
  Future<void> award(XpEvent event) async {
    try {
      await _repo.award(event);
      final total = await _repo.totalXp();
      if (mounted) {
        state = xpStateFromTotal(total);
        _xpEarnedController.add(event.amount);
      }
    } catch (e) {
      // XP loss is recoverable; log and swallow.
      assert(() {
        // ignore: avoid_print
        print('[XpNotifier] award failed: $e');
        return true;
      }());
    }
  }

  @override
  void dispose() {
    _xpEarnedController.close();
    super.dispose();
  }
}
