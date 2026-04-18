import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_lookup/country_lookup.dart';
import 'package:region_lookup/region_lookup.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'app.dart';
import 'core/notification_service.dart';
import 'core/providers.dart';
import 'data/achievement_repository.dart';
import 'data/bootstrap_service.dart';
import 'data/db/roavvy_database.dart';
import 'data/firestore_sync_service.dart';
import 'data/region_repository.dart';
import 'data/trip_repository.dart';
import 'data/visit_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Override audioplayers' default .playAndRecord session so audio plays
  // through the speaker even when the ringer switch is off (ADR-124).
  await AudioPlayer.global.setAudioContext(AudioContext(
    iOS: AudioContextIOS(category: AVAudioSessionCategory.playback),
  ));
  tz.initializeTimeZones();
  await NotificationService.instance.init();
  final (countryData, regionData, _) = await (
    rootBundle.load('assets/geodata/ne_countries.bin'),
    rootBundle.load('assets/geodata/ne_admin1.bin'),
    Firebase.initializeApp(),
  ).wait;
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  final countryBytes =
      countryData.buffer.asUint8List(countryData.offsetInBytes, countryData.lengthInBytes);
  final regionBytes =
      regionData.buffer.asUint8List(regionData.offsetInBytes, regionData.lengthInBytes);
  initCountryLookup(countryBytes);
  initRegionLookup(regionBytes);
  final db = RoavvyDatabase(driftDatabase(name: 'roavvy'));
  final visitRepo = VisitRepository(db);
  final tripRepo = TripRepository(db);
  final regionRepo = RegionRepository(db);

  // Synthesise one trip per country for users upgrading from pre-v6 schema
  // who have no photo_date_records yet (ADR-048).
  await bootstrapExistingUser(visitRepo, tripRepo, regionRepo: regionRepo);

  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid != null) {
    unawaited(FirestoreSyncService().flushDirty(
      uid,
      visitRepo,
      achievementRepo: AchievementRepository(db),
      tripRepo: tripRepo,
    ));
  }
  runApp(
    ProviderScope(
      overrides: [
        geodataBytesProvider.overrideWithValue(countryBytes),
        regionGeodataBytesProvider.overrideWithValue(regionBytes),
        roavvyDatabaseProvider.overrideWithValue(db),
      ],
      child: const RoavvyApp(),
    ),
  );
}
