import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_lookup/country_lookup.dart';
import 'package:region_lookup/region_lookup.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'app.dart';
import 'core/notification_service.dart';
import 'core/remote_config_service.dart';
import 'core/providers.dart';
import 'features/heritage/world_heritage_lookup_service.dart';
import 'data/db/roavvy_database.dart';

import 'firebase_options.dart';

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      tz.initializeTimeZones();

      try {
        await NotificationService.instance.init();

        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );

        await FirebaseAppCheck.instance.activate(
          appleProvider: kDebugMode
              ? AppleProvider.debug
              : AppleProvider.appAttestWithDeviceCheckFallback,
        );

        // Route Flutter framework errors to Crashlytics.
        FlutterError.onError =
            FirebaseCrashlytics.instance.recordFlutterFatalError;

        await RemoteConfigService.initialise();

        // On web we only serve the public landing page — SQLite is not available
        // without a WASM worker, and the landing page needs neither the DB nor
        // the geodata binary assets.  Run a minimal ProviderScope so GoRouter
        // can render the landing page without touching any native-only code.
        if (kIsWeb) {
          runApp(const ProviderScope(child: RoavvyApp()));
          return;
        }

        // ── Native (iOS / Android) path ──────────────────────────────────────

        // Configure iOS audio session before any AudioPlayer is used.
        // playback + mixWithOthers: sounds play even when the ringer switch is
        // off, and layer over background music without interrupting it.
        // Must match AppDelegate.configureAudioSession() (M111).
        await AudioPlayer.global.setAudioContext(
          AudioContext(
            iOS: AudioContextIOS(
              category: AVAudioSessionCategory.playback,
              options: {AVAudioSessionOptions.mixWithOthers},
            ),
          ),
        );

        final (countryData, regionData) =
            await (
              rootBundle.load('assets/geodata/ne_countries.bin'),
              rootBundle.load('assets/geodata/ne_admin1.bin'),
            ).wait;

        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );

        final countryBytes = countryData.buffer.asUint8List(
          countryData.offsetInBytes,
          countryData.lengthInBytes,
        );
        final regionBytes = regionData.buffer.asUint8List(
          regionData.offsetInBytes,
          regionData.lengthInBytes,
        );
        initCountryLookup(countryBytes);
        initRegionLookup(regionBytes);

        // M119: load World Heritage Site dataset (ADR-164).
        final whsJson = await rootBundle.loadString(
          'assets/geodata/whs_sites.json',
        );
        WorldHeritageLookupService.init(whsJson);

        final db = RoavvyDatabase(driftDatabase(name: 'roavvy'));

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
      } catch (e, stack) {
        debugPrint('Initialization error: $e\n$stack');
        runApp(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Failed to start Roavvy',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(e.toString(), textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed:
                            () => WidgetsBinding.instance.handleBeginFrame(
                              Duration.zero,
                            ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
    },
    (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    },
  );
}
