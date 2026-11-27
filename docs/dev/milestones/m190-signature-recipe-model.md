# M190 — Signature Recipe model, pack format and resolver (engine)

**Phase:** v2 Signature T-shirts (M190–M199)
**Depends on:** none (v1.0 merged, `main` @ 9e479da2)
**Status:** Done (branch `feat/m190-signature-recipes`, not merged)
**Primary target:** `packages/design_forge` · `packages/design_studio` · ADR-181
**Size:** M

---

## 1. Why this exists

v2 is built around six "signature" recipes that each produce a good T-shirt for every country, approved outside the app. Before any recipe or Lab work, the engine needs one shared description of what an approved recipe is: a base design, the ranges variations may move within, sparse per-country fixes, and locks that catch engine drift. Everything else in v2 (Lab workbench, the six recipes, the in-app feed) reads and writes this one format.

## 2. Architecture (ADR-181)

```
packages/design_forge/lib/src/signature/
  signature_recipe.dart     SignatureRecipe, SignatureStatus, CountryOverride
  variation_envelope.dart   VariationEnvelope, ParamRange (num range | value set)
  signature_pack_codec.dart roavvy.signature_pack v1 <-> SignatureRecipe (canonical JSON)
  signature_resolver.dart   hero(pack, cc) / variation(pack, cc, i) -> DesignRecipe
packages/design_studio/
  assets/signature/         <id>.pack.json (bundled; declared in pubspec)
  lib/src/signature_catalog.dart  load packs from an AssetBundle / file store; release drops drafts
```

- Parameters are addressed by stable dotted paths into `DesignRecipe` canonical JSON (e.g. `tornStrips.distress`, `style.palette`, `seed`). One `RecipePath` helper reads and writes them; `ParamRange` validates them.
- Resolution order: `base` → fill country → apply `overrides[cc]` → (variation only) sample each envelope path with `DeterministicRng(hash(id, version, cc, i)).sub(path)` → `DesignRecipe`. Hero = index 0 with `heroes[cc]` seed if present.
- `locks` check: `SignatureCatalog.verify(pack)` re-resolves each locked country and compares `recipeId`; returns a list of drifted countries (tests fail on any).
- Pure Dart in `design_forge` (no Flutter); the catalog sits in `design_studio` because it needs `AssetBundle`.

## 3. Tasks

- **T1 Model.** `SignatureRecipe`, `VariationEnvelope`, `ParamRange`, `CountryOverride` (`params`, `reason` required), `SignatureStatus`. Immutable, `==`/`hashCode`, `copyWith`.
- **T2 Codec.** `roavvy.signature_pack` v1 encode/decode via `canonical_json.dart`; unknown future fields rejected with a clear error; round-trip is byte-identical.
- **T3 RecipePath.** Read/write/validate dotted paths on recipe JSON; reject unknown paths at decode time (a typo in a pack must fail loudly).
- **T4 Resolver.** `hero` and `variation` as above; envelope values clamped to range; overrides cannot widen the envelope.
- **T5 Catalog.** `SignatureCatalog` in design_studio: `loadBundled()`, `approved` getter, `verify(pack)`. Release builds (`kReleaseMode`) never return `draft` packs.
- **T6 Seed pack.** Convert `design_studio/recipes/portrait_torn_flag/us-classic.preset.json` into `assets/signature/torn_flag.pack.json` (status `draft`, envelope empty, lock = US) to prove the format end to end.
- **T7 ADR + docs.** ADR-181 (written, status Proposed → Accepted on merge); `packages/design_forge/doc/SIGNATURE.md` explaining the format with the torn-flag example.

## 4. Tests

- Codec round-trip and canonical bytes; rejected unknown fields/paths.
- Resolver determinism: same `(pack, cc, i)` → same `recipeId` across runs and isolates; different `i` → different recipe; every sampled value inside its range.
- Overrides applied only to their country; cannot exceed the envelope.
- Catalog: drafts hidden under a release flag; `verify` reports a deliberately changed lock.

## 5. Acceptance

- [x] `dart test` in `design_forge` (135) and `flutter test` in `design_studio` (85) green; analyze clean.
- [x] Torn-flag seed pack loads, resolves US to the same `recipeId` as the existing preset (`748dc73163b8ec40`).
- [x] No change to `apps/mobile_flutter` or the V1 merch path (mobile + Lab analyze: 0 errors).

## 6. As built (2026-11-27)

- `packages/design_forge/lib/src/signature/`: `recipe_path.dart` (dotted paths, list indices, leaf-only), `variation_envelope.dart` (`NumRange` incl. integer, `ValueSet`; draws rounded to 4 dp), `signature_recipe.dart` (model + all validation at construction), `signature_resolver.dart` (`hero`, `variation`, `driftedLocks`, `lockFor`), `signature_pack_codec.dart` (`encode`/`decode`, `draftFromRecipe`).
- Decisions made while building:
  - Heroes store **envelope values** (not just a seed), so "save this variation as the hero" in the Lab is exact.
  - An override on an enveloped path **pins** it for that country and must sit inside the range; overrides can never widen the envelope.
  - Templating is a `{{country}}` string token, required in `base`; extra `{{name}}` tokens can be passed for later recipes (trip year, name).
  - The catalog takes an injected loader (`rootBundle.loadString` on mobile, file reads in the Lab), keeping host concerns out of design_studio, plus an `index.json` that fixes feed order.
- `packages/design_studio/lib/src/signature_catalog.dart`, assets `assets/signature/{index.json,torn_flag.pack.json}` declared in the pubspec.
- `packages/design_forge/tool/pack_from_preset.dart` made the torn-flag seed pack (draft, empty envelope, lock `us`).
- Tests: `design_forge/test/signature_recipe_test.dart` (17, incl. cross-isolate determinism), `design_studio/test/signature_catalog_test.dart` (5: locks, canonical files, preset parity, drafts hidden, id mismatch).
- Doc: `packages/design_forge/doc/SIGNATURE.md`.
