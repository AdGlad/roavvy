import 'dart:convert';

import 'package:design_forge/design_forge.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;

/// Loads a text asset by key. Hosts inject it: mobile passes
/// `rootBundle.loadString`, the macOS Lab reads the repo file directly.
typedef SignatureAssetLoader = Future<String> Function(String key);

/// The bundled Signature Recipe packs (ADR-181 §2, §5).
///
/// Packs live in this package at `assets/signature/<id>.pack.json`, listed in
/// `assets/signature/index.json` (`{"packs": ["torn_flag", …]}`) in feed
/// order. A host loads them with [load]; release builds never see a draft.
class SignatureCatalog {
  SignatureCatalog(Iterable<SignatureRecipe> packs)
      : packs = List.unmodifiable(packs);

  /// Asset-key prefix when loaded from a Flutter app that depends on this
  /// package (`rootBundle` keys of package assets).
  static const String bundlePrefix = 'packages/design_studio/assets/signature/';

  /// Path prefix relative to this package's root (the Lab, tests).
  static const String packagePrefix = 'assets/signature/';

  static const String indexFile = 'index.json';
  static String packFile(String id) => '$id.pack.json';

  /// Every loaded pack, in index order.
  final List<SignatureRecipe> packs;

  /// Packs users may see.
  List<SignatureRecipe> get approved =>
      [for (final p in packs) if (p.isApproved) p];

  SignatureRecipe? byId(String id) {
    for (final p in packs) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Loads the index and every pack it lists. Draft packs are dropped unless
  /// [includeDrafts] (default: everything but release builds). A pack that
  /// fails to decode throws: a broken pack must never ship silently.
  static Future<SignatureCatalog> load(
    SignatureAssetLoader loader, {
    String prefix = bundlePrefix,
    bool includeDrafts = !kReleaseMode,
  }) async {
    final index = jsonDecode(await loader('$prefix$indexFile'));
    final ids = (index is Map ? index['packs'] : null);
    if (ids is! List) {
      throw const FormatException('signature index.json needs a "packs" list');
    }
    final packs = <SignatureRecipe>[];
    for (final id in ids.cast<String>()) {
      final pack = SignaturePackCodec.decode(await loader('$prefix${packFile(id)}'));
      if (pack.id != id) {
        throw FormatException('${packFile(id)} declares id "${pack.id}"');
      }
      if (includeDrafts || pack.isApproved) packs.add(pack);
    }
    return SignatureCatalog(packs);
  }

  /// Pack id → countries whose hero no longer matches its lock. Empty when
  /// no engine change has altered an approved design.
  Map<String, List<String>> verify() => {
        for (final p in packs)
          if (SignatureResolver.driftedLocks(p).isNotEmpty)
            p.id: SignatureResolver.driftedLocks(p),
      };
}
