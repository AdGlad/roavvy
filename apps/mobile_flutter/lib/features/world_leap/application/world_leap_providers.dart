// lib/features/world_leap/application/world_leap_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'package:mobile_flutter/features/world_leap/application/world_leap_analytics_service.dart';
import 'package:mobile_flutter/features/world_leap/application/world_leap_controller.dart';
import 'package:mobile_flutter/features/world_leap/application/world_leap_daily_service.dart';
import 'package:mobile_flutter/features/world_leap/application/world_leap_state.dart';
import 'package:mobile_flutter/features/world_leap/data/repositories/world_leap_run_repository.dart';
import 'package:mobile_flutter/features/world_leap/domain/services/world_leap_country_service.dart';
import 'package:mobile_flutter/features/world_leap/domain/services/world_leap_geo_service.dart';
import 'package:mobile_flutter/features/world_leap/domain/services/world_leap_heritage_bonus_service.dart';
import 'package:mobile_flutter/features/world_leap/domain/services/world_leap_scoring_service.dart';
import 'package:mobile_flutter/features/world_leap/presentation/audio/world_leap_audio_service.dart';

String worldLeapTodayDate() => DateFormat('yyyy-MM-dd').format(DateTime.now());

/// Provides a fully-wired [WorldLeapController] for today's game.
/// Created as AutoDispose so it tears down when the tab is not visible.
final worldLeapControllerProvider = FutureProvider.autoDispose<WorldLeapController>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final firestore = FirebaseFirestore.instance;
  final geo = WorldLeapGeoService();
  final countryService = const WorldLeapCountryService();

  final heritage = await WorldLeapHeritageBonusService.load(geo);
  final scoring = WorldLeapScoringService(heritage);
  final dailyService = WorldLeapFirestoreDailyService(firestore, prefs);
  final repository = WorldLeapRunRepository(firestore: firestore, prefs: prefs);

  final audio = WorldLeapAudioService();
  await audio.init(prefs);

  final analytics = WorldLeapAnalyticsService(const DebugAnalyticsLogger());

  final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  final date = worldLeapTodayDate();

  final controller = WorldLeapController(
    userId: userId,
    date: date,
    dailyService: dailyService,
    repository: repository,
    geo: geo,
    countryService: countryService,
    scoring: scoring,
  );

  controller.addListener(() {
    audio.playForState(controller.state);
    analytics.logForState(controller.state);
    // Tick sound during countdown (only when aiming, only last 5 seconds).
    if (controller.state is WorldLeapStateAiming &&
        controller.timeRemaining > 0 &&
        controller.timeRemaining <= 5) {
      audio.playTick();
    }
  });

  // Stretch creak when user pulls the slingshot (throttled inside playStretch).
  controller.aimNotifier.addListener(() {
    final aim = controller.aimNotifier.value;
    if (aim != null) audio.playStretch(aim.power);
  });

  ref.onDispose(() {
    controller.dispose();
    audio.dispose();
  });

  await controller.initialize();
  return controller;
});
