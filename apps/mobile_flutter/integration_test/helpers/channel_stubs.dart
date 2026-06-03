// T5 — Platform channel stubs for integration tests

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/scan_fixture.dart';

/// Stubs the `roavvy/photo_scan` MethodChannel to return "authorized" (3)
/// for requestPermission and no-ops for all other methods.
void stubPhotoScanPermission() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('roavvy/photo_scan'), (
        MethodCall call,
      ) async {
        switch (call.method) {
          case 'requestPermission':
            return 3; // PhotoPermissionStatus.authorized
          default:
            return null;
        }
      });
}

/// Stubs the `roavvy/photo_scan/events` EventChannel to emit fixture photo
/// records followed by a done event, then close the stream.
void stubPhotoScanStream() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockStreamHandler(
        const EventChannel('roavvy/photo_scan/events'),
        MockStreamHandler.inline(
          onListen: (Object? arguments, MockStreamHandlerEventSink events) {
            // Emit all photos in a single batch.
            events.success({
              'type': 'batch',
              'photos':
                  kFixturePhotos
                      .map((p) => Map<String, dynamic>.from(p))
                      .toList(),
            });
            // Signal completion.
            events.success({
              'type': 'done',
              'inspected': kFixturePhotoCount,
              'withLocation': kFixturePhotoCount,
            });
            events.endOfStream();
          },
        ),
      );
}

/// Stubs the share_plus MethodChannel to silently accept share calls.
void stubShareChannel() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/share'),
        (MethodCall call) async => null,
      );
}

/// Stubs the url_launcher MethodChannel to silently accept launch calls.
void stubUrlLaunchChannel() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'),
        (MethodCall call) async => true,
      );
}
