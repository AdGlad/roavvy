import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

/// Opens the device's native maps application with a destination pin.
///
/// - iOS: Apple Maps (`maps.apple.com/?daddr=…`)
/// - Android: Google Maps navigation intent, falling back to `maps.google.com`
///
/// No routing data is returned to Roavvy. Turn-by-turn navigation is
/// delegated entirely to the native maps app. (ADR-015)
class NativeMapsLauncher {
  NativeMapsLauncher._();

  /// Opens native maps with a destination at [lat], [lng].
  ///
  /// [label] is used as the destination label on Android where supported.
  /// Returns `true` if the URL was successfully launched.
  static Future<bool> open(double lat, double lng, String label) async {
    if (Platform.isIOS) {
      return _launch(
        'https://maps.apple.com/?daddr=$lat,$lng&dirflg=d',
      );
    }

    // Android: try Google Maps navigation intent first.
    final googleIntent = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    if (await canLaunchUrl(googleIntent)) {
      return launchUrl(googleIntent);
    }

    // Fallback: browser-based Google Maps URL.
    final encodedLabel = Uri.encodeComponent(label);
    return _launch(
      'https://maps.google.com/?daddr=$lat,$lng&destination=$encodedLabel',
    );
  }

  static Future<bool> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }
}
