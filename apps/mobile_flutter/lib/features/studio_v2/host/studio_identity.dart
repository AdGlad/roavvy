import 'package:design_forge/design_forge.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Base keys for everything the Studio keeps between sessions. Never used on
/// their own after M25.1 — see [StudioOwner.storageKey].
const String kStudioLibraryKey = 'studio_v2_library';
const String kStudioPreferencesKey = 'studio_v2_preferences';

/// Who a saved design belongs to.
///
/// Deliberately NOT the same thing as a design's identity. A [DesignRecipe] is
/// identified by its own content, and a [StudioContext]'s `scopeKey` describes
/// the TRAVEL a design was made from — both are baked into `recipeId`, so an
/// account id must never reach either: it would rewrite every recipe id the
/// moment somebody signed in, and a saved design would stop reproducing.
///
/// This owns storage, and only storage:
///
/// ```text
/// Roavvy account  →  StudioOwner  →  where the wardrobe is kept
/// ```
///
/// The account id is hashed rather than stored verbatim. It is a stable,
/// opaque key — enough that a raw account identifier is not sitting in device
/// storage or in a trace line, not a security boundary.
class StudioOwner {
  const StudioOwner._(this.storageScope, {required this.isSignedIn});

  /// The owner for a Roavvy account id, or [signedOut] when there is none.
  ///
  /// Roavvy signs everyone in — anonymously at first, upgraded in place when
  /// they add Apple/Google/Facebook — so in the running app this is nearly
  /// always a real account, and the upgrade keeps the same id. A traveller who
  /// somehow has none still gets a Studio; their designs simply stay with the
  /// device.
  factory StudioOwner.of(String? uid) =>
      (uid == null || uid.isEmpty)
          ? signedOut
          : StudioOwner._('u${stableContentHash(uid)}', isSignedIn: true);

  /// No account: designs belong to this device and to nobody else.
  static const StudioOwner signedOut = StudioOwner._(
    'device',
    isSignedIn: false,
  );

  final String storageScope;
  final bool isSignedIn;

  /// Where [base] is kept for this owner. Two accounts on one phone therefore
  /// never read each other's wardrobe.
  String storageKey(String base) => '$base:$storageScope';

  @override
  bool operator ==(Object other) =>
      other is StudioOwner && other.storageScope == storageScope;

  @override
  int get hashCode => storageScope.hashCode;

  @override
  String toString() => 'StudioOwner($storageScope)';
}

/// Hands anything saved before M25.1 to the first account that opens the
/// Studio.
///
/// Those designs were written to an unscoped key, and nothing recorded who
/// made them. MOVED rather than copied, and only when the account has no
/// wardrobe of its own: one account inherits them and the legacy key is gone,
/// so the same designs can never turn up under a second account.
Future<void> adoptLegacyStudioStorage(StudioOwner owner) async {
  final prefs = await SharedPreferences.getInstance();
  for (final base in const [kStudioLibraryKey, kStudioPreferencesKey]) {
    final legacy = prefs.getString(base);
    if (legacy == null) continue;
    final scoped = owner.storageKey(base);
    if (prefs.getString(scoped) == null) await prefs.setString(scoped, legacy);
    await prefs.remove(base);
  }
}
