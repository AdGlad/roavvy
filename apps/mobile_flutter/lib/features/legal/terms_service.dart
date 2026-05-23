import 'package:shared_preferences/shared_preferences.dart';

/// The current Terms & Conditions version string.
///
/// Bump this (e.g. '1.1', '2.0') whenever the T&C content changes.
/// Existing users will be re-prompted to accept on next app launch.
const kCurrentTermsVersion = '1.0';

const _kPrefsKey = 'terms_accepted_version';

/// Reads and writes the accepted T&C version to SharedPreferences.
class TermsService {
  const TermsService._();

  /// Returns true when the user has accepted the current T&C version.
  static Future<bool> hasAcceptedCurrent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kPrefsKey) == kCurrentTermsVersion;
  }

  /// Saves the current T&C version as accepted.
  static Future<void> acceptCurrent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsKey, kCurrentTermsVersion);
  }

  /// Clears the stored acceptance (used for testing / account deletion).
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefsKey);
  }
}
