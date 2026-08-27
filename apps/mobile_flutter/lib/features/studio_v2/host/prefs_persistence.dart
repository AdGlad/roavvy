import 'package:design_forge/design_forge.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mobile [DesignStore] for the reproducible design library, backed by the app's
/// existing `shared_preferences` infrastructure (no new persistence framework).
///
/// Satisfies the shared `design_studio` / `design_forge` persistence seam
/// ([PersistentDesignLibrary] takes a [DesignStore]). M1 provides just enough to
/// support save/reopen; the final Save-to-Library UX is a later milestone.
class PrefsDesignStore implements DesignStore {
  PrefsDesignStore({this.key = 'studio_v2_library'});

  final String key;

  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> write(String contents) async =>
      (await SharedPreferences.getInstance()).setString(key, contents);
}

/// Mobile persistence for learned [DesignPreferences], using the model's own
/// `encode()` / `decode()` over `shared_preferences`. Wired into the shared
/// controller via its injected `savePreferences` callback.
class PrefsPreferenceStore {
  PrefsPreferenceStore({this.key = 'studio_v2_preferences'});

  final String key;

  Future<void> save(DesignPreferences prefs) async =>
      (await SharedPreferences.getInstance()).setString(key, prefs.encode());

  Future<DesignPreferences?> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(key);
    return raw == null ? null : DesignPreferences.decode(raw);
  }
}
