# M188 — Copy, legal and App Store listing for a free app

**Phase:** Free Launch (M184–M189)
**Depends on:** M186 (so the final UI is known)
**Status:** Todo
**Primary target:** in-app copy · `legal/terms_screen.dart` · App Store Connect · `apps/web_marketing`

---

## 1. Why this exists

App Review checks that the app, its listing and its legal text describe the same product. A
free app whose Terms describe print-on-demand purchases, or whose screenshots show T-shirts,
invites a rejection under 2.3 (accurate metadata), and it is also misleading.

## 2. Tasks

- **T1 In-app copy sweep.** Change any string that *promises* merch to a commerce-neutral
  version when commerce is off. Includes onboarding, achievement descriptions and celebration
  copy. Use `grep -riE "t-shirt|tee|merch|poster|shop|order|print"` across `lib/` outside the
  merch features.
- **T2 Terms of Service.** §6 "Merchandise & Print-on-Demand" and the promo-code and
  fulfilment clauses are shown only when commerce is on. Mirror this in the hosted Terms and
  Privacy Policy on roavvy.com, or reword them as "may offer in future". The owner chooses the
  wording, and legal text needs owner sign-off.
- **T3 App Store Connect** (owner-operated; we prepare the content):
  - description, keywords and promo text with no merch;
  - screenshots from a commerce-off build;
  - age rating;
  - privacy nutrition labels with no Purchases category;
  - review notes saying "All features are free; no purchases in this version".
- **T4 Website.** roavvy.com mentions t-shirts and merch (about 8 references in
  `apps/web_marketing`). Align it to "coming later" or remove. Deploy only from
  `apps/web_marketing`.

## 3. Acceptance

- [ ] No in-app, Terms, listing or website text promises a purchase in v1.0.
- [ ] Owner has signed off on the legal and listing copy.
