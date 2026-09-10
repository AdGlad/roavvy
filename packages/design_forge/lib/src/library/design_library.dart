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
    this.updatedAtEpochMs,
    this.usedAtEpochMs,
    this.note,
    this.reason,
    this.session,
    this.version = DesignLibrary.schemaVersion,
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

  /// When the entry was last re-saved. Null until it has been saved a second
  /// time; [sortedAtEpochMs] falls back to [savedAtEpochMs].
  final int? updatedAtEpochMs;

  final int? usedAtEpochMs;
  final String? note;

  /// The editor session that produced this design, as an OPAQUE map.
  ///
  /// A [DesignRecipe] reproduces the *picture* exactly, but not the state the
  /// editor was in when the customer made it — which Direction and Detail they
  /// were on, which countries and years they had chosen, how the front was
  /// configured. Reopening without it restores the right artwork into the wrong
  /// session, and the first edit that regenerates throws the saved design away.
  ///
  /// Kept opaque on purpose: the shape belongs to whichever editor wrote it
  /// (see `StudioSession` in `design_studio`), so the library persists it
  /// faithfully without needing to understand it, and an entry written by a
  /// newer editor still round-trips through an older one.
  final Map<String, Object?>? session;

  /// The [DesignLibrary.schemaVersion] this entry was written at. Entries from
  /// older versions load with the defaults for whatever they lack; entries from
  /// a NEWER version keep their own number so nothing downgrades them silently.
  final int version;

  /// The time this entry should be ordered by: last save, else first save.
  int get sortedAtEpochMs => updatedAtEpochMs ?? savedAtEpochMs;

  /// Content-hash id (stable across sessions and re-renders). A two-face garment
  /// is keyed by its composite [GarmentDesign.garmentId] (covers both faces +
  /// colour), so re-saving the same garment updates ONE entry — no duplicates.
  /// A single-face like keeps the recipe's own content hash.
  String get id => garment?.garmentId ?? recipe.recipeId;

  SavedDesign copyWith({
    bool? liked,
    bool? usedForTshirt,
    bool? rejected,
    int? updatedAtEpochMs,
    int? usedAtEpochMs,
    String? note,
    String? reason,
    Map<String, Object?>? session,
  }) =>
      SavedDesign(
        recipe: recipe,
        garment: garment,
        liked: liked ?? this.liked,
        usedForTshirt: usedForTshirt ?? this.usedForTshirt,
        rejected: rejected ?? this.rejected,
        savedAtEpochMs: savedAtEpochMs,
        updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
        usedAtEpochMs: usedAtEpochMs ?? this.usedAtEpochMs,
        note: note ?? this.note,
        reason: reason ?? this.reason,
        session: session ?? this.session,
        version: version,
      );

  Map<String, Object?> toJson() => {
        'recipe': recipe.toJson(),
        if (garment != null) 'garment': garment!.toJson(),
        if (liked) 'liked': true,
        if (usedForTshirt) 'usedForTshirt': true,
        if (rejected) 'rejected': true,
        'savedAt': savedAtEpochMs,
        if (updatedAtEpochMs != null) 'updatedAt': updatedAtEpochMs,
        if (usedAtEpochMs != null) 'usedAt': usedAtEpochMs,
        if (note != null) 'note': note,
        if (reason != null) 'reason': reason,
        if (session != null) 'session': session,
        'v': version,
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
        updatedAtEpochMs: (j['updatedAt'] as num?)?.toInt(),
        usedAtEpochMs: (j['usedAt'] as num?)?.toInt(),
        note: j['note'] as String?,
        reason: j['reason'] as String?,
        session: j['session'] == null
            ? null
            : (j['session'] as Map).cast<String, Object?>(),
        // Entries written before versioning carry no 'v'; they are version 1.
        version: (j['v'] as num?)?.toInt() ?? 1,
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

  /// The library format version.
  ///
  /// 1 — recipe + garment + flags + timestamps.
  /// 2 — adds the opaque editor [SavedDesign.session], [SavedDesign.updatedAtEpochMs]
  ///     and a per-entry `v`. Both additions are optional, so a version-1 file
  ///     loads unchanged: its entries simply carry no session and reopen with
  ///     the artwork alone (see [SavedDesign.session]).
  static const schemaVersion = 2;

  /// How many entries the last [fromJson] could not read.
  ///
  /// One unreadable record must never cost the customer their whole wardrobe,
  /// so a bad entry is skipped rather than thrown — this counts what was lost
  /// so a host can say so instead of pretending nothing was there.
  int get unreadableEntries => _unreadable;
  int _unreadable = 0;

  /// The `version` the loaded file declared (defaults to [schemaVersion] for a
  /// library built in memory). A file from a NEWER version keeps its number.
  int get loadedVersion => _loadedVersion;
  int _loadedVersion = schemaVersion;

  final Map<String, SavedDesign> _byId;

  /// All kept designs, most recently saved first.
  List<SavedDesign> get entries => _byId.values.toList()
    ..sort((a, b) => b.sortedAtEpochMs.compareTo(a.sortedAtEpochMs));

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
  void likeGarment(GarmentDesign g,
      {required int nowMs, Map<String, Object?>? session}) {
    final back = g.back ?? g.front;
    if (back == null) return; // nothing to save
    final id = g.garmentId;
    final existing = _byId[id];
    _byId[id] = existing?.copyWith(
          liked: true,
          rejected: false,
          // Re-saving the SAME garment updates the one entry: the design is
          // unchanged, so only when it was last kept and the session behind it
          // move. Editing changes [GarmentDesign.garmentId], which is a
          // different design and therefore a different entry.
          updatedAtEpochMs: nowMs,
          session: session,
        ) ??
        SavedDesign(
          recipe: back,
          garment: g,
          liked: true,
          savedAtEpochMs: nowMs,
          session: session,
        );
  }

  /// Remove a saved design outright — the wardrobe's Delete.
  ///
  /// Unlike [unlike] this is unconditional: an ordered design can be deleted
  /// from the wardrobe too (the order it produced is commerce's record, not
  /// this one's). Touches nothing but [id]. Returns whether anything went.
  bool remove(String id) => _byId.remove(id) != null;

  /// Copy a saved design under a NEW identity, leaving the original alone.
  ///
  /// The recipes are carried across untouched — a duplicate is the same design,
  /// never a re-roll — and identity comes from [GarmentDesign.variant], which is
  /// already part of [GarmentDesign.garmentId]. The copy starts un-ordered: it
  /// is a new design that has never been printed. Returns the new id, or null
  /// if [id] is not a saved garment.
  String? duplicate(String id, {required int nowMs, String? variant}) {
    final entry = _byId[id];
    final g = entry?.garment;
    if (entry == null || g == null) return null;
    final copy = GarmentDesign(
      front: g.front,
      back: g.back,
      garmentColour: g.garmentColour,
      variant: variant ?? 'copy:$nowMs',
      themeSeed: g.themeSeed,
    );
    likeGarment(copy, nowMs: nowMs, session: entry.session);
    return copy.garmentId;
  }

  /// Mark a saved two-face garment as ordered.
  ///
  /// Distinct from [setUsedForTshirt], which keys by a single recipe id: a
  /// garment is keyed by [GarmentDesign.garmentId], so using the recipe form
  /// here would leave the wardrobe entry untouched and add a second, faceless
  /// one beside it. Saving is implied — an ordered design is in the wardrobe
  /// whether or not it was saved by hand first.
  void markGarmentOrdered(GarmentDesign g,
      {required int nowMs, Map<String, Object?>? session}) {
    likeGarment(g, nowMs: nowMs, session: session);
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

  /// Reads a persisted library, entry by entry.
  ///
  /// Deliberately tolerant in one direction only: a record this build cannot
  /// read is SKIPPED and counted ([unreadableEntries]), never guessed at and
  /// never allowed to take the rest of the wardrobe with it. Nothing is ever
  /// regenerated to fill a gap — a design that cannot be restored exactly is
  /// not a design the customer saved.
  factory DesignLibrary.fromJson(Map<String, Object?> j) {
    final kept = <SavedDesign>[];
    var unreadable = 0;
    for (final d in (j['designs'] as List? ?? const [])) {
      try {
        kept.add(SavedDesign.fromJson((d as Map).cast<String, Object?>()));
      } catch (_) {
        unreadable++;
      }
    }
    return DesignLibrary(kept)
      .._unreadable = unreadable
      .._loadedVersion = (j['version'] as num?)?.toInt() ?? 1;
  }

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
  Future<bool> _persist() async {
    try {
      await _store.write(_lib.encode());
      _lastWriteFailed = false;
      return true;
    } catch (_) {
      // Deliberately swallowed — see above. Recorded, though, so a host that
      // wants to offer a retry can tell a written design from a lost one.
      _lastWriteFailed = true;
      return false;
    }
  }

  /// Whether the last write to the store failed. The in-memory library is still
  /// correct either way — this says only that the change has not reached disk.
  bool get lastWriteFailed => _lastWriteFailed;
  bool _lastWriteFailed = false;

  Future<bool> toggleLike(DesignRecipe r, {int? nowMs}) async {
    final liked =
        _lib.toggleLike(r, nowMs: nowMs ?? DateTime.now().millisecondsSinceEpoch);
    await _persist();
    return liked;
  }

  /// Save a two-face [GarmentDesign] (Studio Review). Idempotent by garment
  /// identity, so repeated Save keeps a single entry (no uncontrolled duplicates).
  Future<bool> saveGarment(GarmentDesign g,
      {int? nowMs, Map<String, Object?>? session}) async {
    _lib.likeGarment(g,
        nowMs: nowMs ?? DateTime.now().millisecondsSinceEpoch,
        session: session);
    return _persist();
  }

  Future<void> markGarmentOrdered(GarmentDesign g,
      {int? nowMs, Map<String, Object?>? session}) async {
    _lib.markGarmentOrdered(
      g,
      nowMs: nowMs ?? DateTime.now().millisecondsSinceEpoch,
      session: session,
    );
    await _persist();
  }

  /// Delete one saved design. Nothing else in the wardrobe is touched.
  Future<bool> remove(String id) async {
    if (!_lib.remove(id)) return false;
    await _persist();
    return true;
  }

  /// Copy one saved design under a new identity (see [DesignLibrary.duplicate]).
  Future<String?> duplicate(String id, {int? nowMs}) async {
    final newId = _lib.duplicate(id,
        nowMs: nowMs ?? DateTime.now().millisecondsSinceEpoch);
    if (newId != null) await _persist();
    return newId;
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
