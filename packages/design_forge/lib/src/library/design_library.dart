import 'dart:convert';

import '../recipe/design_recipe.dart';
import '../recipe/garment_design.dart';

/// Abstract local persistence for the design library — the engine core stays
/// free of `dart:io` and platform APIs. Each host supplies its own:
///   • macOS Design Lab → a JSON file on disk;
///   • the iPhone app → a file in the app's documents directory (path_provider);
///   • tests → an in-memory store.
abstract class DesignStore {
  /// The persisted library JSON, or null if nothing has been saved yet.
  Future<String?> read();

  /// Persist the library JSON.
  Future<void> write(String contents);
}

/// A design the user chose to keep: the **full reproducible recipe** plus how it
/// was used. Because a [DesignRecipe] is deterministic and self-contained, the
/// recipe alone re-renders the exact image at any resolution later — no raster
/// needs to be stored. [id] is the recipe's content hash.
class SavedDesign {
  const SavedDesign({
    required this.recipe,
    this.garment,
    this.liked = false,
    this.usedForTshirt = false,
    this.rejected = false,
    required this.savedAtEpochMs,
    this.usedAtEpochMs,
    this.note,
    this.reason,
  });

  final DesignRecipe recipe;

  /// The full two-face garment (front + back + shared garment colour/theme) when
  /// this entry was saved from the T-Shirt Studio's Review step. Null for legacy
  /// single-face ♥ likes. When present it carries EVERYTHING needed to reproduce
  /// BOTH printed sides deterministically (see [GarmentDesign.garmentId]); the
  /// single-face [recipe] is kept as the back/hero for backward compatibility.
  final GarmentDesign? garment;

  /// The user "hearted" this design.
  final bool liked;

  /// This design was used to order/print an actual t-shirt.
  final bool usedForTshirt;

  /// The user tagged this design for deletion ("I don't like it"). Kept until
  /// the batch learner has processed it, so the engine can learn to avoid it.
  final bool rejected;

  /// Optional free-text/quick-pick reason the user disliked it.
  final String? reason;

  final int savedAtEpochMs;
  final int? usedAtEpochMs;
  final String? note;

  /// Content-hash id (stable across sessions and re-renders). A two-face garment
  /// is keyed by its composite [GarmentDesign.garmentId] (covers both faces +
  /// colour), so re-saving the same garment updates ONE entry — no duplicates.
  /// A single-face like keeps the recipe's own content hash.
  String get id => garment?.garmentId ?? recipe.recipeId;

  SavedDesign copyWith({
    bool? liked,
    bool? usedForTshirt,
    bool? rejected,
    int? usedAtEpochMs,
    String? note,
    String? reason,
  }) =>
      SavedDesign(
        recipe: recipe,
        garment: garment,
        liked: liked ?? this.liked,
        usedForTshirt: usedForTshirt ?? this.usedForTshirt,
        rejected: rejected ?? this.rejected,
        savedAtEpochMs: savedAtEpochMs,
        usedAtEpochMs: usedAtEpochMs ?? this.usedAtEpochMs,
        note: note ?? this.note,
        reason: reason ?? this.reason,
      );

  Map<String, Object?> toJson() => {
        'recipe': recipe.toJson(),
        if (garment != null) 'garment': garment!.toJson(),
        if (liked) 'liked': true,
        if (usedForTshirt) 'usedForTshirt': true,
        if (rejected) 'rejected': true,
        'savedAt': savedAtEpochMs,
        if (usedAtEpochMs != null) 'usedAt': usedAtEpochMs,
        if (note != null) 'note': note,
        if (reason != null) 'reason': reason,
      };

  factory SavedDesign.fromJson(Map<String, Object?> j) => SavedDesign(
        recipe: DesignRecipe.fromJson((j['recipe'] as Map).cast<String, Object?>()),
        garment: j['garment'] == null
            ? null
            : GarmentDesign.fromJson((j['garment'] as Map).cast<String, Object?>()),
        liked: j['liked'] == true,
        usedForTshirt: j['usedForTshirt'] == true,
        rejected: j['rejected'] == true,
        savedAtEpochMs: (j['savedAt'] as num?)?.toInt() ?? 0,
        usedAtEpochMs: (j['usedAt'] as num?)?.toInt(),
        note: j['note'] as String?,
        reason: j['reason'] as String?,
      );
}

/// An in-memory collection of [SavedDesign]s keyed by recipe id, with
/// JSON (de)serialisation. Pure data — the host owns persistence via a
/// [DesignStore] (see [PersistentDesignLibrary]).
///
/// Policy: a design is only kept while it is *selected* (liked or used for a
/// t-shirt). Un-liking a design that was never used drops it entirely, so the
/// library never accumulates the whole generated batch — only what the user chose.
class DesignLibrary {
  DesignLibrary([Iterable<SavedDesign> entries = const []])
      : _byId = {for (final e in entries) e.id: e};

