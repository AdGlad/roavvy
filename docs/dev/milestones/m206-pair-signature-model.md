# M206 — Pair Signatures: two-country model, tokens and resolver

**Phase:** Two-country Signatures (M206–M214, ADR-185)
**Depends on:** M190 (Signature Recipe model)
**Status:** Todo
**Size:** M

---

## 1. Why

Every signature so far is for one country (`{{country}}`). The owner's references (`~/Downloads/1-heart-2-countries.jpg`, `two-hearts-1.jpeg`, `split-flags-c.jpg`, `split-two-b.jpeg`, `split-two.jpeg`; stock art, used for style only) are all **two flags in one design**. That needs a pack that takes a pair of countries.

## 2. Scope

- **Pack arity:** a new optional pack field `countries` (1 or 2; default 1, so existing packs are unchanged). With 2, `base` must use both `{{countryA}}` and `{{countryB}}`. `{{countryAName}}`, `{{countryBName}}`, `{{countryA3}}` and `{{countryB3}}` also work. `{{country}}` is refused in a pair pack.
- **Recipe content:** two `content.flags` entries (A then B). Renderers that take two flags read slot 0 as A and slot 1 as B.
- **Resolver:** `SignatureResolver.heroPair(pack, a, b)` and `variationPair(pack, a, b, i)`. The variation RNG key is `id|version|a+b|i`, so (fr, jp) and (jp, fr) are different, deterministic designs.
- **Overrides:** per-country overrides still apply to that country's half (for example, JP's red disc). New **pair overrides** use the key `"a+b"` for the rare case where two flags clash; a reason is required, as with every override.
- **Locks and heroes:** keyed by pair (`"us+co"`). The sample pair set lives in the pack (`samplePairs`).
- **Flag focus (shared rule, not per pack):** a per-flag focus point (`canton` | `centre` | `hoist`), e.g. US/AU/NZ/GR → canton and PT → emblem near the hoist, so a half-flag crop keeps the part that makes the flag recognisable. Data file in `design_forge` with a default of `centre`. In the references, US keeps its stars on either side.
- **Codec:** `formatVersion` stays 1. Encode `countries`/`samplePairs` only when used, and keep refusing unknown fields. Update `SIGNATURE.md`.

## 3. Out of scope

Three or more countries (M214), the Lab UI (M207) and the app (M213).

## 4. Definition of done

- [ ] Single-country packs and their locks are byte-identical (parity test).
- [ ] Round-trip, token, pair-override and swap-order (A/B ≠ B/A) tests.
- [ ] Flag-focus table covers all 272 flags (default centre) with a test.
- [ ] `SIGNATURE.md` documents pair packs.

## As built (2026-11-28)

- `SignatureRecipe.countries` (1 | 2) and `samplePairs` (`"a+b"` keys). The codec writes them only for pair packs, so every bundled pack still round-trips byte for byte and its locks are unchanged (`pair_signature_test.dart`).
- `SignaturePair` (`a`, `b`, `key`, `swapped`, `parse`), plus `instantiatePair` / `instantiateKey`.
- Tokens `{{countryA}}`, `{{countryA3}}`, `{{countryAName}}` and the same for `B`. Validation:
  - a pair pack must use an A and a B token and no single tokens;
  - a single pack refuses pair tokens, pair keys and `samplePairs`;
  - heroes and locks must be keyed by pair in a pair pack.
- Overrides:
  - **country overrides** use the path segment `{slot}` (0 = A, 1 = B), so a fix only touches that country's half; paths without it apply to the whole design;
  - **pair overrides** (`"a+b"`) apply last and may not use `{slot}`.
- Resolver:
  - `heroPair`, `variationPair` (seed `id|version|a+b|i`), and the key-generic `heroFor` / `variationFor`;
  - `driftedLocks` / `lockFor` accept either kind of key;
  - `hero` / `variation` throw `StateError` on a pair pack, and the reverse.
- `FlagFocus.of(code)`: a kind (centre, canton, hoist, emblem, fly), a focus point, an optional `FlagBox` emblem, `windowLeft(w)` and `visibleFraction(box)`. About 200 flags are hand-set; the rest default to centre with no emblem.
- `PairGeometry.of(recipe)`, with `FlagCrop` (`emblemVisible`, optional polygon) and `PairSeam`. It is the hook compositions use to report crops and the seam to pair QA. It returns null until M209 adds `splitPair`.
- `SIGNATURE.md` has a "Two-country packs" section.
