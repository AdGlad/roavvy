/// The shell's tabs, addressed by name (ADR-052, ADR-180).
///
/// Notifications and deep links name a tab (`tab:stats`) rather than an index,
/// because the set of visible tabs depends on whether commerce is built in:
/// with commerce off there is no Shop and Play moves up one place.
enum AppTab {
  map,
  journey,
  stats,
  shop,
  play;

  /// Notification payload for this tab, e.g. `tab:stats`.
  String get payload => 'tab:$name';

  /// Parses the part after `tab:`. Accepts a tab name, or a legacy index from
  /// the five-tab layout (0 Map · 1 Journey · 2 Stats · 3 Shop · 4 Play) for
  /// notifications scheduled by older builds. Returns null if unrecognised.
  static AppTab? parse(String value) {
    for (final t in AppTab.values) {
      if (t.name == value) return t;
    }
    final i = int.tryParse(value);
    if (i == null || i < 0 || i >= AppTab.values.length) return null;
    return AppTab.values[i];
  }

  /// Parses a full `tab:<x>` payload, or returns null.
  static AppTab? fromPayload(String? payload) {
    if (payload == null || !payload.startsWith('tab:')) return null;
    return parse(payload.substring(4));
  }

  /// The tabs shown in the shell, in order. Shop only exists with commerce.
  static List<AppTab> visible({required bool commerce}) => [
    for (final t in AppTab.values)
      if (t != AppTab.shop || commerce) t,
  ];

  /// [requested] if it is visible, otherwise Map.
  static AppTab resolve(AppTab requested, {required bool commerce}) =>
      visible(commerce: commerce).contains(requested) ? requested : AppTab.map;
}