  static const schemaVersion = 1;
  final Map<String, SavedDesign> _byId;

  /// All kept designs, newest first.
  List<SavedDesign> get entries => _byId.values.toList()
    ..sort((a, b) => b.savedAtEpochMs.compareTo(a.savedAtEpochMs));

  List<SavedDesign> get liked => entries.where((e) => e.liked).toList();

  /// Designs used to order/print real t-shirts, most recently used first.
  List<SavedDesign> get usedForTshirt {
    final out = entries.where((e) => e.usedForTshirt).toList();
    out.sort((a, b) => (b.usedAtEpochMs ?? b.savedAtEpochMs)
        .compareTo(a.usedAtEpochMs ?? a.savedAtEpochMs));
    return out;
  }

  /// Designs the user tagged for deletion ("don't like"), newest first — the
  /// batch the learner reworks the generator from.
  List<SavedDesign> get rejected => entries.where((e) => e.rejected).toList();

  bool isLiked(String id) => _byId[id]?.liked ?? false;
  bool isUsedForTshirt(String id) => _byId[id]?.usedForTshirt ?? false;
  bool isRejected(String id) => _byId[id]?.rejected ?? false;
  bool contains(String id) => _byId.containsKey(id);
  SavedDesign? get(String id) => _byId[id];
  int get length => _byId.length;

  /// Heart a design — stores its full recipe so it can be reproduced later.
  void like(DesignRecipe recipe, {required int nowMs}) {
    final existing = _byId[recipe.recipeId];
    _byId[recipe.recipeId] = existing?.copyWith(liked: true, rejected: false) ??
        SavedDesign(recipe: recipe, liked: true, savedAtEpochMs: nowMs);
  }

  /// Save a two-face [GarmentDesign] (the T-Shirt Studio Review step). Stores the
  /// FULL garment so both printed faces reproduce deterministically. Idempotent
  /// by [GarmentDesign.garmentId]: re-saving the same garment updates the one
  /// entry rather than accumulating duplicates. A no-op when the garment carries
  /// no artwork on either face.
  void likeGarment(GarmentDesign g, {required int nowMs}) {
    final back = g.back ?? g.front;
    if (back == null) return; // nothing to save
    final id = g.garmentId;
    final existing = _byId[id];
    _byId[id] = existing?.copyWith(liked: true, rejected: false) ??
        SavedDesign(
            recipe: back, garment: g, liked: true, savedAtEpochMs: nowMs);
  }

  /// Mark a saved two-face garment as ordered.
  ///
  /// Distinct from [setUsedForTshirt], which keys by a single recipe id: a
  /// garment is keyed by [GarmentDesign.garmentId], so using the recipe form
  /// here would leave the wardrobe entry untouched and add a second, faceless
  /// one beside it. Saving is implied — an ordered design is in the wardrobe
  /// whether or not it was saved by hand first.
  void markGarmentOrdered(GarmentDesign g, {required int nowMs}) {
    likeGarment(g, nowMs: nowMs);
    final entry = _byId[g.garmentId];
    if (entry == null) return;
    _byId[g.garmentId] = entry.copyWith(
      usedForTshirt: true,
      usedAtEpochMs: nowMs,
    );
  }

  /// The saved two-face garments (newest first).
  List<SavedDesign> get garments =>
      entries.where((e) => e.garment != null).toList();

  /// Remove the heart. If the design was never used for a t-shirt it is dropped
  /// entirely (we don't keep un-selected designs).
  void unlike(String id) {
    final e = _byId[id];
    if (e == null) return;
    if (e.usedForTshirt) {
      _byId[id] = e.copyWith(liked: false);
    } else {
      _byId.remove(id);
    }
  }

  /// Toggle a like, returning the new liked state.
  bool toggleLike(DesignRecipe recipe, {required int nowMs}) {
    if (isLiked(recipe.recipeId)) {
      unlike(recipe.recipeId);
      return false;
    }
    like(recipe, nowMs: nowMs);
    return true;
  }

  /// Tag a design for deletion ("I don't like it"), with an optional [reason].
  /// The full recipe is kept so the batch learner can study what to avoid.
  void reject(DesignRecipe recipe, {String? reason, required int nowMs}) {
    final existing = _byId[recipe.recipeId];
    _byId[recipe.recipeId] = (existing ??
            SavedDesign(recipe: recipe, savedAtEpochMs: nowMs))
        // Rejecting clears a like — you can't like and dislike the same design.
        .copyWith(rejected: true, liked: false, reason: reason);
  }

