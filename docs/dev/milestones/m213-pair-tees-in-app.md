# M213 — Pair tees in the app

**Phase:** Two-country Signatures (M206–M214, ADR-185)
**Depends on:** M206; the first approved pair pack (M209)
**Status:** Todo
**Size:** M

---

## 1. Scope

- **Choosing the pair** (needs the owner's decision; this is the default):
  1. **Suggested pairs** from the user's data: countries visited on the same trip, and the two most-visited countries. The app has no home country, so "home + destination" pairs need a home-country setting first. That is out of scope unless the owner wants it.
  2. **Pick any two** visited countries, with ⇄ swap to change the order.
- **Pair tee page:** the signature tee page (`studio_v2_commerce/signature_tees/`) takes a pair. It has the same TeeSidesPreview, print layout controls, colour backdrop, sizes and cart. Cart and print files go through the existing `renderPrintFiles` path unchanged, since the art is still one recipe.
- **Entry points:** a "Two countries" row on the signature tee list, and the trip detail page for trips with two or more countries. Everything sits behind CommerceGate.
- **Title:** "Greece & Italy" in cart and order lines.

## 2. Definition of done

- [ ] Widget tests: pick a pair, swap, add to cart (both commerce modes).
- [ ] The full suite is green with `ROAVVY_COMMERCE=true` and `false`.
- [ ] Only approved pair packs show in release builds (drafts only in debug).
