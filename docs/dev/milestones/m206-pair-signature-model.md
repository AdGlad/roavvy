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