  /// Undo a rejection; drops the entry entirely if nothing else keeps it.
  void unreject(String id) {
    final e = _byId[id];
    if (e == null) return;
    if (e.liked || e.usedForTshirt) {
      _byId[id] = e.copyWith(rejected: false);
    } else {
      _byId.remove(id);
    }
  }

  bool toggleReject(DesignRecipe recipe, {String? reason, required int nowMs}) {
    if (isRejected(recipe.recipeId)) {
      unreject(recipe.recipeId);
      return false;
    }
    reject(recipe, reason: reason, nowMs: nowMs);
    return true;
  }

  /// Clear all rejected entries (after the learner has processed them).
  void clearRejected() {
    for (final e in rejected) {
      unreject(e.id);
    }
  }

  /// Mark (or unmark) a design as used for a real t-shirt. Marking also keeps
  /// the recipe even if it isn't liked; unmarking drops it if not liked.
  void setUsedForTshirt(DesignRecipe recipe, bool used, {required int nowMs}) {
    final existing = _byId[recipe.recipeId];
    if (used) {
      _byId[recipe.recipeId] = (existing ??
              SavedDesign(recipe: recipe, savedAtEpochMs: nowMs))
          .copyWith(usedForTshirt: true, usedAtEpochMs: nowMs);
    } else if (existing != null) {
      if (existing.liked) {
        _byId[recipe.recipeId] = existing.copyWith(usedForTshirt: false);
      } else {
        _byId.remove(recipe.recipeId);
      }
    }
  }

  Map<String, Object?> toJson() => {
        'version': schemaVersion,
        'designs': [for (final e in entries) e.toJson()],
      };

  factory DesignLibrary.fromJson(Map<String, Object?> j) => DesignLibrary([
        for (final d in (j['designs'] as List? ?? const []))
          SavedDesign.fromJson((d as Map).cast<String, Object?>()),
      ]);

  String encode() => jsonEncode(toJson());

  factory DesignLibrary.decode(String? jsonStr) {
    if (jsonStr == null || jsonStr.trim().isEmpty) return DesignLibrary();
    try {
      return DesignLibrary.fromJson(
          (jsonDecode(jsonStr) as Map).cast<String, Object?>());
    } catch (_) {
      return DesignLibrary();
    }
  }
}

/// A [DesignLibrary] backed by a [DesignStore]: load once, then persist after
/// every mutation. The same class works on macOS and iOS — only the injected
/// [DesignStore] differs.
class PersistentDesignLibrary {
  PersistentDesignLibrary(this._store);
  final DesignStore _store;
  DesignLibrary _lib = DesignLibrary();

  DesignLibrary get library => _lib;

  Future<void> load() async {
    _lib = DesignLibrary.decode(await _store.read());
  }

  /// Writes the library out, discarding a store failure.
  ///
  /// Every caller in the Studio is a synchronous user action — save, like,
  /// reject — that cannot await this, so a thrown write becomes an unhandled
  /// async error landing on whatever happens to be running. Losing a write is
  /// a lost bookmark; an unhandled error is a crash, and the in-memory library
  /// is still correct either way.
  Future<void> _persist() async {
    try {
      await _store.write(_lib.encode());
    } catch (_) {
      // Deliberately swallowed — see above.
    }
  }

  Future<bool> toggleLike(DesignRecipe r, {int? nowMs}) async {
    final liked =
        _lib.toggleLike(r, nowMs: nowMs ?? DateTime.now().millisecondsSinceEpoch);
    await _persist();
    return liked;
  }

  /// Save a two-face [GarmentDesign] (Studio Review). Idempotent by garment
  /// identity, so repeated Save keeps a single entry (no uncontrolled duplicates).
  Future<void> saveGarment(GarmentDesign g, {int? nowMs}) async {
    _lib.likeGarment(g, nowMs: nowMs ?? DateTime.now().millisecondsSinceEpoch);
    await _persist();
  }

  Future<void> markGarmentOrdered(GarmentDesign g, {int? nowMs}) async {
    _lib.markGarmentOrdered(
      g,
      nowMs: nowMs ?? DateTime.now().millisecondsSinceEpoch,
    );
    await _persist();
  }

  Future<void> setUsedForTshirt(DesignRecipe r, bool used, {int? nowMs}) async {
    _lib.setUsedForTshirt(r, used,
        nowMs: nowMs ?? DateTime.now().millisecondsSinceEpoch);
    await _persist();
  }

  Future<bool> toggleReject(DesignRecipe r, {String? reason, int? nowMs}) async {
    final rejected = _lib.toggleReject(r,
        reason: reason, nowMs: nowMs ?? DateTime.now().millisecondsSinceEpoch);
    await _persist();
    return rejected;
  }

  Future<void> clearRejected() async {
    _lib.clearRejected();
    await _persist();
  }
}
